# Excel Format

Blank template: `examples/format_FRF.xlsx`. Filled examples: `examples/example_FRF1.xlsx`, `examples/example_FRF2.xlsx`.

Required sheets:

- `Metadata`
- `FRF`

`FRF` required columns:

```text
Frequency (Hz) | Magnitude (abs) | Phase (deg)
```

Rules:

- Read numeric rows only.
- Row count is variable.
- Treat magnitude as linear absolute value.
- Treat phase as degrees.
- Treat plant as `output/input`.
- Sort non-monotonic frequency internally and report a warning.
- Reject non-positive frequency and negative magnitude.
- Malformed workbooks (missing sheets, missing data/value columns) fail fast with `read_frf_excel:*` errors — ask the user for a corrected file instead of patching around the format.

Useful metadata fields:

- sampling mode
- sampling time
- input signal / input unit
- output signal / output unit
- channel name
- operating condition
