% 이름   : time_series_example
% 용도   : plot-style time-series 케이스 — before/after 비교 예제
% 작성자 : REM2 / 2026
% 사용법 : MATLAB에서 직접 실행 (외부 데이터 불필요). image_fig/에 PNG 저장
% 의존성 : 없음 (기본 MATLAB)

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

%% ── BEFORE — 흔한 문제: 얇은 선, 단위 brackets, grid 없음, xlim 없음, shorthand 색, 불필요한 title
figBefore = figure('Name', 'time-series BEFORE');
plot(t, y, 'b');                            % 얇은 기본 선 + shorthand 색
hold on;
plot(t, setpoint, 'r');
xlabel('Time [s]');                         % brackets (잘못)
ylabel('y');                                % 단위·의미 불명
title('Step Response');                     % 불필요한 title
legend('y', 'set');
exportgraphics(figBefore, fullfile(outDir, 'time_series_before.png'), 'Resolution', 300);

%% ── AFTER — plot-style Common + time-series 케이스 적용
% 스타일 블록 (예제 자립성을 위해 인라인)
fontSize  = 24;  fontName = 'Times New Roman';  lineWidth = 3.0;
gridStyle = '--';  gridAlpha = 0.25;
colorOrder = [0 0 0; 1 0 0; 0 0 1];

% 재현 가능한 export 크기 (docking 대신 고정 Position)
figAfter = figure('Name', 'time-series AFTER', 'Color', 'w', ...
                  'Units', 'pixels', 'Position', [100 100 960 540]);
ax = axes('Parent', figAfter);

hMeas = plot(ax, t, y, 'LineStyle', '-', 'Color', colorOrder(1,:), 'LineWidth', lineWidth);
hold(ax, 'on');
hRef  = plot(ax, t, setpoint, 'LineStyle', '--', 'Color', colorOrder(2,:), 'LineWidth', lineWidth);

xlabel(ax, 'Time (s)');                     % 단위 괄호
ylabel(ax, 'Displacement (mm)');            % 물리 단위 명시
xlim(ax, [0, t(end)]);                      % 0부터 시작
ylim(ax, [0, 1.1*max(y)]);                  % 위쪽 ~10% 패딩
pbaspect(ax, [2 1 1]);                      % 시계열 wide
set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', ...
        'XGrid', 'on', 'YGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha);
legend(ax, [hMeas, hRef], {'Displacement', 'Setpoint'}, ...
       'Location', 'northoutside', 'NumColumns', 1, ...   % 2개 항목(1–3) → 1열
       'FontSize', fontSize, 'FontName', fontName);
exportgraphics(figAfter, fullfile(outDir, 'time_series_after.png'), 'Resolution', 300);

disp('time_series_example: before/after PNG 저장 완료 → image_fig/');
