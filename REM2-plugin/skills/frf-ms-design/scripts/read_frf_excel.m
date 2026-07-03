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
[frequencyHz, magnitudeAbs, phaseDeg, headerWarnings] = localReadFrfColumns(frfRaw);
warningMessages = headerWarnings;

validRows = isfinite(frequencyHz) & isfinite(magnitudeAbs) & isfinite(phaseDeg);
frequencyHz = frequencyHz(validRows);
magnitudeAbs = magnitudeAbs(validRows);
phaseDeg = phaseDeg(validRows);

if numel(frequencyHz) < 3
    error("read_frf_excel:InsufficientRows", "FRF sheet must contain at least three numeric rows.");
end
if any(frequencyHz <= 0)
    error("read_frf_excel:InvalidFrequency", "Frequency values must be positive.");
end
if any(magnitudeAbs < 0)
    error("read_frf_excel:InvalidMagnitude", "Magnitude values must be non-negative.");
end

if any(diff(frequencyHz) <= 0)
    warningMessages(end + 1, 1) = "Frequency vector was sorted because it was not strictly increasing.";
    [frequencyHz, sortIndex] = sort(frequencyHz(:));
    magnitudeAbs = magnitudeAbs(sortIndex);
    phaseDeg = phaseDeg(sortIndex);
end

phaseUnwrappedDeg = rad2deg(unwrap(deg2rad(phaseDeg(:))));

% 언랩 시작 위상 정렬: 360 deg 배수 offset 제거 (복소 응답 불변)
wrapShiftDeg = 360*round(phaseUnwrappedDeg(1)/360);
if wrapShiftDeg ~= 0
    warningMessages(end + 1, 1) = sprintf( ...
        "Unwrapped phase started at %.1f deg; removed %+.0f deg wrap offset.", ...
        phaseUnwrappedDeg(1), wrapShiftDeg);
    phaseUnwrappedDeg = phaseUnwrappedDeg - wrapShiftDeg;
end

% 시작 위상이 0 또는 ±180 deg 부근(±45 deg)이 아니면 wrap/부호 관례 확인 경고
startPhaseDeg = phaseUnwrappedDeg(1);
if abs(startPhaseDeg) > 45 && abs(abs(startPhaseDeg) - 180) > 45
    warningMessages(end + 1, 1) = sprintf( ...
        "Initial unwrapped phase %.1f deg is not near 0 or +/-180 deg; check phase sign/wrap convention.", ...
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

function [frequencyHz, magnitudeAbs, phaseDeg, headerWarnings] = localReadFrfColumns(frfRaw)
headers = string(frfRaw(1, :));
headerWarnings = strings(0, 1);
[frequencyCol, headerWarnings] = localFindHeader(headers, "Frequency (Hz)", 1, headerWarnings);
[magnitudeCol, headerWarnings] = localFindHeader(headers, "Magnitude (abs)", 2, headerWarnings);
[phaseCol, headerWarnings] = localFindHeader(headers, "Phase (deg)", 3, headerWarnings);

frequencyHz = localNumericColumn(frfRaw(2:end, frequencyCol));
magnitudeAbs = localNumericColumn(frfRaw(2:end, magnitudeCol));
phaseDeg = localNumericColumn(frfRaw(2:end, phaseCol));
end

function [columnIndex, headerWarnings] = localFindHeader(headers, expectedName, fallbackIndex, headerWarnings)
columnIndex = find(strcmpi(strtrim(headers), expectedName), 1);
if isempty(columnIndex)
    columnIndex = fallbackIndex;
    headerWarnings(end + 1, 1) = sprintf( ...
        "Header '%s' not found; falling back to column %d. Verify the FRF sheet layout.", ...
        expectedName, fallbackIndex);
end
end

function values = localNumericColumn(rawColumn)
values = NaN(numel(rawColumn), 1);
for idx = 1:numel(rawColumn)
    item = rawColumn{idx};
    if isnumeric(item)
        values(idx) = item;
    elseif isstring(item) || ischar(item)
        values(idx) = str2double(item);
    end
end
end
