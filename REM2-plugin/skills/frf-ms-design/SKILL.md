---
name: frf-ms-design
description: MATLAB workflow for measured SISO FRF Excel files. Use when fitting a stable s-domain plant model with a time-delay term from FRF data, designing a lag or lead-lag controller with integral lag, plotting plant/open-loop/closed-loop frequency responses with margin analysis, or estimating closed-loop step-response behavior — including korean requests like FRF 피팅, 플랜트 모델 피팅, 제어기 설계, 리드-래그/래그 설계, 위상 여유, 루프쉐이핑, 측정 FRF 엑셀 처리.
---

# FRF M&S Design

Requires: System Identification Toolbox, Control System Toolbox.

Use this skill for measured SISO FRF data stored in the lab Excel format:

- `Metadata` sheet: measurement and signal metadata
- `FRF` sheet: `Frequency (Hz)`, `Magnitude (abs)`, `Phase (deg)`

Assume `Plant = output/input`, magnitude is linear `abs`, phase is `deg`, frequency is `Hz`, and the plant is stable. A blank template workbook is provided at `examples/format_FRF.xlsx`.

If the workbook does not match this format, `read_frf_excel` fails fast with a `read_frf_excel:*` error. Do NOT patch around it — report the error to the user, point to `examples/format_FRF.xlsx`, and ask for a corrected file.

## Plant Model Convention

Always fit in the continuous s-domain with an explicit time-delay term:

```text
P(s) = B(s)/A(s) * exp(-td*s)
```

- `tfest` runs with `iodelay = NaN` so the delay `td` is estimated from the FRF data.
- Sampling and transport delays are absorbed into `exp(-td*s)`; the rational part stays low order.
- Closed-loop stability of a delayed loop CANNOT use `isstable(feedback(...))` (internal-delay error). Use loop margins (`allmargin`) with a Pade-approximation fallback, as implemented in the scripts.

## Workflow

1. Read the Excel file with `scripts/read_frf_excel.m`.
2. Fit a stable transfer function (rational part + delay) with `scripts/fit_plant_model.m`.
3. Design the controller with `scripts/design_lead_lag.m`.
4. Run closed-loop frequency and step-response analysis with `scripts/run_frf_ms_workflow.m`.
5. Generate one summary figure with `scripts/plot_design_summary.m`.

Workflow rules (MUST follow):

- MUST ask the user for the target crossover frequency and the `analog`/`digital` choice BEFORE an end-to-end run. The built-in defaults (auto target crossover, auto implementation) are smoke-test fallbacks only and require explicit user confirmation — the result appends `"auto default target crossover X Hz — confirm with the user"` to `WarningMessages` whenever the auto default was used.
- MUST report `result.WarningMessages` and the fit RMS errors (`result.FitRmsMagnitudeErrorDb`, `result.FitRmsPhaseErrorDeg`, `result.CrossoverBandRmsMagnitudeErrorDb`) to the user after every run.
- If the crossover-band RMS magnitude error exceeds `3 dB`, present the design as unreliable: the fitted model does not track the measurement near crossover, so the reported margins are not trustworthy.

For an end-to-end run, use:

```matlab
result = run_frf_ms_workflow(excelFile, outputDir, ...
    TargetCrossoverHz=targetHz, ...
    MaxDenominatorOrder=6);
```

## User Inputs To Collect

Ask for these values when not provided:

- target open-loop crossover frequency in Hz (REQUIRED — never rely on the auto default without confirmation)
- controller implementation: `analog` or `digital` (REQUIRED — `auto` resolves from metadata: discrete / `Ts > 0` → digital at the metadata rate, else analog)
- digital controller sampling frequency (`SamplingFrequencyHz`): if omitted, resolved from metadata `Ts`; if metadata is continuous, the workflow errors and the user must supply it
- maximum plant denominator order, default `6`
- controller structure: `auto` (default), `lag`, or `leadlag`
- manual lead ratio override (`LeadAlpha`), when the user wants to fix the lead stage (lab convention `alpha >= 1`; an Ogata-convention value `alpha < 1` is rejected — convert with `alpha_lab = 1/alpha_ogata`)
- lag phase budget (`LagPhaseBudgetDeg`, default `10 deg`): phase reserve subtracted for the integral lag when computing the required lead

Metadata `Ts` is the MEASUREMENT sampling rate — its delay effect is already inside the measured FRF and the estimated `td` — while `SamplingFrequencyHz` is the CONTROLLER rate whose `Ts/2` delay models only the controller ZOH; they are different quantities, and a mismatch between an explicit `SamplingFrequencyHz` and metadata `Ts` raises `frf_ms_design:SampleRateMismatch` unless `ConfirmSamplingFrequency=true` is passed for a deliberate override.

## Controller Structure Rule (lab convention)

Classify the plant from the fitted-model magnitude slope over `[crossover/10, crossover]`:

- **Stiffness-dominant** (flat magnitude over a wide band, slope > `-10 dB/dec`): use a **lag controller only**. Do not add lead.
- **Mass-dominant** (continuously decreasing magnitude, slope <= `-10 dB/dec`): use **lead-lag**.

