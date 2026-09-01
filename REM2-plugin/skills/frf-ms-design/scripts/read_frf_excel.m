function [frfData, metadata, warningMessages] = read_frf_excel(excelFile)
arguments
    excelFile (1, :) char
end

if ~isfile(excelFile)
    error("read_frf_excel:FileNotFound", "Excel file not found: %s", excelFile);
end

sheetNames = string(sheetnames(excelFile));
if ~any(strcmp(sheetNames, "Metadata")) || ~any(strcmp(sheetNames, "FRF"))
    error("read_frf_excel:MissingSheet", "Workbook must contain Metadata and FRF sheets.");
end

metadataRaw = readcell(excelFile, "Sheet", "Metadata");
metadata = localReadMetadata(metadataRaw);

frfRaw = readcell(excelFile, "Sheet", "FRF");
[frequencyHz, magnitudeAbs, phaseDeg] = localReadFrfColumns(frfRaw);
warningMessages = strings(0, 1);

if numel(frequencyHz) < 3
    error("read_frf_excel:InsufficientRows", "FRF sheet must contain at least three numeric rows.");
end
if any(frequencyHz <= 0)
    error("read_frf_excel:InvalidFrequency", "Frequency values must be positive.");
end
if any(magnitudeAbs < 0)
    error("read_frf_excel:InvalidMagnitude", "Magnitude values must be non-negative.");
end
% 크기 0은 이후 20*log10(0) = -Inf 로 dB 분석을 망가뜨리므로 즉시 실패
if any(magnitudeAbs == 0)
    error("read_frf_excel:ZeroMagnitude", ...
        "Magnitude must be strictly positive (20*log10(0) = -Inf breaks dB analysis); found %d zero value(s).", ...
        nnz(magnitudeAbs == 0));
end

if any(diff(frequencyHz) <= 0)
    warningMessages(end + 1, 1) = "Frequency vector was sorted because it was not strictly increasing.";
    [frequencyHz, sortIndex] = sort(frequencyHz(:));
    magnitudeAbs = magnitudeAbs(sortIndex);
    phaseDeg = phaseDeg(sortIndex);
