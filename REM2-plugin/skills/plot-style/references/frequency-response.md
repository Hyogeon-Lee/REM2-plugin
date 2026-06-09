# Case: Frequency response

Bode, FRF, Nyquist, magnitude/phase vs frequency, transfer-function plots. Inherits all Common rules; overrides/adds below.

> Runnable before/after example: [`../examples/frequency_response_example.m`](../examples/frequency_response_example.m)

## Frequency axis

- **Log frequency** always. Magnitude in physical units (default) → **`loglog`** (log magnitude vs log frequency). Magnitude in dB → `semilogx` (dB is already logarithmic). **Phase → always `semilogx`** (linear deg vs log frequency).
- **Order matters — log scale first, then `hold on`.** Call `loglog`/`semilogx` to draw the **first** series, *then* `hold(ax,'on')` for the rest. Issuing `hold on` on an empty axes before the first log plot leaves the x axis linear. Never set `hold on` first.

```matlab
loglog(ax, f, mag1, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);  % 첫 plot이 로그 스케일 확정
hold(ax, 'on');                                                                             % 그 다음 hold
loglog(ax, f, mag2, 'LineStyle', '-', 'Color', colorOrder(2, :), 'LineWidth', lineWidth);
```
- Label `Frequency (Hz)` or `Frequency (rad/s)` — match the data; state which in a comment.
- Set `xlim` to the analyzed frequency range.

## Bode = two stacked panels sharing x

Magnitude (top) + phase (bottom), x axis linked:

```matlab
fig = figure;
axMag   = subplot(2, 1, 1, 'Parent', fig);
axPhase = subplot(2, 1, 2, 'Parent', fig);

loglog(axMag, f, mag, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);     % 물리 단위 magnitude
semilogx(axPhase, f, phase, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);

ylabel(axMag,   'Magnitude (mm/A)');   % 실제 물리 단위 명시 (출력/입력)
ylabel(axPhase, 'Phase (deg)');
xlabel(axPhase, 'Frequency (Hz)');     % 아래 패널만 x라벨
linkaxes([axMag, axPhase], 'x');
```

- **Magnitude ylabel = the actual physical unit of output/input**, e.g. `Magnitude (mm/A)`, `Magnitude (m/N)`, `Magnitude (V/V)` — make the unit explicit, never a bare `Magnitude`.
- Use **dB** (`20*log10(abs(H))`) only when the user asks or when comparing across very different scales; then label `Magnitude (dB)` and state the reference quantity in a comment. Default to the physical unit on a `loglog`/linear-magnitude axis.
- Phase in **degrees** (`unwrap` before converting to avoid ±360 jumps).
- Apply the Common per-axes styling, xlim/ylim to **both** axes.

## Nyquist

- Real vs imaginary of `H(jw)`; treat as an X–Y plot with **`axis equal`** (real/imag share scale).
- Mark the `-1 + 0j` critical point. Add the unit circle when assessing gain margin.
- Labels `Real Axis`, `Imaginary Axis`.

## Stability margins (optional)

- When showing gain/phase margins, annotate the 0 dB and −180° crossings with dashed reference lines (`'LineStyle', '--'`) and label the margin value.

## Notes

- Multiple systems (≤6) overlay with the style-block color order; legend per Common, `northoutside`.
- `bode`/`nyquist` built-ins produce non-conforming figures — extract data (`[mag, phase, w] = bode(sys)`) and plot manually to apply these rules.