`design_lead_lag` applies this automatically with `ControllerStructure="auto"`; override with `"lag"` or `"leadlag"` when the user asks.

## Lead-Lag Convention

Use the lab convention (lead stage omitted, `C_lead = 1`, for stiffness-dominant plants):

```text
C(s) = K * C_lead(s) * C_lag(s)
C_lead(s) = (alpha*tau*s + 1)/(tau*s + 1)
C_lag(s)  = (tau*s + 1)/(tau*s)
```

The lag stage is INTEGRAL lag (PI form): its pole sits at the origin, so the loop is Type 1 and — provided the closed loop is stable, the plant DC gain is finite and nonzero, and nothing cancels the controller integrator — the closed-loop step response settles at exactly 1 (zero steady-state error). Never use the finite-pole form `(tau*s+1)/(beta*tau*s+1)` — it leaves a `1/(1+K*P(0))` steady-state offset.

Design sequence:

1. Classify the plant (stiffness- vs mass-dominant) to pick lag-only or lead-lag.
2. For lead-lag, place lead action near the target crossover using the UNWRAPPED plant phase (never single-point wrapped phase; a delayed plant can be below -360 deg).
3. Place the lag zero:
   - **lag-only** (flat plant): zero AT the target crossover (`tau = 1/w_target`). Do NOT use the `/10` rule here — a flat plant provides no magnitude slope, so a lag whose zero sits a decade below crossover leaves the loop grazing 0 dB with no visible gain crossover. The zero at `w_target` gives the loop a `-10 dB/dec` slope through 0 dB; the crossover is then set by `K * C_lag`.
   - **lead-lag** (rolling-off plant): zero at `target crossover / 10` so the lag phase does not erode the phase margin at crossover; the plant itself provides the crossing slope.
4. Tune `K` so `|C(jw)P(jw)| = 1` at the target crossover. Both gain signs (`+K`, `-K`) are synthesized and evaluated as complete candidates; any candidate whose closed loop is unstable is discarded. If NO stable candidate exists, `design_lead_lag` returns the `+K` candidate with all pass flags false and `DesignFailed = true`, and `run_frf_ms_workflow` hard-fails with `frf_ms_design:UnstableDesign`.
5. Check `PM >= 40 deg` and `GM >= 6 dB` from loop margins.

Margin reporting is `allmargin`-based (one call: stability flag plus ALL gain/phase crossings). `PhaseMarginDeg` is the PM at the gain crossover NEAREST the target crossover; `WorstCasePhaseMarginDeg` / `WorstCaseGainMarginDb` report the worst case across all crossings. Empty margins (no crossing) are defined as `+Inf` (pass). Margins are never reported as passing for an unstable loop.

Redesign guidance by failure mode:

- `PassGainMargin` false on a lag-only design: for a stiffness-dominant (flat) plant, the lag-only loop flattens about `-3 dB` below 0 dB above the crossover (zero-at-crossover placement), so `GM` is bounded by where the plant roll-off finally pulls the loop down. Move the target crossover toward the plant roll-off region or lower it, then redesign; do NOT add lead to fix this.
- `PassPhaseMargin` false after lead saturation (`RequiredLeadDeg` clamped at the lab 60 deg single-stage limit): lower the target crossover; never exceed the 60 deg lead limit or stack lead stages.
- `DesignFailed` / unstable: hard stop — no result artifacts are produced. Lower the target crossover and re-run.

## Digital Implementation

- Controller sampling frequency `fs`: resolved from metadata `Ts` when `SamplingFrequencyHz` is not given; if metadata is continuous, the workflow errors and asks for `fs` explicitly. An explicit `fs` that disagrees with metadata `Ts` errors (`frf_ms_design:SampleRateMismatch`) unless `ConfirmSamplingFrequency=true`.
- Discretize the controller with ZOH: `c2d(C, 1/fs, "zoh")`.
- Margin and step analysis include the ZOH phase lag approximated as `exp(-s*Ts/2)` so digital margins are not optimistic.
- Digital bound: the target crossover MUST be below `fs/2` (error `frf_ms_design:CrossoverAboveNyquist`) and ideally at or below `fs/10` (warning above it — ZOH phase lag noticeably erodes the margins).

## Output

Generate a project output folder containing:

- fitted plant model (rational part, delay `td`) and controller data
- plant, open-loop, closed-loop `T`, and sensitivity `S` frequency responses (controller curve is intentionally not plotted — its scale distorts the axes)
- margin summary
- expected unit-step response and step-response characteristics
- one `image_fig/design_summary.png` and editable `design_summary.fig`

## Validation

Run `scripts/validate_examples.m` for an assert-based validation of the bundled examples (`examples/example_FRF1.xlsx`, `examples/example_FRF2.xlsx`), fail-fast negative tests on runtime-generated malformed workbooks, and a control-theory regression on a delayed `1/s^2` plant. Outputs regenerate under `validation_outputs/` (disposable; do not package).

## References

- `references/excel_format.md`: expected workbook format
- `references/workflow.md`: script responsibilities and execution order