end
% 정렬 후 중복 주파수는 FRF를 다가함수로 만들므로 실패 처리
if any(diff(frequencyHz) == 0)
    duplicatedFrequencies = unique(frequencyHz([diff(frequencyHz) == 0; false]));
    error("read_frf_excel:DuplicateFrequency", ...
        "Duplicate frequency value(s) after sorting: %s Hz. Each frequency must appear exactly once.", ...
        strjoin(string(duplicatedFrequencies(:).'), ", "));
end

% dB 의심 휴리스틱: 전 구간 1 초과 + 최대 50 초과이면 선형 abs 가 아니라 dB일 가능성
if min(magnitudeAbs) > 1 && max(magnitudeAbs) > 50
    warningMessages(end + 1, 1) = sprintf( ...
        "Magnitude column looks like dB values (min %.4g, max %.4g). Confirm with the user that Magnitude (abs) is linear absolute value, not dB.", ...
        min(magnitudeAbs), max(magnitudeAbs));
end

phaseUnwrappedDeg = rad2deg(unwrap(deg2rad(phaseDeg(:))));

% remove 360 deg wrap offset so unwrapped phase starts near 0 (complex response unchanged)
wrapShiftDeg = 360*round(phaseUnwrappedDeg(1)/360);
if wrapShiftDeg ~= 0
    warningMessages(end + 1, 1) = sprintf( ...
        "Unwrapped phase started at %.1f deg; removed %+.0f deg wrap offset.", ...
        phaseUnwrappedDeg(1), wrapShiftDeg);
    phaseUnwrappedDeg = phaseUnwrappedDeg - wrapShiftDeg;
end

% 시작 위상 점검: 0, +/-90(적분기/속도 플랜트는 정상), +/-180 deg 근처(+/-45 deg 허용)만 허용
startPhaseDeg = phaseUnwrappedDeg(1);
nearZero = abs(startPhaseDeg) <= 45;
nearNinety = abs(abs(startPhaseDeg) - 90) <= 45;
nearOneEighty = abs(abs(startPhaseDeg) - 180) <= 45;
if ~(nearZero || nearNinety || nearOneEighty)
    warningMessages(end + 1, 1) = sprintf( ...
        "Initial unwrapped phase %.1f deg is not near 0, +/-90, or +/-180 deg; check phase sign/wrap convention.", ...
        startPhaseDeg);
end
response = magnitudeAbs(:) .* exp(1j * deg2rad(phaseUnwrappedDeg));

samplingMode = string(metadata.SamplingMode);
if strcmpi(samplingMode, "이산") || strcmpi(samplingMode, "discrete")
    ts = metadata.SamplingTime;
else
    ts = 0;
end

frfData = struct();
frfData.FrequencyHz = frequencyHz(:);
frfData.WradPerSec = 2*pi*frequencyHz(:);
frfData.MagnitudeAbs = magnitudeAbs(:);
frfData.PhaseDeg = phaseDeg(:);
frfData.PhaseUnwrappedDeg = phaseUnwrappedDeg(:);
frfData.Response = response(:);
frfData.Ts = ts;
frfData.OutputUnit = metadata.OutputUnit;
frfData.InputUnit = metadata.InputUnit;
frfData.ResponseUnit = metadata.OutputUnit + "/" + metadata.InputUnit;
end

function metadata = localReadMetadata(metadataRaw)
% metadata contract is label/value pairs; fail fast before column-2 access
if size(metadataRaw, 2) < 2
    error("read_frf_excel:MetadataMissingValueColumn", ...
        "Metadata sheet must have label/value columns (2 columns); found %d.", ...
        size(metadataRaw, 2));
end
metadata = struct();
metadata.SamplingMode = localLookup(metadataRaw, ["샘플링 방식", "sampling mode"], "연속");
metadata.SamplingTime = localToDouble(localLookup(metadataRaw, ["샘플링 시간", "sampling time", "sampling time (s)"], 0), 0);
metadata.InputSignal = localLookup(metadataRaw, ["입력 신호", "input"], "");
metadata.InputUnit = string(localLookup(metadataRaw, ["입력 단위", "input unit"], ""));
metadata.OutputSignal = localLookup(metadataRaw, ["출력 신호", "output"], "");
metadata.OutputUnit = string(localLookup(metadataRaw, ["출력 단위", "output unit"], ""));
metadata.ChannelName = localLookup(metadataRaw, ["측정 대상 채널 이름", "channel name"], "");
metadata.OperatingCondition = localLookup(metadataRaw, ["운전 조건", "operating condition"], "");
end

function value = localLookup(raw, keys, defaultValue)
value = defaultValue;
for rowIndex = 1:size(raw, 1)
    label = raw{rowIndex, 1};
    if localIsBlank(label)
        continue
    end
    labelText = string(label);
    if any(strcmpi(strtrim(labelText), keys))
        candidate = raw{rowIndex, 2};
        if ~localIsBlank(candidate)
            value = candidate;
        end
        return
    end
end
end

function blank = localIsBlank(value)
if isempty(value)
    blank = true;
elseif ismissing(value)
    blank = all(ismissing(value), "all");
elseif isstring(value)
    blank = all(strlength(value) == 0, "all");
elseif ischar(value)
    blank = isempty(strtrim(value));
else
    blank = false;
end
end

function numberValue = localToDouble(value, defaultValue)
if isnumeric(value)
    numberValue = value;
elseif isstring(value) || ischar(value)
    numberValue = str2double(value);
else
    numberValue = NaN;
end
if ~isfinite(numberValue)
    numberValue = defaultValue;
end
end

function [frequencyHz, magnitudeAbs, phaseDeg] = localReadFrfColumns(frfRaw)
if isempty(frfRaw)
    error("read_frf_excel:EmptyFrfSheet", "FRF sheet is empty.");
end
headers = string(frfRaw(1, :));
headers(ismissing(headers)) = "";
expectedNames = ["Frequency (Hz)", "Magnitude (abs)", "Phase (deg)"];

% 헤더 계약은 엄격: 기대 헤더가 없으면 열 위치 추정(폴백) 없이 즉시 실패
columnIndex = zeros(1, numel(expectedNames));
for nameIdx = 1:numel(expectedNames)
    foundIndex = find(strcmpi(strtrim(headers), expectedNames(nameIdx)), 1);
    if isempty(foundIndex)
        error("read_frf_excel:MissingHeader", ...
            "Required FRF header '%s' not found. Headers found: [%s]. Expected exactly: [%s].", ...
            expectedNames(nameIdx), strjoin(headers, " | "), strjoin(expectedNames, " | "));
    end
    columnIndex(nameIdx) = foundIndex;
end

dataRows = frfRaw(2:end, :);
numRows = size(dataRows, 1);
frequencyHz = NaN(numRows, 1);
magnitudeAbs = NaN(numRows, 1);
phaseDeg = NaN(numRows, 1);
blankRowMask = false(numRows, 1);
invalidRowNumbers = [];

for rowIdx = 1:numRows
    rowCells = dataRows(rowIdx, columnIndex);
    blankMask = cellfun(@localIsBlank, rowCells);
    if all(blankMask)
        blankRowMask(rowIdx) = true;   % 완전히 빈 행만 조용히 건너뜀
        continue
    end
    rowValues = NaN(1, 3);
    for cellIdx = 1:3
        rowValues(cellIdx) = localCellToDouble(rowCells{cellIdx});
    end
    % 부분 입력 / 비숫자 / NaN / Inf 는 모두 실패 대상 행
    if any(~isfinite(rowValues))
        invalidRowNumbers(end + 1) = rowIdx + 1; %#ok<AGROW> 워크북 행 번호(헤더 포함)
        continue
    end
    frequencyHz(rowIdx) = rowValues(1);
    magnitudeAbs(rowIdx) = rowValues(2);
    phaseDeg(rowIdx) = rowValues(3);
end

if ~isempty(invalidRowNumbers)
    error("read_frf_excel:InvalidRow", ...
        "FRF sheet row(s) %s contain partially populated, non-numeric, NaN, or Inf data. Fix the workbook; only wholly blank rows are skipped.", ...
        strjoin(string(invalidRowNumbers), ", "));
end

frequencyHz = frequencyHz(~blankRowMask);
magnitudeAbs = magnitudeAbs(~blankRowMask);
phaseDeg = phaseDeg(~blankRowMask);
end

function numberValue = localCellToDouble(item)
% 셀 값을 double 로 변환: 숫자/문자만 허용, 그 외 타입은 NaN
if isnumeric(item) && isscalar(item)
    numberValue = double(item);
elseif isstring(item) || ischar(item)
    numberValue = str2double(item);
else
    numberValue = NaN;
end
end
