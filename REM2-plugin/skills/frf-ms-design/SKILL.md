---
name: frf-ms-design
description: MATLAB workflow for measured SISO FRF Excel files. Use when fitting a stable s-domain plant model with a time-delay term from FRF data, designing a lag or lead-lag controller, plotting plant/controller/open-loop/closed-loop frequency responses with margin analysis, or estimating closed-loop step-response behavior.
---

# FRF M&S Design

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

For an end-to-end run, use:

```matlab
result = run_frf_ms_workflow(excelFile, outputDir, ...
    TargetCrossoverHz=targetHz, ...
    MaxDenominatorOrder=6);
```

## User Inputs To Collect

Ask for these values when not provided:

- target open-loop crossover frequency in Hz
- controller implementation: `analog` or `digital`
- digital sampling frequency, default `1000 Hz`
- maximum plant denominator order, default `6`
- controller structure: `auto` (default), `lag`, or `leadlag`
- lead/lag manual tuning preference

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

The lag stage is INTEGRAL lag (PI form): its pole sits at the origin, so the loop is Type 1 and the closed-loop step response settles at exactly 1 (zero steady-state error). Never use the finite-pole form `(tau*s+1)/(beta*tau*s+1)` — it leaves a `1/(1+K*P(0))` steady-state offset.

Design sequence:

1. Classify the plant (stiffness- vs mass-dominant) to pick lag-only or lead-lag.
2. For lead-lag, place lead action near the target crossover using the UNWRAPPED plant phase (never single-point wrapped phase; a delayed plant can be below -360 deg).
3. Place the lag zero:
   - **lag-only** (flat plant): zero AT the target crossover (`tau = 1/w_target`). Do NOT use the `/10` rule here — a flat plant provides no magnitude slope, so a lag whose zero sits a decade below crossover leaves the loop grazing 0 dB with no visible gain crossover. The zero at `w_target` gives the loop a `-10 dB/dec` slope through 0 dB; the crossover is then set by `K * C_lag`.
   - **lead-lag** (rolling-off plant): zero at `target crossover / 10` so the lag phase does not erode the phase margin at crossover; the plant itself provides the crossing slope.
4. Tune `K` so `|C(jw)P(jw)| = 1` at the target crossover.
5. Check `PM >= 40 deg` and `GM >= 6 dB` from loop margins.

For a stiffness-dominant (flat) plant, the lag-only loop flattens about `-3 dB` below 0 dB above the crossover (zero-at-crossover placement), so `GM` is bounded by where the plant roll-off finally pulls the loop down. If `PassGainMargin` is false, move the target crossover toward the plant roll-off region or lower it, then redesign; do not add lead to fix this.

## Digital Implementation

- Discretize the controller with ZOH: `c2d(C, 1/fs, "zoh")`, default `fs = 1000 Hz`.
- Margin and step analysis include the ZOH phase lag approximated as `exp(-s*Ts/2)` so digital margins are not optimistic.

## Output

Generate a project output folder containing:

- fitted plant model (rational part, delay `td`) and controller data
- plant, controller, open-loop, and expected closed-loop frequency responses
- margin summary
- expected unit-step response and step-response characteristics
- one `image_fig/design_summary.png` and editable `design_summary.fig`

## Validation

Run `scripts/validate_examples.m` for a smoke test on the bundled examples (`examples/example_FRF1.xlsx`, `examples/example_FRF2.xlsx`). Outputs regenerate under `validation_outputs/` (disposable; do not package).

## References

- `references/excel_format.md`: expected workbook format
- `references/workflow.md`: script responsibilities and execution order
