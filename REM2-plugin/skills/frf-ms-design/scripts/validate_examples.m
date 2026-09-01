% 번들 예제 + 음성 테스트 + 제어이론 회귀 검증 스크립트 (assert 기반)
scriptPath = mfilename("fullpath");
scriptsDir = fileparts(scriptPath);
skillRoot = fileparts(scriptsDir);
addpath(scriptsDir);

examples = ["example_FRF1.xlsx", "example_FRF2.xlsx"];
exampleDir = fullfile(skillRoot, "examples");
validationRoot = fullfile(skillRoot, "validation_outputs");
if ~exist(validationRoot, "dir")
    mkdir(validationRoot);
end

validationResults = struct([]);

%% FRF1 (analog): 안정 설계 + 양쪽 마진 통과 + 피팅 오차 유한
excelFile = fullfile(exampleDir, examples(1));
[~, exampleName] = fileparts(excelFile);
outputDir = fullfile(validationRoot, exampleName);
result = run_frf_ms_workflow(char(excelFile), char(outputDir), ...
    MaxDenominatorOrder=6, ...
    Implementation="analog");
assert(~result.DesignInfo.DesignFailed && result.DesignInfo.ClosedLoopStable, ...
    "FRF1: design must be closed-loop stable.");
assert(result.DesignInfo.PassPhaseMargin && result.DesignInfo.PassGainMargin, ...
    "FRF1: both phase and gain margins must pass.");
assert(isfinite(result.FitRmsMagnitudeErrorDb) && isfinite(result.FitRmsPhaseErrorDeg) ...
    && isfinite(result.CrossoverBandRmsMagnitudeErrorDb), ...
    "FRF1: fit RMS errors must be finite.");
validationResults(1).Example = examples(1);
validationResults(1).OutputDir = outputDir;
validationResults(1).Result = result;

%% FRF2: fs 미지정 -> 메타데이터 Ts=1e-4 로부터 디지털 10000 Hz 로 해석되어야 함
excelFile = fullfile(exampleDir, examples(2));
[~, exampleName] = fileparts(excelFile);
outputDir = fullfile(validationRoot, exampleName);
result = run_frf_ms_workflow(char(excelFile), char(outputDir), ...
    MaxDenominatorOrder=6);
assert(strcmpi(result.DesignInfo.Implementation, "digital"), ...
    "FRF2: metadata (discrete, Ts>0) must resolve to a digital design.");
assert(abs(result.DesignInfo.SamplingFrequencyHz - 10000) < 1e-6, ...
    "FRF2: resolved controller rate must be 10000 Hz from metadata Ts=1e-4, got %.6g Hz.", ...
    result.DesignInfo.SamplingFrequencyHz);
assert(~result.DesignInfo.DesignFailed && result.DesignInfo.ClosedLoopStable, ...
    "FRF2: design must be closed-loop stable.");
validationResults(2).Example = examples(2);
validationResults(2).OutputDir = outputDir;
validationResults(2).Result = result;

for idx = 1:numel(validationResults)
    result = validationResults(idx).Result;
    fprintf("%s: target %.3f Hz, structure %s, delay %.4g s, PM %.2f deg, GM %.2f dB, stable %d, band RMS %.2f dB\n", ...
        validationResults(idx).Example, ...
        result.DesignInfo.TargetCrossoverHz, ...
        result.DesignInfo.ControllerStructure, ...
        result.FitInfo.TimeDelaySeconds, ...
        result.DesignInfo.PhaseMarginDeg, ...
        result.DesignInfo.GainMarginDb, ...
        result.DesignInfo.ClosedLoopStable, ...
        result.CrossoverBandRmsMagnitudeErrorDb);
end

%% 음성 테스트: 런타임 생성 워크북 (examples/ 는 절대 수정하지 않음)
negativeDir = fullfile(tempdir, "frf_ms_design_negative_" + ...
    string(datetime("now", "Format", "yyyyMMdd_HHmmssSSS")));
mkdir(negativeDir);
metadataCell = {'샘플링 방식', '연속'; '샘플링 시간', 0};

% 1) 헤더 누락 -> read_frf_excel:MissingHeader (위치 기반 폴백 없음)
badHeaderFile = fullfile(negativeDir, "bad_header.xlsx");
writecell(metadataCell, badHeaderFile, "Sheet", "Metadata");
writecell([{'Freq', 'Mag', 'Phase'}; num2cell([1 1 0; 2 1 -10; 4 1 -20])], ...
    badHeaderFile, "Sheet", "FRF");
errorId = localExpectedErrorId(@() read_frf_excel(char(badHeaderFile)));
assert(errorId == "read_frf_excel:MissingHeader", ...
    "Missing header must raise read_frf_excel:MissingHeader, got '%s'.", errorId);

% 2) 중복 주파수 -> read_frf_excel:DuplicateFrequency
duplicateFile = fullfile(negativeDir, "duplicate_frequency.xlsx");
writecell(metadataCell, duplicateFile, "Sheet", "Metadata");
writecell([{'Frequency (Hz)', 'Magnitude (abs)', 'Phase (deg)'}; ...
    num2cell([1 1 0; 2 1 -10; 2 1 -12; 4 1 -20])], ...
    duplicateFile, "Sheet", "FRF");
errorId = localExpectedErrorId(@() read_frf_excel(char(duplicateFile)));
assert(errorId == "read_frf_excel:DuplicateFrequency", ...
    "Duplicate frequency must raise read_frf_excel:DuplicateFrequency, got '%s'.", errorId);

% 3) LeadAlpha=0.5 (Ogata 컨벤션) -> 오류
errorId = localExpectedErrorId(@() design_lead_lag(tf(1, [1 1]), 10, LeadAlpha=0.5));
assert(errorId == "design_lead_lag:InvalidLeadAlpha", ...
    "LeadAlpha < 1 must raise design_lead_lag:InvalidLeadAlpha, got '%s'.", errorId);

% 4) Implementation="discrete" -> mustBeMember 오류
errorId = localExpectedErrorId(@() design_lead_lag(tf(1, [1 1]), 10, Implementation="discrete"));
assert(strlength(errorId) > 0, "Implementation=""discrete"" must raise a validation error.");

rmdir(negativeDir, "s");   % 임시 워크북 정리

%% 제어이론 회귀: exp(-0.02*s)/s^2, 목표 10 Hz
% 언랩 위상 -252 deg -> 리드 요구 > 0; 불안정 루프에서 pass 플래그 금지
delayedPlant = tf(1, [1 0 0], "IODelay", 0.02);
[~, delayedInfo] = design_lead_lag(delayedPlant, 10);
assert(delayedInfo.RequiredLeadDeg > 0 || delayedInfo.ControllerStructure == "leadlag", ...
    "Delayed 1/s^2 must request lead (or select the leadlag structure).");
assert(~(delayedInfo.PassPhaseMargin && delayedInfo.PassGainMargin && ~delayedInfo.ClosedLoopStable), ...
    "Pass flags must never both be true for an unstable loop.");

save(fullfile(validationRoot, "validation_results.mat"), "validationResults");
fprintf("validate_examples: all assertions passed.\n");

%% 로컬 함수
function errorId = localExpectedErrorId(callable)
% 호출에서 발생한 오류 식별자 수집 (오류 없으면 빈 문자열)
errorId = "";
try
    callable();
catch caughtError
    errorId = string(caughtError.identifier);
end
end
