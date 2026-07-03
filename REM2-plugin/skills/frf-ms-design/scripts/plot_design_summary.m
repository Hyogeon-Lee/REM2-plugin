function plotInfo = plot_design_summary(frfData, plant, controller, designInfo, analysisInfo, outputDir)
arguments
    frfData (1, 1) struct
    plant
    controller (1, 1) struct %#ok<INUSA> caller API kept; controller curve intentionally not plotted
    designInfo (1, 1) struct
    analysisInfo (1, 1) struct
    outputDir (1, :) char = pwd
end

imageDir = fullfile(outputDir, "image_fig");
if ~exist(imageDir, "dir")
    mkdir(imageDir);
end

fontSize = 12;
fontName = "Times New Roman";
lineWidth = 2.0;
axLineWidth = 1.0;
gridStyle = "--";
gridAlpha = 0.25;
colorOrder = [
    0,    0,    0;
    1,    0,    0;
    0,    0,    1;
    0.9,  0.3,  0.1;
    0,    0.5,  0
];

frequencyHz = frfData.FrequencyHz(:);
w = frfData.WradPerSec(:);
measuredResponse = frfData.Response(:);
plantResponse = localFrequencyResponse(plant, w);
loopResponse = localFrequencyResponse(analysisInfo.Loop, w);
closedLoopResponse = localFrequencyResponse(analysisInfo.ClosedLoop, w);
sensitivityResponse = localFrequencyResponse(analysisInfo.Sensitivity, w);

fig = figure("Visible", "off", "Position", [100 100 1400 1200]);

