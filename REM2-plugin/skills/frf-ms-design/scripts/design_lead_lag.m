function [controller, designInfo] = design_lead_lag(plant, targetCrossoverHz, options)
arguments
    plant
    targetCrossoverHz (1, 1) double {mustBePositive}
    options.PhaseMarginTargetDeg (1, 1) double = 40
    options.GainMarginTargetDb (1, 1) double = 6
    options.LeadAlpha (1, 1) double = NaN
    options.LagPhaseBudgetDeg (1, 1) double {mustBeNonnegative} = 10
    options.ControllerStructure (1, 1) string {mustBeMember(options.ControllerStructure, ["auto", "lag", "leadlag"])} = "auto"
    options.Implementation (1, 1) string {mustBeMember(options.Implementation, ["analog", "digital"])} = "analog"
    options.SamplingFrequencyHz (1, 1) double {mustBePositive} = 1000
end

% 랩 컨벤션: C_lead = (alpha*tau*s+1)/(tau*s+1), alpha >= 1 (Ogata 컨벤션은 alpha < 1)
if isfinite(options.LeadAlpha) && options.LeadAlpha < 1
    error("design_lead_lag:InvalidLeadAlpha", ...
        "LeadAlpha=%.4g < 1. Lab convention uses C_lead=(alpha*tau*s+1)/(tau*s+1) with alpha >= 1. If your value follows the Ogata convention (alpha < 1), convert with alpha_lab = 1/alpha_ogata.", ...
        options.LeadAlpha);
end

s = tf("s");
wc = 2*pi*targetCrossoverHz;

% digital: ZOH phase lag approximated as Ts/2 dead time in the analysis loop
if strcmpi(options.Implementation, "digital")
    % 디지털 가드: 나이퀴스트(fs/2) 초과는 오류, fs/10 초과는 경고
    if targetCrossoverHz > options.SamplingFrequencyHz/2
        error("frf_ms_design:CrossoverAboveNyquist", ...
            "Target crossover %.4g Hz exceeds the Nyquist frequency %.4g Hz (fs = %.4g Hz). Lower the target crossover or raise the controller sampling frequency.", ...
            targetCrossoverHz, options.SamplingFrequencyHz/2, options.SamplingFrequencyHz);
    elseif targetCrossoverHz > options.SamplingFrequencyHz/10
        warning("frf_ms_design:CrossoverNearNyquist", ...
            "Target crossover %.4g Hz exceeds fs/10 = %.4g Hz; ZOH phase lag will noticeably erode the margins.", ...
            targetCrossoverHz, options.SamplingFrequencyHz/10);
    end
    analysisDelaySeconds = 0.5/options.SamplingFrequencyHz;
    analysisDelay = exp(-analysisDelaySeconds*s);
else
    analysisDelaySeconds = 0;
    analysisDelay = tf(1);
end

% lab rule: flat magnitude (stiffness-dominant) -> lag only; rolling off (mass-dominant) -> lead-lag
[structureChoice, magSlopeDbPerDec] = localSelectStructure(plant, wc, options.ControllerStructure);

% use unwrapped phase: a delayed plant can sit below -360 deg, single-point wrapped phase is wrong
plantPhaseDeg = localUnwrappedPhaseAt(plant*analysisDelay, wc);

% 이득 부호별 후보 설계: 음의 이득은 루프 위상을 180 deg 이동시키므로
% 각 부호의 위상으로 리드를 별도 합성한 뒤 완성된 후보를 평가하고, 불안정 후보는 폐기
bestCandidate = [];
bestScore = -inf;
positiveCandidate = [];
for gainSign = [1, -1]
    candidate = localSynthesizeCandidate(plant, analysisDelay, s, wc, targetCrossoverHz, ...
        plantPhaseDeg, gainSign, structureChoice, options);
    if gainSign == 1
        positiveCandidate = candidate;
    end
    if ~candidate.MarginInfo.ClosedLoopStable
        continue   % 불안정 후보 폐기: margin() 수치가 좋아 보여도 무의미
    end
    score = 100*double(candidate.MarginInfo.PhaseMarginDeg >= options.PhaseMarginTargetDeg) ...
        + 100*double(candidate.MarginInfo.GainMarginDb >= options.GainMarginTargetDb) ...
        + candidate.MarginInfo.PhaseMarginDeg + min(candidate.MarginInfo.GainMarginDb, 60);
    if score > bestScore
        bestScore = score;
        bestCandidate = candidate;
    end
