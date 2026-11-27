%TEST_FILTERS Verify noise_gen.slx -> signal_filter.slx for every filter_mode.
%   1) Ts = 1e-4 (10 kHz): error analysis of each mode against the clean
%      (true) signal; every filter must at least halve the raw noise RMSE.
%      Metrics: RMSE, bias, max |error|, delay, delay-compensated RMSE.
%   2) Ts = 1e-3 (1 kHz): Ts override reaches FixedStep, sine stays 10 Hz,
%      Kalman filter still reduces the noise.
%   3) Run-time mode switching (MATLAB level): output stays finite and bounded.

% 작업 공간 정리: 이전 figure 창·변수·명령창 초기화 (재실행 시 창 누적 방지)
close all; clear all; clc; warning off;

% 플롯 스타일 기본 설정 (Common)
optionSave = true;                 % true일 때만 figure 저장 (PNG + FIG) — 저장 원치 않으면 false
fontSize   = 24;                   % 기본 폰트 크기 (revise에서 12~32 범위로 조절 가능)
fontName   = 'Times New Roman';
lineWidth  = 3.0;
axLineWidth = 1.0;                 % 축 박스·그리드 선 두께
gridStyle  = '--';                 % 점선 그리드
gridAlpha  = 0.25;                 % 그리드 투명도
maxDefaultSeries = 6;              % 기본 시리즈 최대 개수 (= 범례 항목 최대)
legendLocationCandidates = {'northeast', 'northwest', 'southeast', 'southwest', 'northoutside'};
colorOrder = [
    0,    0,    0;
    1,    0,    0;
    0,    0,    1;
    0.9,  0.3,  0.1;
    0,    0.5,  0;
    0.5,  0.2,  0.6;
    0,    1,    1;
    0,    1,    0
];

mdlGen = 'noise_gen';
mdlFlt = 'signal_filter';
load_system(mdlGen);
load_system(mdlFlt);
Ts1   = 1e-4;                      % 기본 샘플링 주기 (10 kHz)
tEnd  = 0.5;                       % 시뮬레이션 길이 (s)
tSkip = 0.05;                      % 초기 수렴 구간 제외 후 오차 계산 (s)
modeNames  = {'Bypass', 'LPF 1st', 'Butterworth 2nd', 'Moving Avg', 'Kalman', 'Particle'};
shortNames = {'Bypass', 'LPF1', 'Butter2', 'MovAvg', 'Kalman', 'PF'};
nModes = numel(modeNames);

%% 1) 10 kHz: 모드별 시뮬레이션
[t, yClean, yNoisy] = runNoiseGen(mdlGen, Ts1, tEnd);
yFilt = zeros(numel(t), nModes);
for k = 0:nModes - 1
    yFilt(:, k + 1) = runFilter(mdlFlt, Ts1, k, t, yNoisy);
end

%% 오차 분석: 참값(y_clean) 대비 e = y_filt - y_clean
%   RMSE^2 ~ (지연에 의한 오차)^2 + (잔여 노이즈)^2 이므로, 지연 L을 보상한
%   RMSE_aligned = min_L rms(y_filt(k) - y_clean(k - L)) 로 두 성분을 분리한다.
idx    = find(t >= tSkip);
maxLag = round(0.01/Ts1);          % 지연 탐색 0~10 ms (10 Hz 신호 반주기 50 ms보다 작게)
rmse   = zeros(1, nModes);
bias   = rmse;  maxErr = rmse;  delayMs = rmse;  rmseAligned = rmse;
for k = 1:nModes
    e = yFilt(idx, k) - yClean(idx);
    rmse(k)   = sqrt(mean(e.^2));
    bias(k)   = mean(e);
    maxErr(k) = max(abs(e));
    rmseLag = arrayfun(@(L) sqrt(mean((yFilt(idx, k) - yClean(idx - L)).^2)), 0:maxLag);
    [rmseAligned(k), iBest] = min(rmseLag);
    delayMs(k) = (iBest - 1)*Ts1*1e3;
end
fprintf('Ts = %g s (10 kHz), error vs clean signal (t >= %.2f s)\n', Ts1, tSkip);
fprintf('  %-4s %-16s %8s %9s %8s %10s %13s\n', 'mode', 'name', 'RMSE', 'bias', 'max|e|', 'delay(ms)', 'RMSE aligned');
for k = 1:nModes
    fprintf('  %-4d %-16s %8.4f %9.5f %8.4f %10.2f %13.4f\n', k - 1, modeNames{k}, rmse(k), bias(k), maxErr(k), delayMs(k), rmseAligned(k));
end
assert(max(abs(yFilt(:, 1) - yNoisy)) == 0, 'Bypass must return the input unchanged');
assert(all(rmse(2:end) < 0.5*rmse(1)), 'A filter mode did not halve the noise RMSE');

