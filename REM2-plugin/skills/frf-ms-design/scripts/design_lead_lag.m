function [controller, designInfo] = design_lead_lag(plant, targetCrossoverHz, options)
arguments
    plant
    targetCrossoverHz (1, 1) double {mustBePositive}
    options.PhaseMarginTargetDeg (1, 1) double = 40
    options.GainMarginTargetDb (1, 1) double = 6
    options.LeadAlpha (1, 1) double = NaN
    options.ControllerStructure (1, 1) string = "auto"
    options.Implementation (1, 1) string = "analog"
    options.SamplingFrequencyHz (1, 1) double {mustBePositive} = 1000
end

s = tf("s");
wc = 2*pi*targetCrossoverHz;

% digital: ZOH phase lag approximated as Ts/2 dead time in the analysis loop
if strcmpi(options.Implementation, "digital")
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
currentPhaseMarginDeg = 180 + plantPhaseDeg;

if structureChoice == "leadlag"
    requiredLeadDeg = options.PhaseMarginTargetDeg + 10 - currentPhaseMarginDeg;
    requiredLeadDeg = min(max(requiredLeadDeg, 0), 60);   % single-stage lead limit (deg)
    if requiredLeadDeg >= 60
        warning("design_lead_lag:LeadSaturated", ...
            "Required lead reached the 60 deg single-stage limit; phase margin target may not be met.");
    end

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
[gainK, controllerContinuous, marginInfo] = localChooseGainSign(shapeController, plant, analysisDelay, gainMagnitude, options);

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
designInfo.PassPhaseMargin = designInfo.PhaseMarginDeg >= options.PhaseMarginTargetDeg;
designInfo.PassGainMargin = designInfo.GainMarginDb >= options.GainMarginTargetDb;
designInfo.ClosedLoopStable = marginInfo.ClosedLoopStable;
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

function phaseAtDeg = localUnwrappedPhaseAt(sys, wc)
% unwrap from 3 decades below wc; align the start to the nearest 0/+-180 deg
wGrid = logspace(log10(wc) - 3, log10(wc), 400);
respGrid = squeeze(freqresp(sys, wGrid));
phaseGridDeg = rad2deg(unwrap(angle(respGrid(:))));
phaseGridDeg = phaseGridDeg - 360*round(phaseGridDeg(1)/360);
phaseAtDeg = phaseGridDeg(end);
end

function [gainK, controllerContinuous, bestInfo] = localChooseGainSign(shapeController, plant, analysisDelay, gainMagnitude, options)
bestScore = -inf;
gainK = gainMagnitude;
controllerContinuous = minreal(gainMagnitude * shapeController, [], false);
bestInfo = localAnalyzeLoop(controllerContinuous, plant, analysisDelay);

for gainSign = [1, -1]
    candidateGain = gainSign * gainMagnitude;
    candidateController = minreal(candidateGain * shapeController, [], false);
    candidateInfo = localAnalyzeLoop(candidateController, plant, analysisDelay);

    stableScore = 1000 * double(candidateInfo.ClosedLoopStable);
    marginScore = candidateInfo.PhaseMarginDeg + min(candidateInfo.GainMarginDb, 60);
    passScore = 100 * double(candidateInfo.PhaseMarginDeg >= options.PhaseMarginTargetDeg) ...
        + 100 * double(candidateInfo.GainMarginDb >= options.GainMarginTargetDb);
    score = stableScore + passScore + marginScore;

    if score > bestScore
        bestScore = score;
        gainK = candidateGain;
        controllerContinuous = candidateController;
        bestInfo = candidateInfo;
    end
end
end

function marginInfo = localAnalyzeLoop(controllerContinuous, plant, analysisDelay)
loopContinuous = minreal(controllerContinuous * plant, [], false) * analysisDelay;
closedLoopStable = localClosedLoopStable(loopContinuous);

warningState = warning("off", "all");
cleanup = onCleanup(@() warning(warningState));
% margin output order: [Gm, Pm, Wcg (phase xover), Wcp (gain xover)]
[gainMargin, phaseMargin, phaseCrossRad, gainCrossRad] = margin(loopContinuous);

marginInfo = struct();
marginInfo.GainMargin = gainMargin;
marginInfo.GainMarginDb = 20*log10(gainMargin);
marginInfo.PhaseMarginDeg = phaseMargin;
marginInfo.GainCrossoverHz = gainCrossRad/(2*pi);
marginInfo.PhaseCrossoverHz = phaseCrossRad/(2*pi);
marginInfo.ClosedLoopStable = closedLoopStable;
end

function stableFlag = localClosedLoopStable(loopContinuous)
% isstable fails on delayed closed loops (internal delay) -> allmargin verdict, Pade(8) fallback
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

function alpha = localPhaseLeadToAlpha(phaseLeadDeg)
if phaseLeadDeg <= 0
    alpha = 1;
    return
end

phaseLeadRad = deg2rad(phaseLeadDeg);
alpha = (1 + sin(phaseLeadRad))/(1 - sin(phaseLeadRad));
alpha = max(alpha, 1);
end
