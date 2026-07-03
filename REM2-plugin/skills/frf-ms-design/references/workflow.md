# Workflow

End-to-end MATLAB order:

1. `read_frf_excel`
2. `fit_plant_model` — s-domain rational part + estimated time delay `exp(-td*s)`
3. `design_lead_lag` — lag-only (stiffness-dominant) or lead-lag (mass-dominant)
4. closed-loop frequency and step-response analysis in `run_frf_ms_workflow`
5. `plot_design_summary`

Recommended defaults:

- maximum denominator order: `6`
- target phase margin: `40 deg`
- target gain margin: `6 dB`
- controller structure: `auto` (magnitude-slope classification, threshold `-10 dB/dec`)
- digital sampling frequency: `1000 Hz`, controller discretization: ZOH
- reference frequency: `target crossover / 10`

Stability checks on the delayed loop use `allmargin` (loop margins), with `isstable(pade(feedback(L,1), 8))` as fallback. Never call `isstable` directly on a closed loop containing `exp(-td*s)`.

Validation examples:

```matlab
validate_examples
```

`validate_examples` runs a smoke test through plant fitting (including delay estimation), controller-structure selection, margin analysis, closed-loop step estimation, and summary-figure export using `examples/example_FRF1.xlsx` and `examples/example_FRF2.xlsx`. Results land in `validation_outputs/` (regenerable; excluded from packaging).
