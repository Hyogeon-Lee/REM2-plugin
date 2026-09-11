% 이름   : xy_plot_example
% 용도   : plot-style xy-plot 케이스 — before/after 비교 예제 (동일 단위 궤적, axis equal; figure 1개, Before/After 탭)
% 작성자 : REM2 / 2026
% 사용법 : MATLAB에서 직접 실행 (외부 데이터 불필요). 축(패널)별 PNG를 image_fig/에 저장
% 의존성 : 없음 (기본 MATLAB R2020a+ — exportgraphics 탭 export)

%% 합성 데이터 — Lissajous 궤적 (x, y 모두 변위 mm, 동일 스케일)
clear; clc;
tt = linspace(0, 2*pi, 800);
A  = 10;  B = 10;                           % 진폭 (mm)
xPos = A*sin(3*tt + pi/4);                  % X 변위 (mm)
yPos = B*sin(2*tt);                         % Y 변위 (mm)

%% 출력 폴더
thisDir = fileparts(mfilename('fullpath'));
outDir  = fullfile(thisDir, 'image_fig');
if ~exist(outDir, 'dir'); mkdir(outDir); end

%% Figure 1개 + Before/After 탭 (Common: 스크립트당 figure 1개, 플롯마다 탭 1개)
fig = figure('Name', 'xy-plot before/after', 'Color', 'w', ...
             'Units', 'pixels', 'Position', [100 100 720 720]);   % 정방형 → axis equal 궤적
tabGroup  = uitabgroup(fig);
tabBefore = uitab(tabGroup, 'Title', 'Before');
tabAfter  = uitab(tabGroup, 'Title', 'After');

%% ── BEFORE — 흔한 문제: 종횡비 왜곡(axis equal 없음), 라벨/단위 없음, 얇은 선, shorthand, grid 없음
axes('Parent', tabBefore);                  % 현재 축 = Before 탭 → 아래 bare 호출이 여기에 그려짐
plot(xPos, yPos, 'g');                      % 얇은 기본 선 + shorthand 색, 비등방 → 형상 왜곡
xlabel('x');                                % 단위 없음
ylabel('y');
title('XY');

%% ── AFTER — plot-style Common + xy-plot 케이스 적용 (동일 단위 → axis equal)
fontSize  = 24;  fontName = 'Times New Roman';  lineWidth = 3.0;
axLineWidth = 1.0;                              % 축 박스·그리드 선 두께
gridStyle = '--';  gridAlpha = 0.25;
colorOrder = [0 0 0; 1 0 0; 0 0 1];

ax = axes('Parent', tabAfter);              % 축 부모를 탭으로 명시

hPath = plot(ax, xPos, yPos, 'LineStyle', '-', 'Color', colorOrder(1,:), 'LineWidth', lineWidth);
hold(ax, 'on');
% 시작/끝 마커로 진행 방향 표시
hStart = plot(ax, xPos(1),   yPos(1),   'LineStyle', 'none', 'Marker', 'o', ...
              'MarkerSize', 12, 'MarkerFaceColor', colorOrder(2,:), 'MarkerEdgeColor', colorOrder(2,:));
hEnd   = plot(ax, xPos(end), yPos(end), 'LineStyle', 'none', 'Marker', 's', ...
              'MarkerSize', 12, 'MarkerFaceColor', colorOrder(3,:), 'MarkerEdgeColor', colorOrder(3,:));

xlabel(ax, 'X Position (mm)');              % 단위 괄호
ylabel(ax, 'Y Position (mm)');
axis(ax, 'equal');                          % 동일 물리 단위 → 등방 스케일 (형상 보존)
xlim(ax, [-1.1*A, 1.1*A]);
ylim(ax, [-1.1*B, 1.1*B]);
set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', 'LineWidth', axLineWidth, ...
        'XGrid', 'on', 'YGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha, ...
        'GridLineWidth', axLineWidth);          % GridLineWidth: R2023a+
legend(ax, [hPath, hStart, hEnd], {'Trajectory', 'Start', 'End'}, ...
       'Location', 'northoutside', 'NumColumns', 1, ...   % 3개 항목(1–3) → 1열
       'FontSize', fontSize, 'FontName', fontName);

%% 축(subplot 패널)별 PNG 저장 — 탭 figure에서 exportgraphics(fig)/print(fig)는 오류 → 축 단위 export
figName = 'xy_plot';
tabs = findobj(fig, 'Type', 'uitab');                       % 생성 순서 유지
for k = 1:numel(tabs)
    tabName = matlab.lang.makeValidName(tabs(k).Title);
    axList  = flipud(findobj(tabs(k), 'Type', 'axes'));     % Children는 최신 우선 → 생성 순서로
    for j = 1:numel(axList)
        pngName = sprintf('%s_%d_%s_%d.png', figName, k, tabName, j);   % 탭 번호·축 번호 항상 포함 → 파일명 고유
        exportgraphics(axList(j), fullfile(outDir, pngName), 'Resolution', 300);
    end
end

disp('xy_plot_example: before/after PNG 저장 완료 → image_fig/');