end

designFailed = isempty(bestCandidate);
if designFailed
    % 안정 후보 없음: +K 후보를 반환하되 모든 pass 플래그 false + DesignFailed = true
    bestCandidate = positiveCandidate;
end

if bestCandidate.LeadSaturated
    warning("design_lead_lag:LeadSaturated", ...
        "Required lead reached the 60 deg single-stage limit; phase margin target may not be met.");
end

controllerContinuous = bestCandidate.Controller;
gainK = bestCandidate.GainK;
marginInfo = bestCandidate.MarginInfo;
requiredLeadDeg = bestCandidate.RequiredLeadDeg;
alpha = bestCandidate.Alpha;
tauLead = bestCandidate.TauLead;
tauLag = bestCandidate.TauLag;

controller = struct();
controller.Continuous = controllerContinuous;
controller.Discrete = [];

if strcmpi(options.Implementation, "digital")
    ts = 1/options.SamplingFrequencyHz;
    controller.Discrete = c2d(controllerContinuous, ts, "zoh");
end

designInfo = struct();
designInfo.TargetCrossoverHz = targetCrossoverHz;
designInfo.ControllerStructure = structureChoice;
designInfo.MagSlopeDbPerDec = magSlopeDbPerDec;
designInfo.PhaseMarginTargetDeg = options.PhaseMarginTargetDeg;
designInfo.GainMarginTargetDb = options.GainMarginTargetDb;
designInfo.LagPhaseBudgetDeg = options.LagPhaseBudgetDeg;
designInfo.RequiredLeadDeg = requiredLeadDeg;
designInfo.Alpha = alpha;
designInfo.TauLead = tauLead;
designInfo.TauLag = tauLag;
designInfo.GainK = gainK;
designInfo.GainSign = sign(gainK);
designInfo.GainMargin = marginInfo.GainMargin;
designInfo.GainMarginDb = marginInfo.GainMarginDb;
designInfo.PhaseMarginDeg = marginInfo.PhaseMarginDeg;
designInfo.GainCrossoverHz = marginInfo.GainCrossoverHz;
designInfo.PhaseCrossoverHz = marginInfo.PhaseCrossoverHz;
designInfo.WorstCasePhaseMarginDeg = marginInfo.WorstCasePhaseMarginDeg;
designInfo.WorstCaseGainMarginDb = marginInfo.WorstCaseGainMarginDb;
% 불안정 루프에서 pass 를 보고하지 않음: DesignFailed 이면 무조건 false
designInfo.PassPhaseMargin = ~designFailed && designInfo.PhaseMarginDeg >= options.PhaseMarginTargetDeg;
designInfo.PassGainMargin = ~designFailed && designInfo.GainMarginDb >= options.GainMarginTargetDb;
designInfo.ClosedLoopStable = marginInfo.ClosedLoopStable;
designInfo.DesignFailed = designFailed;
designInfo.Implementation = options.Implementation;
designInfo.SamplingFrequencyHz = options.SamplingFrequencyHz;
designInfo.AnalysisDelaySeconds = analysisDelaySeconds;
end

function [structureChoice, magSlopeDbPerDec] = localSelectStructure(plant, wc, requested)
% classify by magnitude slope (dB/dec) over [wc/10, wc]
wGrid = logspace(log10(wc/10), log10(wc), 50);
magDb = 20*log10(abs(squeeze(freqresp(plant, wGrid))));
coeffs = polyfit(log10(wGrid(:)), magDb(:), 1);
magSlopeDbPerDec = coeffs(1);

if strcmpi(requested, "lag")
    structureChoice = "lag";
elseif strcmpi(requested, "leadlag")
    structureChoice = "leadlag";
else
    % -10 dB/dec threshold: flatter -> stiffness-dominant -> lag only
    if magSlopeDbPerDec > -10
        structureChoice = "lag";
    else
        structureChoice = "leadlag";
    end
end
end

function candidate = localSynthesizeCandidate(plant, analysisDelay, s, wc, targetCrossoverHz, plantPhaseDeg, gainSign, structureChoice, options)
% 부호 보정 위상: 음의 이득은 루프 위상 180 deg 이동
% (음의 DC 이득 플랜트의 언랩 앵커 +180 과 상쇄되는 -180 방향을 사용)
if gainSign < 0
    signedPhaseDeg = plantPhaseDeg - 180;
