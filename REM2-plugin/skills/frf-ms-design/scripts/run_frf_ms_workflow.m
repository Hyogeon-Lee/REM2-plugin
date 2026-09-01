function result = run_frf_ms_workflow(excelFile, outputDir, options)
arguments
    excelFile (1, :) char
    outputDir (1, :) char = ''
    options.TargetCrossoverHz (1, 1) double = NaN
    options.MaxDenominatorOrder (1, 1) double {mustBeInteger, mustBePositive} = 6
    options.ControllerStructure (1, 1) string {mustBeMember(options.ControllerStructure, ["auto", "lag", "leadlag"])} = "auto"
    options.Implementation (1, 1) string {mustBeMember(options.Implementation, ["auto", "analog", "digital"])} = "auto"
    options.SamplingFrequencyHz (1, 1) double = NaN
    options.ConfirmSamplingFrequency (1, 1) logical = false
    options.PhaseMarginTargetDeg (1, 1) double = 40
    options.GainMarginTargetDb (1, 1) double = 6
    options.LeadAlpha (1, 1) double = NaN
    options.LagPhaseBudgetDeg (1, 1) double {mustBeNonnegative} = 10
    options.SearchAllOrders (1, 1) logical = false
    options.EstimateTimeDelay (1, 1) logical = true
end

if isempty(outputDir)
    [folderPath, fileName] = fileparts(excelFile);
    outputDir = fullfile(folderPath, "outputs", fileName);
end
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end

[frfData, metadata, warningMessages] = read_frf_excel(excelFile);

targetCrossoverHz = options.TargetCrossoverHz;
targetAutoDefaulted = ~isfinite(targetCrossoverHz) || targetCrossoverHz <= 0;
if targetAutoDefaulted
    targetCrossoverHz = localDefaultTarget(frfData.FrequencyHz);
    % 자동 기본값은 스모크 테스트용: 반드시 사용자 확인을 받아야 함
    warningMessages(end + 1, 1) = sprintf( ...
        "auto default target crossover %.4g Hz — confirm with the user", targetCrossoverHz);
end
if targetCrossoverHz < min(frfData.FrequencyHz) || targetCrossoverHz > max(frfData.FrequencyHz)
    warningMessages(end + 1, 1) = sprintf( ...
        "Target crossover %.3g Hz is outside the measured band [%.3g, %.3g] Hz; results rely on model extrapolation.", ...
        targetCrossoverHz, min(frfData.FrequencyHz), max(frfData.FrequencyHz));
end

% Implementation 해석: auto -> 메타데이터가 이산(Ts > 0)이면 digital(메타데이터 레이트), 아니면 analog
implementation = options.Implementation;
if strcmpi(implementation, "auto")
    if frfData.Ts > 0
        implementation = "digital";
    else
        implementation = "analog";
    end
end

% 디지털 fs 해석 규칙:
% - SamplingFrequencyHz 가 NaN 이면 메타데이터 Ts 로 결정, 없으면 오류(호출자에게 fs 요청)
% - 명시 지정 + 메타데이터 불일치(>1%)면 오류: 측정 레이트와 제어기 레이트는 다른 양
%   (의도적 오버라이드는 ConfirmSamplingFrequency=true 로만 허용)
samplingFrequencyHz = options.SamplingFrequencyHz;
if strcmpi(implementation, "digital")
    if ~isfinite(samplingFrequencyHz) || samplingFrequencyHz <= 0
        if frfData.Ts > 0
            samplingFrequencyHz = 1/frfData.Ts;
        else
            error("frf_ms_design:MissingSamplingFrequency", ...
                "Digital implementation requested but no controller sampling frequency is available (metadata is continuous). Pass SamplingFrequencyHz explicitly.");
        end
    elseif frfData.Ts > 0
        metadataFsHz = 1/frfData.Ts;
        if abs(metadataFsHz - samplingFrequencyHz) > 0.01*metadataFsHz && ~options.ConfirmSamplingFrequency
            error("frf_ms_design:SampleRateMismatch", ...
                "Metadata sampling frequency %.6g Hz (measurement rate, already inside the measured FRF) differs from SamplingFrequencyHz=%.6g Hz (controller rate). These are different quantities; pass ConfirmSamplingFrequency=true only for a deliberate controller-rate override.", ...
                metadataFsHz, samplingFrequencyHz);
        end
    end
