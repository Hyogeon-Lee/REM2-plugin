% 이름   : time_series_example
% 용도   : plot-style time-series 케이스 — before/after 비교 예제 (figure 1개, Before/After 탭)
% 작성자 : REM2 / 2026
% 사용법 : MATLAB에서 직접 실행 (외부 데이터 불필요). 축(패널)별 PNG를 image_fig/에 저장
% 의존성 : 없음 (기본 MATLAB R2020a+ — exportgraphics 탭 export)

%% 합성 데이터 — 2차 부족감쇠 스텝 응답 (변위 mm)
clear; clc;
zeta = 0.2;  wn = 20;                       % 감쇠비, 고유진동수 (rad/s)
wd   = wn*sqrt(1 - zeta^2);
t    = 0:1e-3:1.5;                          % 시간 (s) — 0부터 시작
phi  = atan2(sqrt(1 - zeta^2), zeta);
y    = 1 - (exp(-zeta*wn*t)./sqrt(1 - zeta^2)).*sin(wd*t + phi);
y    = 5*y;                                 % 변위 스케일 (mm)
setpoint = 5*ones(size(t));                 % 목표 변위 (mm)

%% 출력 폴더 (스크립트 위치 기준)
thisDir = fileparts(mfilename('fullpath'));
outDir  = fullfile(thisDir, 'image_fig');
if ~exist(outDir, 'dir'); mkdir(outDir); end

%% Figure 1개 + Before/After 탭 (Common: 스크립트당 figure 1개, 플롯마다 탭 1개)
fig = figure('Name', 'time-series before/after', 'Color', 'w', ...
             'Units', 'pixels', 'Position', [100 100 960 540]);   % 고정 Position → 재현 가능한 export 크기
tabGroup  = uitabgroup(fig);
tabBefore = uitab(tabGroup, 'Title', 'Before');
tabAfter  = uitab(tabGroup, 'Title', 'After');

%% ── BEFORE — 흔한 문제: 얇은 선, 단위 brackets, grid 없음, xlim 없음, shorthand 색, 불필요한 title
axes('Parent', tabBefore);                  % 현재 축 = Before 탭 → 아래 bare 호출이 여기에 그려짐
plot(t, y, 'b');                            % 얇은 기본 선 + shorthand 색
hold on;
plot(t, setpoint, 'r');
xlabel('Time [s]');                         % brackets (잘못)
ylabel('y');                                % 단위·의미 불명
title('Step Response');                     % 불필요한 title
legend('y', 'set');

%% ── AFTER — plot-style Common + time-series 케이스 적용
% 스타일 블록 (예제 자립성을 위해 인라인)
fontSize  = 24;  fontName = 'Times New Roman';  lineWidth = 3.0;
axLineWidth = 1.0;                              % 축 박스·그리드 선 두께
gridStyle = '--';  gridAlpha = 0.25;
colorOrder = [0 0 0; 1 0 0; 0 0 1];

ax = axes('Parent', tabAfter);              % 축 부모를 탭으로 명시 (bare axes는 탭 뒤에 숨음)

hMeas = plot(ax, t, y, 'LineStyle', '-', 'Color', colorOrder(1,:), 'LineWidth', lineWidth);
hold(ax, 'on');
hRef  = plot(ax, t, setpoint, 'LineStyle', '--', 'Color', colorOrder(2,:), 'LineWidth', lineWidth);

xlabel(ax, 'Time (s)');                     % 단위 괄호
ylabel(ax, 'Displacement (mm)');            % 물리 단위 명시
xlim(ax, [0, t(end)]);                      % 0부터 시작
ylim(ax, [0, 1.1*max(y)]);                  % 위쪽 ~10% 패딩
pbaspect(ax, [2 1 1]);                      % 시계열 wide
set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', 'LineWidth', axLineWidth, ...
        'XGrid', 'on', 'YGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha, ...
        'GridLineWidth', axLineWidth);          % GridLineWidth: R2023a+
legend(ax, [hMeas, hRef], {'Displacement', 'Setpoint'}, ...
       'Location', 'northoutside', 'NumColumns', 1, ...   % 2개 항목(1–3) → 1열
       'FontSize', fontSize, 'FontName', fontName);

%% 축(subplot 패널)별 PNG 저장 — 탭 figure에서 exportgraphics(fig)/print(fig)는 오류 → 축 단위 export
figName = 'time_series';
tabs = findobj(fig, 'Type', 'uitab');                       % 생성 순서 유지
for k = 1:numel(tabs)
    tabName = matlab.lang.makeValidName(tabs(k).Title);
    axList  = flipud(findobj(tabs(k), 'Type', 'axes'));     % Children는 최신 우선 → 생성 순서로
    for j = 1:numel(axList)
        pngName = sprintf('%s_%d_%s_%d.png', figName, k, tabName, j);   % 탭 번호·축 번호 항상 포함 → 파일명 고유
        exportgraphics(axList(j), fullfile(outDir, pngName), 'Resolution', 300);
    end
end

disp('time_series_example: before/after PNG 저장 완료 → image_fig/');