else
    signedPhaseDeg = plantPhaseDeg;
end
currentPhaseMarginDeg = 180 + signedPhaseDeg;

leadSaturated = false;
if structureChoice == "leadlag"
    % LagPhaseBudgetDeg: 적분 래그가 크로스오버에서 깎는 위상의 예산 (기본 10 deg)
    requiredLeadDeg = options.PhaseMarginTargetDeg + options.LagPhaseBudgetDeg - currentPhaseMarginDeg;
    requiredLeadDeg = min(max(requiredLeadDeg, 0), 60);   % single-stage lead limit (deg)
    leadSaturated = requiredLeadDeg >= 60;

    if isfinite(options.LeadAlpha) && options.LeadAlpha >= 1
        alpha = options.LeadAlpha;
    else
        alpha = localPhaseLeadToAlpha(requiredLeadDeg);
    end

    tauLead = 1/(wc*sqrt(alpha));
    leadController = (alpha*tauLead*s + 1)/(tauLead*s + 1);
else
    requiredLeadDeg = 0;
    alpha = 1;
    tauLead = NaN;
    leadController = tf(1);
end

% integral lag (PI form, pole at origin): Type-1 loop, zero steady-state step error
% lag-only: zero AT the target crossover -> a flat plant still crosses 0 dB at -10 dB/dec
% lead-lag: zero at crossover/10 -> lag phase does not erode PM (plant provides the slope)
if structureChoice == "lag"
    tauLag = 1/wc;
else
    tauLag = 1/(2*pi*(targetCrossoverHz/10));
end
lagController = (tauLag*s + 1)/(tauLag*s);

shapeController = leadController * lagController;
shapeAtTarget = squeeze(freqresp(shapeController*plant*analysisDelay, wc));
gainMagnitude = 1/abs(shapeAtTarget);
gainK = gainSign * gainMagnitude;
controllerContinuous = minreal(gainK * shapeController, [], false);
marginInfo = localAnalyzeLoop(controllerContinuous, plant, analysisDelay, targetCrossoverHz);

candidate = struct();
candidate.GainK = gainK;
candidate.Controller = controllerContinuous;
candidate.MarginInfo = marginInfo;
candidate.RequiredLeadDeg = requiredLeadDeg;
candidate.Alpha = alpha;
candidate.TauLead = tauLead;
candidate.TauLag = tauLag;
candidate.LeadSaturated = leadSaturated;
end

function phaseAtDeg = localUnwrappedPhaseAt(sys, wc)
% 지연-유리부 분리 언랩 위상 계산:
% 1) 유리부 위상은 unwrap(angle(freqresp)) 를 해석적 저주파 앵커에 고정
%    anchor = -90*(원점 극 수 - 원점 영점 수), 적분기 제거부 DC 이득이 음수면 +180
% 2) 지연 위상 -w*td 는 선형 항이라 랩이 없으므로 unwrap 이후에 그대로 더함
%    예: exp(-0.02*s)/s^2 의 10 Hz 위상 = -180 - 72 = -252 deg (+108 deg 가 아님)
td = totaldelay(sys);
[num, den] = tfdata(tf(sys), "v");   % tfdata 는 지연 없는 유리부 계수를 반환
rationalSys = tf(num, den);

originTol = 1e-6*wc;
polesAtOrigin = sum(abs(pole(rationalSys)) < originTol);
zerosAtOrigin = sum(abs(zero(rationalSys)) < originTol);

anchorDeg = -90*(polesAtOrigin - zerosAtOrigin);
% 적분기/미분기 제거 후 DC 이득 부호: 작은 양의 실수 s0 에서 부호 평가
s0 = max(originTol*10, wc*1e-5);
dcSignValue = real(polyval(num, s0)/polyval(den, s0));
if dcSignValue < 0
    anchorDeg = anchorDeg + 180;
end

wGrid = logspace(log10(wc) - 3, log10(wc), 400);
respGrid = squeeze(freqresp(rationalSys, wGrid));
phaseGridDeg = rad2deg(unwrap(angle(respGrid(:))));
% 그리드 시작 위상을 앵커에 가장 가까운 360 deg 분기로 이동
wrapShiftDeg = 360*round((phaseGridDeg(1) - anchorDeg)/360);
phaseGridDeg = phaseGridDeg - wrapShiftDeg;