%% 2) 1 kHz: Ts 변경이 FixedStep·신호 주파수·필터에 반영되는지 확인
Ts2 = 1e-3;
[t2, yClean2, yNoisy2] = runNoiseGen(mdlGen, Ts2, tEnd);
assert(abs(mean(diff(t2)) - Ts2) < 1e-12, 'Ts override did not reach FixedStep');
specMag = abs(fft(yClean2 - mean(yClean2)));
freqHz  = (0:numel(specMag) - 1)'/(numel(specMag)*Ts2);
[~, iPeak] = max(specMag(1:floor(end/2)));
assert(abs(freqHz(iPeak) - 10) <= 1/tEnd, 'Sine frequency changed with Ts');
yKalman2 = runFilter(mdlFlt, Ts2, 4, t2, yNoisy2);
isEval2  = t2 >= tSkip;
rmseRaw2 = sqrt(mean((yNoisy2(isEval2) - yClean2(isEval2)).^2));
rmseKf2  = sqrt(mean((yKalman2(isEval2) - yClean2(isEval2)).^2));
fprintf('Ts = 1e-3 s (1 kHz): sine peak %.2f Hz, RMSE raw %.4f -> Kalman %.4f\n', freqHz(iPeak), rmseRaw2, rmseKf2);
assert(rmseKf2 < rmseRaw2, 'Kalman filter at 1 kHz did not reduce the noise');

%% 3) 런타임 모드 전환 (MATLAB 레벨): 0.05 s마다 모드 변경
clear signal_filter_core
modeSeq = mod(floor(t/0.05), nModes);
ySwitch = zeros(size(t));
for i = 1:numel(t)
    ySwitch(i) = signal_filter_core(yNoisy(i), modeSeq(i), Ts1, 200, 20, 1e5, 0.04, 200);
end
assert(all(isfinite(ySwitch)) && max(abs(ySwitch - yClean)) < 1, 'Mode switching produced a jump');
fprintf('Mode switching every 0.05 s: max |error| = %.3f\n', max(abs(ySwitch - yClean)));
disp('All checks passed.');

%% 플롯
% Figure 생성: 스크립트당 1개 + 탭 그룹(플롯마다 탭 1개), 모니터 크기 초과 금지, 툴바 항상 유지
screenSize = get(0, 'ScreenSize');                 % [left bottom width height] (px)
figWidth   = min(960, screenSize(3) - 100);        % 목표 폭, 화면 폭 초과 금지
figHeight  = min(540, screenSize(4) - 150);        % 목표 높이, 작업표시줄·창 테두리 여유 확보
fig = figure('Color', 'w', 'Units', 'pixels', ...
             'Position', [100 100 figWidth figHeight], ...
             'ToolBar', 'figure', 'MenuBar', 'figure');
tabGroup = uitabgroup(fig);
tView  = [0, 0.1];                                 % 시작 수렴 + 1주기 (10 Hz)가 보이는 구간
inView = t >= tView(1) & t <= tView(2);
padRange = @(r) r + [-1, 1]*0.05*diff(r);          % 데이터 범위 + 5% 여유

