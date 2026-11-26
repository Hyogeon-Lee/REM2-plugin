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
legendMaxHeightFrac = 0.4;   % legend band above this share of the plot-box height -> northoutside
yTickInsetFrac = 0.05;       % gap between the outermost y ticks and the box edges
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
lgdPlantMag = legend(axPlantMag, ["Measured plant", "Fitted plant", "Target crossover"], "Location", "northeast", "NumColumns", 1, "FontSize", fontSize, "FontName", fontName);

axPlantPhase = subplot(3, 2, 2, "Parent", fig);
semilogx(axPlantPhase, frequencyHz, localPhaseDeg(measuredResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
hold(axPlantPhase, "on");
semilogx(axPlantPhase, frequencyHz, localPhaseDeg(plantResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
xline(axPlantPhase, designInfo.TargetCrossoverHz, "LineStyle", ":", "Color", colorOrder(4, :), "LineWidth", lineWidth);
ylabel(axPlantPhase, "Phase (deg)");
lgdPlantPhase = legend(axPlantPhase, ["Measured plant", "Fitted plant", "Target crossover"], "Location", "northeast", "NumColumns", 1, "FontSize", fontSize, "FontName", fontName);

% controller curve omitted: its scale distorts both axes -> overlay fitted plant + open loop only
axLoopMag = subplot(3, 2, 3, "Parent", fig);
semilogx(axLoopMag, frequencyHz, localMagDb(plantResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
hold(axLoopMag, "on");
semilogx(axLoopMag, frequencyHz, localMagDb(loopResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
yline(axLoopMag, 0, "LineStyle", "--", "Color", colorOrder(5, :), "LineWidth", axLineWidth);
xline(axLoopMag, designInfo.TargetCrossoverHz, "LineStyle", ":", "Color", colorOrder(4, :), "LineWidth", lineWidth);
ylabel(axLoopMag, "Magnitude (dB)");
lgdLoopMag = legend(axLoopMag, ["Fitted plant", "Open loop", "0 dB", "Target crossover"], "Location", "north", "NumColumns", 2, "FontSize", fontSize, "FontName", fontName);

axLoopPhase = subplot(3, 2, 4, "Parent", fig);
semilogx(axLoopPhase, frequencyHz, localPhaseDeg(plantResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
hold(axLoopPhase, "on");
semilogx(axLoopPhase, frequencyHz, localPhaseDeg(loopResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
yline(axLoopPhase, -180, "LineStyle", "--", "Color", colorOrder(5, :), "LineWidth", axLineWidth);
xline(axLoopPhase, designInfo.TargetCrossoverHz, "LineStyle", ":", "Color", colorOrder(4, :), "LineWidth", lineWidth);
ylabel(axLoopPhase, "Phase (deg)");
lgdLoopPhase = legend(axLoopPhase, ["Fitted plant", "Open loop", "-180 deg", "Target crossover"], "Location", "north", "NumColumns", 2, "FontSize", fontSize, "FontName", fontName);

axClosedLoop = subplot(3, 2, 5, "Parent", fig);
semilogx(axClosedLoop, frequencyHz, localMagDb(closedLoopResponse), "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
hold(axClosedLoop, "on");
semilogx(axClosedLoop, frequencyHz, localMagDb(sensitivityResponse), "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", lineWidth);
xlabel(axClosedLoop, "Frequency (Hz)");
ylabel(axClosedLoop, "Magnitude (dB)");
lgdClosedLoop = legend(axClosedLoop, ["Closed loop T", "Sensitivity S"], "Location", "northeast", "NumColumns", 1, "FontSize", fontSize, "FontName", fontName);

axStep = subplot(3, 2, 6, "Parent", fig);
plot(axStep, analysisInfo.StepTime, analysisInfo.StepResponse, "LineStyle", "-", "Color", colorOrder(1, :), "LineWidth", lineWidth);
hold(axStep, "on");
yline(axStep, 1, "LineStyle", "--", "Color", colorOrder(2, :), "LineWidth", axLineWidth);
xlabel(axStep, "Time (s)");
ylabel(axStep, "Output (normalized)");
lgdStep = legend(axStep, ["Closed-loop output", "Unit reference"], "Location", "northeast", "NumColumns", 1, "FontSize", fontSize, "FontName", fontName);

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

% plot-style legend rule: legend inside the axes (1-3 entries northeast, 4-6 north), headroom via ylim
finalizeYLimits(axPlantMag, lgdPlantMag, legendMaxHeightFrac, yTickInsetFrac);
finalizeYLimits(axPlantPhase, lgdPlantPhase, legendMaxHeightFrac, yTickInsetFrac);
finalizeYLimits(axLoopMag, lgdLoopMag, legendMaxHeightFrac, yTickInsetFrac);
finalizeYLimits(axLoopPhase, lgdLoopPhase, legendMaxHeightFrac, yTickInsetFrac);
finalizeYLimits(axClosedLoop, lgdClosedLoop, legendMaxHeightFrac, yTickInsetFrac);
finalizeYLimits(axStep, lgdStep, legendMaxHeightFrac, yTickInsetFrac);

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

% Copied verbatim from the plot-style skill (SKILL.md, "finalizeYLimits helper").
function finalizeYLimits(ax, lgd, legendMaxHeightFrac, yTickInsetFrac)
% ylim 마무리 (2-D 축 전용): ① 범례 아래를 지나는 데이터가 범례에 가리지 않게 상한을 올리고
%                           ② y 눈금이 박스 위아래 끝에 걸리지 않게 양쪽에 여유를 둔다
drawnow;                                              % 범례·축 위치 확정
axPix  = getpixelposition(ax);
lgdPix = getpixelposition(lgd);
boxAspect = ax.PlotBoxAspectRatio;                    % pbaspect 반영한 실제 플롯 박스 (axes Position 안에서 가운데 정렬)
boxW = min(axPix(3), axPix(4) * boxAspect(1) / boxAspect(2));
boxH = min(axPix(4), axPix(3) * boxAspect(2) / boxAspect(1));
boxLeft = axPix(1) + (axPix(3) - boxW) / 2;
boxTop  = axPix(2) + (axPix(4) + boxH) / 2;
legendGap  = boxTop - (lgdPix(2) + lgdPix(4));        % 박스 상단~범례 상단 간격 → 범례 아래에도 같은 간격 확보
legendFrac = (boxTop - lgdPix(2) + legendGap) / boxH; % h: 범례 띠 높이 / 플롯 박스 높이
isLogY = strcmp(ax.YScale, 'log');
xFwd = @(v) v;  yFwd = @(v) v;  yInv = @(v) v;        % log 축은 log10 공간에서 계산
if strcmp(ax.XScale, 'log'); xFwd = @log10; end
if isLogY; yFwd = @log10; yInv = @(v) 10.^v; end
xl = xFwd(xlim(ax));  yl = yFwd(ylim(ax));
if isLogY
    yl = [floor(yl(1) + 1e-9), ceil(yl(2) - 1e-9)];   % log 축: 한계를 decade에 맞춰 decade 눈금 유지
end
if legendFrac > legendMaxHeightFrac || lgdPix(3) > boxW
    lgd.Location = 'northoutside';                    % 축 안에 두기엔 너무 큼 → 축 밖, 상한은 그대로
    if lgd.NumColumns == 1
        lgd.NumColumns = numel(lgd.String);           % 축 밖에서는 한 줄로 펼쳐 축 높이를 덜 차지하게
    end
else
    xSpan = xl(1) + ([lgdPix(1), lgdPix(1) + lgdPix(3)] - boxLeft) / boxW * diff(xl);   % 범례 좌우 끝의 x 값
    yTop = -Inf;                                      % 범례 x 구간 아래를 지나는 데이터의 최댓값
    hData = findobj(ax.Children, '-property', 'YData');
    for k = 1:numel(hData)
        x = xFwd(double(hData(k).XData(:)));  y = yFwd(double(hData(k).YData(:)));
        under = x >= xSpan(1) & x <= xSpan(2);        % 구간 안의 점
        cross = min(x(1:end-1), x(2:end)) <= xSpan(2) & max(x(1:end-1), x(2:end)) >= xSpan(1);   % 구간을 가로지르는 선분
        under = under | [cross; false] | [false; cross];
        yTop = max([yTop; y(under)]);
    end
    yHi = yl(1) + (yTop - yl(1)) / (1 - legendFrac);  % ① yTop이 범례 띠 하단에 오도록 하는 상한
    if isLogY; yHi = ceil(yHi - 1e-9); end            % log 축은 decade 단위로 올림
    yl(2) = max(yl(2), yHi);
end
ylim(ax, yInv(yl));
yTickValues = yticks(ax);                             % ① 반영 후의 눈금
yTick = yFwd(yTickValues);
yTick = yTick(yTick >= yl(1) & yTick <= yl(2));       % 박스 안의 눈금만
yInset = yTickInsetFrac * diff(yl);
ylim(ax, yInv([min([yl(1), yTick - yInset]), max([yl(2), yTick + yInset])]));   % ② 양 끝 눈금을 박스 안쪽으로
if ~isequal(yticks(ax), yTickValues)
    yticks(ax, yTickValues);                          % 한계 변경으로 자동 눈금이 바뀌면(주로 log 축) 원래 눈금 유지
end
end
