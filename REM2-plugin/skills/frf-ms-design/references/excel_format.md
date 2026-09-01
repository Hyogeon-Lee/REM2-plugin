# Excel Format

Blank template: `examples/format_FRF.xlsx`. Filled examples: `examples/example_FRF1.xlsx`, `examples/example_FRF2.xlsx`.

Required sheets:

- `Metadata`
- `FRF`

## FRF sheet — strict header contract

The header row must contain these EXACT column names (case-insensitive match after trimming; no positional fallback of any kind):

```text
Frequency (Hz) | Magnitude (abs) | Phase (deg)
```

If any expected header is missing, `read_frf_excel` fails with `read_frf_excel:MissingHeader`, listing the headers it actually found. It never guesses columns by position.

Data-row rules:

- Only WHOLLY blank rows are skipped silently.
- Partially populated, non-numeric, `NaN`, or `Inf` rows fail with `read_frf_excel:InvalidRow`, listing the offending workbook row numbers.
- Row count is variable (at least three valid rows; `read_frf_excel:InsufficientRows`).
- Treat magnitude as linear absolute value; treat phase as degrees; treat plant as `output/input`.
- Non-positive frequency fails with `read_frf_excel:InvalidFrequency`; negative magnitude fails with `read_frf_excel:InvalidMagnitude`.
- Magnitude exactly `0` fails with `read_frf_excel:ZeroMagnitude` (`20*log10(0) = -Inf` breaks dB analysis).
- Non-monotonic frequency is sorted internally with a warning; any duplicate frequency remaining after sorting fails with `read_frf_excel:DuplicateFrequency`.
- If the magnitude column looks like dB values (all values `> 1` and max `> 50`), a warning is appended — confirm with the user that the column is linear `abs`, not dB.

Malformed workbooks (missing sheets, missing headers, invalid rows) fail fast with `read_frf_excel:*` errors — ask the user for a corrected file instead of patching around the format.

## Metadata sheet — bundled template layout

The real bundled template (`examples/format_FRF.xlsx`) uses a Korean 4-column Metadata sheet:

```text
항목 | 값 | 단위 / 선택지 | 설명
```

`read_frf_excel` reads only the first two columns as label/value pairs (`read_frf_excel:MetadataMissingValueColumn` if fewer than 2 columns); the 단위/설명 columns, section-header rows, and any unused metadata keys are ignored by the scripts.

Metadata keys used by the scripts (Korean or English labels):

- `샘플링 방식` / sampling mode (`연속` or `이산`; discrete makes `frfData.Ts > 0`)
- `샘플링 시간` / sampling time (s) — the MEASUREMENT rate, not the controller rate
- `입력 신호` / input, `입력 단위` / input unit
- `출력 신호` / output, `출력 단위` / output unit
- `측정 대상 채널 이름` / channel name
- `운전 조건` / operating condition