% 탭 1: clean vs noisy 입력
tabNoisy = uitab(tabGroup, 'Title', 'Noisy Signal');
axNoisy  = axes('Parent', tabNoisy);
hold(axNoisy, 'on');
hNoisy(1) = stairs(axNoisy, t, yNoisy, 'LineStyle', '-', 'Color', colorOrder(2, :), 'LineWidth', lineWidth);
hNoisy(2) = stairs(axNoisy, t, yClean, 'LineStyle', '--', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
yRange = [min(yNoisy(inView)), max(yNoisy(inView))];

% 탭 2: clean 기준선 + 필터 5종 (최대 6 시리즈)
tabFilt = uitab(tabGroup, 'Title', 'Filtered');
axFilt  = axes('Parent', tabFilt);
hold(axFilt, 'on');
hFilt = gobjects(1, nModes);
hFilt(1) = stairs(axFilt, t, yClean, 'LineStyle', '--', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
for k = 2:nModes
    hFilt(k) = stairs(axFilt, t, yFilt(:, k), 'LineStyle', '-', 'Color', colorOrder(k, :), 'LineWidth', lineWidth);
end

% 탭 3: 참값 대비 오차 e(t) = y_filt - y_clean (필터 5종)
tabErr = uitab(tabGroup, 'Title', 'Error');
axErr  = axes('Parent', tabErr);
hold(axErr, 'on');
hErr = gobjects(1, nModes - 1);
for k = 2:nModes
    hErr(k - 1) = stairs(axErr, t, yFilt(:, k) - yClean, 'LineStyle', '-', 'Color', colorOrder(k, :), 'LineWidth', lineWidth);
end
errView  = yFilt(inView, 2:end) - yClean(inView);
errRange = [min(errView(:)), max(errView(:))];

% 탭 4: RMSE — 전체 vs 지연 보상 (차이 = 위상 지연이 만든 오차)
% (subplot 2단은 540 px 높이에서 축이 찌그러져 탭을 분리)
tabRmse = uitab(tabGroup, 'Title', 'RMSE');
axRmse  = axes('Parent', tabRmse);
hRmse   = bar(axRmse, 1:nModes, [rmse; rmseAligned]', 'grouped', 'EdgeColor', colorOrder(1, :), 'LineWidth', axLineWidth);
set(hRmse(1), 'FaceColor', colorOrder(1, :));
set(hRmse(2), 'FaceColor', colorOrder(2, :));

% 탭 5: 참값 대비 지연
tabDelay = uitab(tabGroup, 'Title', 'Delay');
axDelay  = axes('Parent', tabDelay);
hDelay   = bar(axDelay, 1:nModes, delayMs, 'FaceColor', colorOrder(3, :), 'EdgeColor', colorOrder(1, :), 'LineWidth', axLineWidth);

% 축별 설정: 라벨·범위·범례
axList   = [axNoisy, axFilt, axErr, axRmse, axDelay];
hList    = {hNoisy, hFilt, hErr, hRmse, hDelay};
lblList  = {{'Noisy', 'Clean'}, ['Clean', modeNames(2:end)], modeNames(2:end), {'Total', 'Delay-compensated'}, {'Delay'}};
xlblList = {'Time (s)', 'Time (s)', 'Time (s)', 'Filter', 'Filter'};
ylblList = {'Amplitude (-)', 'Amplitude (-)', 'Error (-)', 'RMSE (-)', 'Delay (ms)'};
xlimList = {tView, tView, tView, [0.4, nModes + 0.6], [0.4, nModes + 0.6]};
ylimList = {padRange(yRange), padRange(yRange), padRange(errRange), [0, 1.1*max(rmse)], [0, 1.1*max(delayMs)]};
isBar    = [false, false, false, true, true];
for a = 1:numel(axList)
    ax = axList(a);
    set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', 'LineWidth', axLineWidth, 'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha, 'GridLineWidth', axLineWidth);
    xlabel(ax, xlblList{a});
    ylabel(ax, ylblList{a});
    xlim(ax, xlimList{a});
    ylim(ax, ylimList{a});
    if isBar(a)
        xticks(ax, 1:nModes);                      % 필터별 막대 위치
        xticklabels(ax, shortNames);
    else
        xticks(ax, 0:0.025:0.1);                   % grid line 5개 (기본 0.02 간격은 6개)
    end
    pbaspect(ax, [2 1 1]);
    % 범례: 표시 개수 제한 + 개수에 따른 열 수
    numLegendEntries = min(numel(lblList{a}), maxDefaultSeries);
    if numLegendEntries <= 3
        numLegendColumns = 1;
    else
        numLegendColumns = 2;
    end
    legend(ax, hList{a}(1:numLegendEntries), lblList{a}(1:numLegendEntries), ...
           'Location', 'northoutside', 'NumColumns', numLegendColumns, ...
           'FontSize', fontSize, 'FontName', fontName);
end

% 결과 저장 (optionSave가 true일 때만): 축마다 검토용 PNG + figure 전체 편집용 FIG
if optionSave
    if ~exist('image_fig', 'dir'); mkdir('image_fig'); end
    figName = 'filter_comparison';
    tabs = findobj(fig, 'Type', 'uitab');          % 생성 순서 유지
    for k = 1:numel(tabs)
        tabName = matlab.lang.makeValidName(tabs(k).Title);   % 탭 제목 → 파일명 안전 문자열
        axTab   = flipud(findobj(tabs(k), 'Type', 'axes'));   % 생성 순서로
        for j = 1:numel(axTab)
            pngName = sprintf('%s_%d_%s_%d.png', figName, k, tabName, j);
            exportgraphics(axTab(j), fullfile('image_fig', pngName), 'Resolution', 300);
        end
    end
    savefig(fig, fullfile('image_fig', [figName '.fig']));   % FIG 하나에 모든 탭·축 보존
end

%% 로컬 함수
function [t, yClean, yNoisy] = runNoiseGen(mdl, Ts, tEnd)
% noise_gen.slx 시뮬레이션 (Ts는 model workspace 파라미터를 덮어씀)
in  = Simulink.SimulationInput(mdl);
in  = in.setVariable('Ts', Ts, 'Workspace', mdl);
in  = in.setModelParameter('StopTime', num2str(tEnd));
out = sim(in);
clean  = out.yout.get('y_clean').Values;
noisy  = out.yout.get('y_noisy').Values;
t      = clean.Time;
yClean = clean.Data(:);
yNoisy = noisy.Data(:);
end

function y = runFilter(mdl, Ts, mode, t, u)
% signal_filter.slx 시뮬레이션: 입력 u(t)를 Inport로 주입, filter_mode 지정
in  = Simulink.SimulationInput(mdl);
in  = in.setVariable('Ts', Ts, 'Workspace', mdl);
in  = in.setVariable('filter_mode', mode, 'Workspace', mdl);
in  = in.setExternalInput([t, u]);
in  = in.setModelParameter('StopTime', num2str(t(end)));
out = sim(in);
y   = out.yout.get('y_filt').Values.Data(:);
end
