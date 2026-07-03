function result = run_frf_ms_workflow(excelFile, outputDir, options)
arguments
    excelFile (1, :) char
    outputDir (1, :) char = ''
    options.TargetCrossoverHz (1, 1) double = NaN
    options.MaxDenominatorOrder (1, 1) double {mustBeInteger, mustBePositive} = 6
    options.ControllerStructure (1, 1) string = "auto"
    options.Implementation (1, 1) string = "auto"
    options.SamplingFrequencyHz (1, 1) double {mustBePositive} = 1000
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
if ~isfinite(targetCrossoverHz) || targetCrossoverHz <= 0
    targetCrossoverHz = localDefaultTarget(frfData.FrequencyHz);
end
if targetCrossoverHz < min(frfData.FrequencyHz) || targetCrossoverHz > max(frfData.FrequencyHz)
    warningMessages(end + 1, 1) = sprintf( ...
        "Target crossover %.3g Hz is outside the measured band [%.3g, %.3g] Hz; results rely on model extrapolation.", ...
        targetCrossoverHz, min(frfData.FrequencyHz), max(frfData.FrequencyHz));
end

implementation = options.Implementation;
if strcmpi(implementation, "auto")
    if frfData.Ts > 0
        implementation = "digital";
    else
        implementation = "analog";
    end
end

% metadata 샘플링 주파수와 SamplingFrequencyHz 옵션 불일치 경고 (상대 오차 1% 초과)
if strcmpi(implementation, "digital") && frfData.Ts > 0
    metadataFsHz = 1/frfData.Ts;
    if abs(metadataFsHz - options.SamplingFrequencyHz) > 0.01*metadataFsHz
        warningMessages(end + 1, 1) = sprintf( ...
            "Metadata sampling frequency %.6g Hz differs from SamplingFrequencyHz=%.6g Hz; digital design uses %.6g Hz.", ...
            metadataFsHz, options.SamplingFrequencyHz, options.SamplingFrequencyHz);
    end
end

[plant, fitInfo] = fit_plant_model(frfData, ...
    MaxDenominatorOrder=options.MaxDenominatorOrder, ...
    TargetCrossoverHz=targetCrossoverHz);

[controller, designInfo] = design_lead_lag(plant, targetCrossoverHz, ...
    ControllerStructure=options.ControllerStructure, ...
    Implementation=implementation, ...
    SamplingFrequencyHz=options.SamplingFrequencyHz);

analysisInfo = localAnalyzeClosedLoop(plant, controller, targetCrossoverHz, designInfo);
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

save(fullfile(outputDir, "workflow_result.mat"), "result");
end

function targetCrossoverHz = localDefaultTarget(frequencyHz)
fMin = min(frequencyHz);
fMax = max(frequencyHz);
targetCrossoverHz = sqrt(fMin*fMax)/5;
targetCrossoverHz = max(targetCrossoverHz, 2*fMin);
targetCrossoverHz = min(targetCrossoverHz, fMax/10);
% 협대역(span < 20x)에서는 위 클램프가 상충해 대역 밖으로 밀림 → 기하 중심으로 보정
if targetCrossoverHz < fMin || targetCrossoverHz > fMax
    targetCrossoverHz = sqrt(fMin*fMax);
end
end

function analysisInfo = localAnalyzeClosedLoop(plant, controller, targetCrossoverHz, designInfo)
s = tf("s");
% 설계 단계와 동일한 해석 지연(digital ZOH 근사) 포함 → margin/step 일관성 유지
if designInfo.AnalysisDelaySeconds > 0
    analysisDelay = exp(-designInfo.AnalysisDelaySeconds*s);
else
    analysisDelay = tf(1);
end

loopContinuous = minreal(controller.Continuous * plant, [], false) * analysisDelay;
closedLoop = feedback(loopContinuous, 1);
sensitivity = feedback(tf(1), loopContinuous);

referenceFrequencyHz = targetCrossoverHz/10;
stepTime = linspace(0, 5/referenceFrequencyHz, 1000).';   % 기준 정현파 5주기
stepFinalValue = real(dcgain(closedLoop));
stepWarning = "";

try
    stepResponse = squeeze(step(closedLoop, stepTime));
    stepResponse = stepResponse(:);
    if isfinite(stepFinalValue)
        stepInfo = stepinfo(stepResponse, stepTime, stepFinalValue);
    else
        stepInfo = stepinfo(stepResponse, stepTime);
    end
catch errorInfo
    stepResponse = NaN(size(stepTime));
    stepInfo = localEmptyStepInfo();
    stepWarning = string(errorInfo.message);
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
analysisInfo.ClosedLoopStable = localClosedLoopStable(loopContinuous);
end

function stableFlag = localClosedLoopStable(loopContinuous)
% 지연 포함 폐루프는 isstable 불가(내부 지연) → 루프 마진(allmargin) 판정,
% 판정 불가 시 Pade(8차) 근사 폴백
try
    loopMargins = allmargin(loopContinuous);
    if isscalar(loopMargins) && isfinite(loopMargins.Stable)
        stableFlag = logical(loopMargins.Stable);
        return
    end
catch
end
try
    stableFlag = isstable(pade(feedback(loopContinuous, 1), 8));
catch
    stableFlag = false;
end
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