else
    % analog: fs 미사용 -> design_lead_lag 기본값으로 채움 (분석에는 영향 없음)
    samplingFrequencyHz = 1000;
end

[plant, fitInfo] = fit_plant_model(frfData, ...
    MaxDenominatorOrder=options.MaxDenominatorOrder, ...
    TargetCrossoverHz=targetCrossoverHz, ...
    SearchAllOrders=options.SearchAllOrders, ...
    EstimateTimeDelay=options.EstimateTimeDelay);

% 피팅 품질 게이트: 크로스오버 대역 [wc/2, min(10*wc, fmax)] RMS 크기 오차 > 3 dB 면 경고
crossoverBandRmsDb = localCrossoverBandRms(plant, frfData, targetCrossoverHz);
if crossoverBandRmsDb > 3
    warningMessages(end + 1, 1) = sprintf( ...
        "plant fit unreliable near crossover (band RMS magnitude error %.2f dB > 3 dB); margins not trustworthy", ...
        crossoverBandRmsDb);
end

[controller, designInfo] = design_lead_lag(plant, targetCrossoverHz, ...
    ControllerStructure=options.ControllerStructure, ...
    Implementation=implementation, ...
    SamplingFrequencyHz=samplingFrequencyHz, ...
    PhaseMarginTargetDeg=options.PhaseMarginTargetDeg, ...
    GainMarginTargetDb=options.GainMarginTargetDb, ...
    LeadAlpha=options.LeadAlpha, ...
    LagPhaseBudgetDeg=options.LagPhaseBudgetDeg);

% 불안정 설계는 하드 스톱: 결과 산출물을 만들지 않고 실패
if designInfo.DesignFailed || ~designInfo.ClosedLoopStable
    error("frf_ms_design:UnstableDesign", ...
        "No stable closed-loop design was found at target crossover %.4g Hz (structure %s, required lead %.1f deg). Lower the target crossover (e.g. toward the plant roll-off region) and re-run.", ...
        targetCrossoverHz, designInfo.ControllerStructure, designInfo.RequiredLeadDeg);
end

analysisInfo = localAnalyzeClosedLoop(plant, controller, targetCrossoverHz, designInfo);
if strlength(analysisInfo.StepWarning) > 0
    warningMessages(end + 1, 1) = string(analysisInfo.StepWarning);
end
plotInfo = plot_design_summary(frfData, plant, controller, designInfo, analysisInfo, outputDir);

result = struct();
result.ExcelFile = excelFile;
result.OutputDir = outputDir;
result.Metadata = metadata;
result.WarningMessages = warningMessages;
result.FrfData = frfData;
result.Plant = plant;
result.FitInfo = fitInfo;
result.Controller = controller;
result.DesignInfo = designInfo;
result.AnalysisInfo = analysisInfo;
result.PlotInfo = plotInfo;
% 피팅 품질 요약 필드 (기존 필드 유지, 추가만)
result.FitRmsMagnitudeErrorDb = fitInfo.RmsMagnitudeErrorDb;
result.FitRmsPhaseErrorDeg = fitInfo.RmsPhaseErrorDeg;
result.CrossoverBandRmsMagnitudeErrorDb = crossoverBandRmsDb;

save(fullfile(outputDir, "workflow_result.mat"), "result");
end

function targetCrossoverHz = localDefaultTarget(frequencyHz)
fMin = min(frequencyHz);
fMax = max(frequencyHz);
targetCrossoverHz = sqrt(fMin*fMax)/5;
targetCrossoverHz = max(targetCrossoverHz, 2*fMin);
targetCrossoverHz = min(targetCrossoverHz, fMax/10);
% narrow band (span < 20x): the clamps conflict and push the target out of band -> geometric center
if targetCrossoverHz < fMin || targetCrossoverHz > fMax
    targetCrossoverHz = sqrt(fMin*fMax);
end
end