phaseAtDeg = phaseGridDeg(end) - rad2deg(wc*td);
end

function marginInfo = localAnalyzeLoop(controllerContinuous, plant, analysisDelay, targetCrossoverHz)
loopContinuous = minreal(controllerContinuous * plant, [], false) * analysisDelay;

warningState = warning("off", "all");
cleanup = onCleanup(@() warning(warningState));

% allmargin 한 번으로 안정성 + 모든 이득/위상 교차 마진 확보 (margin() 단일값 사용 금지)
try
    loopMargins = allmargin(loopContinuous);
catch
    loopMargins = struct("GainMargin", [], "GMFrequency", [], ...
        "PhaseMargin", [], "PMFrequency", [], "Stable", NaN);
end

if isscalar(loopMargins) && isfinite(loopMargins.Stable)
    closedLoopStable = logical(loopMargins.Stable);
else
    closedLoopStable = frf_closed_loop_stable(loopContinuous);   % Pade(8) fallback 공유 헬퍼
end

wcTargetRad = 2*pi*targetCrossoverHz;

% PM: 목표 크로스오버에 가장 가까운 이득 교차에서 보고 + 최악(0 에 가장 가까운) PM
phaseMargins = loopMargins.PhaseMargin(:);
pmFrequenciesRad = loopMargins.PMFrequency(:);
finitePm = isfinite(phaseMargins) & isfinite(pmFrequenciesRad);
phaseMargins = phaseMargins(finitePm);
pmFrequenciesRad = pmFrequenciesRad(finitePm);
if isempty(phaseMargins)
    % 이득 교차 없음: 마진은 +Inf 로 정의 (pass)
    phaseMarginDeg = Inf;
    gainCrossoverHz = NaN;
    worstCasePhaseMarginDeg = Inf;
else
    [~, nearestIdx] = min(abs(pmFrequenciesRad - wcTargetRad));
    phaseMarginDeg = phaseMargins(nearestIdx);
    gainCrossoverHz = pmFrequenciesRad(nearestIdx)/(2*pi);
    [~, worstPmIdx] = min(abs(phaseMargins));
    worstCasePhaseMarginDeg = phaseMargins(worstPmIdx);
end

% GM: 0 dB 에 가장 가까운(최악) 위상 교차 마진을 대표값으로 보고
gainMargins = loopMargins.GainMargin(:);
gmFrequenciesRad = loopMargins.GMFrequency(:);
finiteGm = isfinite(gainMargins) & gainMargins > 0 & isfinite(gmFrequenciesRad);
gainMargins = gainMargins(finiteGm);
gmFrequenciesRad = gmFrequenciesRad(finiteGm);
if isempty(gainMargins)
    % 위상 교차 없음: 마진은 +Inf 로 정의 (pass)
    gainMarginDb = Inf;
    phaseCrossoverHz = NaN;
    worstCaseGainMarginDb = Inf;
else
    gainMarginsDb = 20*log10(gainMargins);
    [~, worstGmIdx] = min(abs(gainMarginsDb));
    worstCaseGainMarginDb = gainMarginsDb(worstGmIdx);
    gainMarginDb = worstCaseGainMarginDb;
    phaseCrossoverHz = gmFrequenciesRad(worstGmIdx)/(2*pi);
end

marginInfo = struct();
marginInfo.GainMargin = 10^(gainMarginDb/20);
marginInfo.GainMarginDb = gainMarginDb;
marginInfo.PhaseMarginDeg = phaseMarginDeg;
marginInfo.GainCrossoverHz = gainCrossoverHz;
marginInfo.PhaseCrossoverHz = phaseCrossoverHz;
marginInfo.WorstCasePhaseMarginDeg = worstCasePhaseMarginDeg;
marginInfo.WorstCaseGainMarginDb = worstCaseGainMarginDb;
marginInfo.ClosedLoopStable = closedLoopStable;
end

function alpha = localPhaseLeadToAlpha(phaseLeadDeg)
if phaseLeadDeg <= 0
    alpha = 1;
    return
end

phaseLeadRad = deg2rad(phaseLeadDeg);
alpha = (1 + sin(phaseLeadRad))/(1 - sin(phaseLeadRad));
alpha = max(alpha, 1);
end
