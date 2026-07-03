function [plant, fitInfo] = fit_plant_model(frfData, options)
arguments
    frfData (1, 1) struct
    options.MaxDenominatorOrder (1, 1) double {mustBeInteger, mustBePositive} = 6
    options.TargetCrossoverHz (1, 1) double = NaN
    options.SearchAllOrders (1, 1) logical = false
    options.EstimateTimeDelay (1, 1) logical = true
end

% s-domain 적합 강제(Ts=0): 샘플링/전송 지연은 exp(-td*s) 항으로 흡수
responseData = reshape(frfData.Response, 1, 1, []);
idData = idfrd(responseData, frfData.WradPerSec, 0, "FrequencyUnit", "rad/s");

fitOptions = tfestOptions("Display", "off");
try
    fitOptions.EnforceStability = true;
catch
end

% iodelay = NaN → tfest가 시간지연을 데이터에서 추정
if options.EstimateTimeDelay
    ioDelaySpec = NaN;
else
    ioDelaySpec = 0;
end

bestScore = inf;
plant = [];
candidateInfo = struct("DenominatorOrder", {}, "NumeratorOrder", {}, "Stable", {}, "Score", {});

denominatorOrders = 1:options.MaxDenominatorOrder;

for denominatorOrder = denominatorOrders
    if options.SearchAllOrders
        numeratorOrders = 0:(denominatorOrder - 1);
    else
        numeratorOrders = max(0, denominatorOrder - 1);
    end

    for numeratorOrder = numeratorOrders
        try
            candidateModel = tfest(idData, denominatorOrder, numeratorOrder, ioDelaySpec, fitOptions);
            candidateTf = minreal(tf(candidateModel), [], false);
            stableCandidate = isstable(candidateTf);
            score = localFitScore(candidateTf, frfData, options.TargetCrossoverHz) + 2*denominatorOrder;
        catch
            stableCandidate = false;
            score = inf;
            candidateTf = [];
        end

        candidateInfo(end + 1).DenominatorOrder = denominatorOrder; %#ok<AGROW>
        candidateInfo(end).NumeratorOrder = numeratorOrder;
        candidateInfo(end).Stable = stableCandidate;
        candidateInfo(end).Score = score;

        if stableCandidate && score < bestScore
            bestScore = score;
            plant = candidateTf;
        end
    end
end

if isempty(plant)
    error("fit_plant_model:FitFailed", "No stable transfer function model was found.");
end

% lab 표기 관례로 재구성: P(s) = (num/den) * exp(-td*s)
timeDelay = totaldelay(plant);
[num, den] = tfdata(plant, "v");
s = tf("s");
if timeDelay > 0
    plant = tf(num, den) * exp(-timeDelay*s);
else
    plant = tf(num, den);
end

[magErrorDb, phaseErrorDeg] = localFitError(plant, frfData);

fitInfo = struct();
fitInfo.Numerator = num;
fitInfo.Denominator = den;
fitInfo.TimeDelaySeconds = timeDelay;
fitInfo.CandidateInfo = candidateInfo;
fitInfo.RmsMagnitudeErrorDb = localRms(magErrorDb);
fitInfo.RmsPhaseErrorDeg = localRms(phaseErrorDeg);
fitInfo.MaxMagnitudeErrorDb = max(abs(magErrorDb), [], "omitnan");
fitInfo.MaxPhaseErrorDeg = max(abs(phaseErrorDeg), [], "omitnan");
fitInfo.Stable = isstable(plant);
end

function score = localFitScore(candidateTf, frfData, targetCrossoverHz)
[magErrorDb, phaseErrorDeg] = localFitError(candidateTf, frfData);

if isfinite(targetCrossoverHz) && targetCrossoverHz > 0
    frequencyHz = frfData.FrequencyHz;
    useIndex = frequencyHz >= targetCrossoverHz/2 & frequencyHz <= targetCrossoverHz*2;
    if nnz(useIndex) < 5
        useIndex = true(size(frequencyHz));
    end
else
    useIndex = true(size(frfData.FrequencyHz));
end

score = localRms(magErrorDb(useIndex)) + 0.02*localRms(phaseErrorDeg(useIndex));
end

function [magErrorDb, phaseErrorDeg] = localFitError(candidateTf, frfData)
modelResponse = squeeze(freqresp(candidateTf, frfData.WradPerSec));
measuredResponse = frfData.Response(:);

magErrorDb = 20*log10(abs(modelResponse(:))) - 20*log10(abs(measuredResponse));
modelPhaseDeg = rad2deg(unwrap(angle(modelResponse(:))));
measuredPhaseDeg = rad2deg(unwrap(angle(measuredResponse)));
phaseErrorDeg = localWrapTo180(modelPhaseDeg - measuredPhaseDeg);
end

function wrappedDeg = localWrapTo180(angleDeg)
wrappedDeg = mod(angleDeg + 180, 360) - 180;
end

function value = localRms(data)
data = data(isfinite(data));
if isempty(data)
    value = inf;
else
    value = sqrt(mean(data.^2));
end
end