axPlantMag = subplot(3, 2, 1, "Parent", fig);
semilogx(axPlantMag, frequencyHz, localMagDb(measuredResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
hold(axPlantMag, "on");
semilogx(axPlantMag, frequencyHz, localMagDb(plantResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
xline(axPlantMag, designInfo.TargetCrossoverHz, "LineStyle", ":", "Color", colorOrder(4, :), "LineWidth", lineWidth);
ylabel(axPlantMag, "Magnitude (dB)");
legend(axPlantMag, ["Measured plant", "Fitted plant", "Target crossover"], "Location", "northoutside", "NumColumns", 3, "FontSize", fontSize, "FontName", fontName);

axPlantPhase = subplot(3, 2, 2, "Parent", fig);
semilogx(axPlantPhase, frequencyHz, localPhaseDeg(measuredResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
hold(axPlantPhase, "on");
semilogx(axPlantPhase, frequencyHz, localPhaseDeg(plantResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
xline(axPlantPhase, designInfo.TargetCrossoverHz, "LineStyle", ":", "Color", colorOrder(4, :), "LineWidth", lineWidth);
ylabel(axPlantPhase, "Phase (deg)");
legend(axPlantPhase, ["Measured plant", "Fitted plant", "Target crossover"], "Location", "northoutside", "NumColumns", 3, "FontSize", fontSize, "FontName", fontName);

% controller curve omitted: its scale distorts both axes -> overlay fitted plant + open loop only
axLoopMag = subplot(3, 2, 3, "Parent", fig);
semilogx(axLoopMag, frequencyHz, localMagDb(plantResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
hold(axLoopMag, "on");
semilogx(axLoopMag, frequencyHz, localMagDb(loopResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
yline(axLoopMag, 0, "LineStyle", "--", "Color", colorOrder(5, :), "LineWidth", axLineWidth);
xline(axLoopMag, designInfo.TargetCrossoverHz, "LineStyle", ":", "Color", colorOrder(4, :), "LineWidth", lineWidth);
ylabel(axLoopMag, "Magnitude (dB)");
legend(axLoopMag, ["Fitted plant", "Open loop", "0 dB", "Target crossover"], "Location", "northoutside", "NumColumns", 4, "FontSize", fontSize, "FontName", fontName);

axLoopPhase = subplot(3, 2, 4, "Parent", fig);
semilogx(axLoopPhase, frequencyHz, localPhaseDeg(plantResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
hold(axLoopPhase, "on");
semilogx(axLoopPhase, frequencyHz, localPhaseDeg(loopResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
yline(axLoopPhase, -180, "LineStyle", "--", "Color", colorOrder(5, :), "LineWidth", axLineWidth);
xline(axLoopPhase, designInfo.TargetCrossoverHz, "LineStyle", ":", "Color", colorOrder(4, :), "LineWidth", lineWidth);
ylabel(axLoopPhase, "Phase (deg)");
legend(axLoopPhase, ["Fitted plant", "Open loop", "-180 deg", "Target crossover"], "Location", "northoutside", "NumColumns", 4, "FontSize", fontSize, "FontName", fontName);

axClosedLoop = subplot(3, 2, 5, "Parent", fig);
semilogx(axClosedLoop, frequencyHz, localMagDb(closedLoopResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
hold(axClosedLoop, "on");
semilogx(axClosedLoop, frequencyHz, localMagDb(sensitivityResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
xlabel(axClosedLoop, "Frequency (Hz)");
ylabel(axClosedLoop, "Magnitude (dB)");
legend(axClosedLoop, ["Closed loop T", "Sensitivity S"], "Location", "northoutside", "NumColumns", 2, "FontSize", fontSize, "FontName", fontName);

axStep = subplot(3, 2, 6, "Parent", fig);
plot(axStep, analysisInfo.StepTime, analysisInfo.StepResponse, "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
hold(axStep, "on");
yline(axStep, 1, "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", axLineWidth);
xlabel(axStep, "Time (s)");
ylabel(axStep, "Output (normalized)");
legend(axStep, ["Closed-loop output", "Unit reference"], "Location", "northoutside", "NumColumns", 2, "FontSize", fontSize, "FontName", fontName);

frequencyAxes = [axPlantMag, axPlantPhase, axLoopMag, axLoopPhase, axClosedLoop];
for ax = frequencyAxes
    localStyleAxes(ax, fontSize, fontName, axLineWidth, gridStyle, gridAlpha);
    xlim(ax, [min(frequencyHz), max(frequencyHz)]);
    pbaspect(ax, [2 1 1]);
end
localStyleAxes(axStep, fontSize, fontName, axLineWidth, gridStyle, gridAlpha);
xlim(axStep, [0, max(analysisInfo.StepTime)]);
pbaspect(axStep, [2 1 1]);

ylim(axPlantMag, localPadLimits([localMagDb(measuredResponse); localMagDb(plantResponse)]));
ylim(axPlantPhase, localPadLimits([localPhaseDeg(measuredResponse); localPhaseDeg(plantResponse)]));
ylim(axLoopMag, localPadLimits([localMagDb(plantResponse); localMagDb(loopResponse); 0]));
ylim(axLoopPhase, localPadLimits([localPhaseDeg(plantResponse); localPhaseDeg(loopResponse); -180]));
ylim(axClosedLoop, localPadLimits([localMagDb(closedLoopResponse); localMagDb(sensitivityResponse)]));
ylim(axStep, localPadLimits([analysisInfo.StepResponse(:); 0; 1]));
linkaxes(frequencyAxes, "x");

figPath = fullfile(imageDir, "design_summary.fig");
pngPath = fullfile(imageDir, "design_summary.png");
savefig(fig, figPath);
exportgraphics(fig, pngPath, "Resolution", 300);
close(fig);

plotInfo = struct();
plotInfo.FigurePath = figPath;
plotInfo.PngPath = pngPath;
plotInfo.GainMarginDb = designInfo.GainMarginDb;
plotInfo.PhaseMarginDeg = designInfo.PhaseMarginDeg;
plotInfo.GainCrossoverHz = designInfo.GainCrossoverHz;
plotInfo.PhaseCrossoverHz = designInfo.PhaseCrossoverHz;
plotInfo.StepInfo = analysisInfo.StepInfo;
end

function response = localFrequencyResponse(sys, w)
response = squeeze(freqresp(sys, w));
response = response(:);
end

function magnitudeDb = localMagDb(response)
magnitudeDb = 20*log10(abs(response(:)));
end

function phaseDeg = localPhaseDeg(response)
phaseDeg = rad2deg(unwrap(angle(response(:))));
end

function localStyleAxes(ax, fontSize, fontName, axLineWidth, gridStyle, gridAlpha)
set(ax, "FontSize", fontSize, "FontName", fontName, "Box", "on", "LineWidth", axLineWidth, ...
    "XGrid", "on", "YGrid", "on", "GridLineStyle", gridStyle, "GridAlpha", gridAlpha);
end

function limits = localPadLimits(values)
values = values(isfinite(values));
if isempty(values)
    limits = [-1, 1];
    return
end

minValue = min(values);
maxValue = max(values);
spanValue = maxValue - minValue;
if spanValue == 0
    spanValue = max(abs(maxValue), 1);
end
limits = [minValue - 0.05*spanValue, maxValue + 0.05*spanValue];
end
