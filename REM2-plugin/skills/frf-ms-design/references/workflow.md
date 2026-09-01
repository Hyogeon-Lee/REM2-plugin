# Workflow

End-to-end MATLAB order:

1. `read_frf_excel`
2. `fit_plant_model` — s-domain rational part + estimated time delay `exp(-td*s)`; for each denominator order `n`, numerator zero counts `0:(n-1)` are searched (order penalty keeps simple models winning ties)
3. fit-quality gate — RMS magnitude fit error over the crossover band `[wc/2, min(10*wc, fmax)]`; `> 3 dB` appends a "plant fit unreliable near crossover; margins not trustworthy" warning, and the RMS errors are reported in `result.FitRmsMagnitudeErrorDb`, `result.FitRmsPhaseErrorDeg`, `result.CrossoverBandRmsMagnitudeErrorDb`
4. `design_lead_lag` — lag-only (stiffness-dominant) or lead-lag (mass-dominant); both gain signs synthesized and evaluated, unstable candidates discarded
5. unstable hard-fail — `DesignFailed`/unstable designs abort `run_frf_ms_workflow` with `frf_ms_design:UnstableDesign` (no result artifacts); lower the target crossover and re-run
6. closed-loop frequency and step-response analysis in `run_frf_ms_workflow` (step prediction only for a stable loop; a settling time at the simulation window edge appends a warning)
7. `plot_design_summary`

Option pass-throughs (`run_frf_ms_workflow` → scripts):

- to `fit_plant_model`: `MaxDenominatorOrder`, `TargetCrossoverHz`, `SearchAllOrders`, `EstimateTimeDelay`
- to `design_lead_lag`: `ControllerStructure`, `Implementation`, `SamplingFrequencyHz`, `PhaseMarginTargetDeg`, `GainMarginTargetDb`, `LeadAlpha`, `LagPhaseBudgetDeg`

Implementation and sampling-frequency resolution:

- `Implementation="auto"`: metadata discrete / `Ts > 0` → `digital` at the metadata rate; else `analog`.
- Digital `SamplingFrequencyHz` (default `NaN`): if `NaN`, resolved as `1/frfData.Ts` from metadata; if metadata is continuous, errors with `frf_ms_design:MissingSamplingFrequency` asking the caller for the controller rate.
- Explicit `SamplingFrequencyHz` that disagrees with metadata `Ts` (>1%) errors with `frf_ms_design:SampleRateMismatch` — measurement rate and controller rate are different quantities; `ConfirmSamplingFrequency=true` suppresses the error for a deliberate override.
- Digital bound: target crossover `> fs/2` errors (`frf_ms_design:CrossoverAboveNyquist`); `> fs/10` warns.

Recommended defaults:

- maximum denominator order: `6`
- target phase margin: `40 deg`; target gain margin: `6 dB`
- lag phase budget (`LagPhaseBudgetDeg`): `10 deg`
- controller structure: `auto` (magnitude-slope classification, threshold `-10 dB/dec`)
- lag stage: integral lag `(tau*s+1)/(tau*s)` (pole at origin → zero steady-state step error for a stable loop with finite nonzero plant DC gain and no integrator cancellation)
- lag zero placement: lag-only → AT target crossover (`tau = 1/w_target`); lead-lag → `crossover/10`
- controller discretization: ZOH at the resolved `fs`
- reference frequency: `target crossover / 10`

Margins come from ONE `allmargin` call per candidate: the stability flag plus all gain/phase crossings. `PhaseMarginDeg` is reported at the gain crossover nearest the target crossover; `WorstCasePhaseMarginDeg` / `WorstCaseGainMarginDb` report the worst case across all crossings; empty margins are `+Inf` (pass). Never call `isstable` directly on a closed loop containing `exp(-td*s)` — the shared helper `frf_closed_loop_stable` (allmargin verdict, `isstable(feedback(pade(minreal(L), 8), 1))` fallback) is the single stability oracle.

Validation examples:

```matlab
validate_examples
```

`validate_examples` is assert-based: FRF1 (analog) must be stable with both margins passing and finite fit errors; FRF2 must resolve the digital rate to `10000 Hz` from metadata `Ts = 1e-4` without an explicit `SamplingFrequencyHz`; negative tests build malformed workbooks at runtime in `tempdir` (missing header, duplicate frequency, `LeadAlpha=0.5`, `Implementation="discrete"`); and a delayed `1/s^2` regression checks that lead is requested and pass flags never accompany an unstable loop. Results land in `validation_outputs/` (regenerable; excluded from packaging).