function bandRmsDb = localCrossoverBandRms(plant, frfData, targetCrossoverHz)
% 크로스오버 대역 [wc/2, min(10*wc, fmax)] 의 RMS 크기 피팅 오차 (dB)
fMaxHz = max(frfData.FrequencyHz);
bandIndex = frfData.FrequencyHz >= targetCrossoverHz/2 ...
    & frfData.FrequencyHz <= min(10*targetCrossoverHz, fMaxHz);
if ~any(bandIndex)
    bandRmsDb = Inf;   % 대역에 측정점 없음 -> 검증 불가 -> 경고를 유발하는 Inf
    return
end
modelResponse = squeeze(freqresp(plant, frfData.WradPerSec(bandIndex)));
magErrorDb = 20*log10(abs(modelResponse(:))) - 20*log10(frfData.MagnitudeAbs(bandIndex));
magErrorDb = magErrorDb(isfinite(magErrorDb));
if isempty(magErrorDb)
    bandRmsDb = Inf;
else
    bandRmsDb = sqrt(mean(magErrorDb.^2));
end
end

function analysisInfo = localAnalyzeClosedLoop(plant, controller, targetCrossoverHz, designInfo)
s = tf("s");
% include the same ZOH delay approximation as the design loop for consistent margins/step
if designInfo.AnalysisDelaySeconds > 0
    analysisDelay = exp(-designInfo.AnalysisDelaySeconds*s);
else
    analysisDelay = tf(1);
end

loopContinuous = minreal(controller.Continuous * plant, [], false) * analysisDelay;
closedLoop = feedback(loopContinuous, 1);
sensitivity = feedback(tf(1), loopContinuous);
closedLoopStable = frf_closed_loop_stable(loopContinuous);   % 공유 헬퍼 (Pade 패턴 복제 금지)

referenceFrequencyHz = targetCrossoverHz/10;
stepTime = linspace(0, 5/referenceFrequencyHz, 1000).';   % 5 periods at the reference frequency (s)
stepFinalValue = real(dcgain(closedLoop));
stepWarning = "";

% 스텝 예측은 안정 루프에서만 수행
if closedLoopStable
    try
        stepResponse = squeeze(step(closedLoop, stepTime));
        stepResponse = stepResponse(:);
        if isfinite(stepFinalValue)
            stepInfo = stepinfo(stepResponse, stepTime, stepFinalValue);
        else
            stepInfo = stepinfo(stepResponse, stepTime);
        end
        % 정착 시간이 시뮬레이션 창 끝에 걸리면 미정착 가능성 경고
        if isfinite(stepInfo.SettlingTime) && stepInfo.SettlingTime > 0.95*max(stepTime)
            stepWarning = sprintf( ...
                "Step settling time %.4g s sits at the simulation window edge (%.4g s); the response may not be settled.", ...
                stepInfo.SettlingTime, max(stepTime));
        end
    catch errorInfo
        stepResponse = NaN(size(stepTime));
        stepInfo = localEmptyStepInfo();
        stepWarning = string(errorInfo.message);
    end
else
    stepResponse = NaN(size(stepTime));
    stepInfo = localEmptyStepInfo();
    stepWarning = "Closed loop is unstable; step prediction skipped.";
end

analysisInfo = struct();
analysisInfo.Loop = loopContinuous;
analysisInfo.ClosedLoop = closedLoop;
analysisInfo.Sensitivity = sensitivity;
analysisInfo.ReferenceFrequencyHz = referenceFrequencyHz;
analysisInfo.StepTime = stepTime;
analysisInfo.StepResponse = stepResponse;
analysisInfo.StepFinalValue = stepFinalValue;
analysisInfo.StepInfo = stepInfo;
analysisInfo.StepWarning = stepWarning;
analysisInfo.ClosedLoopStable = closedLoopStable;
end

function stepInfo = localEmptyStepInfo()
stepInfo = struct();
stepInfo.RiseTime = NaN;
stepInfo.TransientTime = NaN;
stepInfo.SettlingTime = NaN;
stepInfo.SettlingMin = NaN;
stepInfo.SettlingMax = NaN;
stepInfo.Overshoot = NaN;
stepInfo.Undershoot = NaN;
stepInfo.Peak = NaN;
stepInfo.PeakTime = NaN;
end
