% 이름   : figure_export_example
% 용도   : figure-export 스킬 — before/after 비교 예제 (IEEE single column, 흑백 생존성)
% 작성자 : REM2 / 2026
% 사용법 : MATLAB에서 직접 실행 (외부 데이터 불필요). image_fig/에 PDF·PNG 저장
% 의존성 : 없음 (기본 MATLAB, Control System Toolbox 불필요)

%% 합성 데이터 — 2차 폐루프 시스템 계단응답 (감쇠비 3종)
clear; clc;
wn    = 2*pi*5;                            % 고유진동수 (rad/s)
zetas = [0.2, 0.5, 0.8];                   % 감쇠비 — 곡선 3개
t     = linspace(0, 2, 400);               % 시간 (s)
y     = zeros(numel(zetas), numel(t));
for k = 1:numel(zetas)
    z     = zetas(k);
    wd    = wn*sqrt(1 - z^2);              % 감쇠 고유진동수 (rad/s)
    phi   = acos(z);
    y(k,:) = 1 - exp(-z*wn*t)./sqrt(1 - z^2) .* sin(wd*t + phi);   % 표준 계단응답 해
end

%% 출력 폴더
thisDir = fileparts(mfilename('fullpath'));
outDir  = fullfile(thisDir, 'image_fig');
if ~exist(outDir, 'dir'); mkdir(outDir); end

%% ── BEFORE — 흔한 문제: 화면 크기로 그려서 축소 의존, 색으로만 구분, 기본 폰트, 저해상도 PNG
figBefore = figure('Name', 'figure-export BEFORE');
plot(t, y(1,:), 'r', t, y(2,:), 'g', t, y(3,:), 'b');   % 색만으로 구분 — 흑백 인쇄 시 전멸
xlabel('time'); ylabel('output');                       % 단위 없음
legend('0.2', '0.5', '0.8');
title('Step Response');                                 % 논문 figure에 title 금지
exportgraphics(figBefore, fullfile(outDir, 'figure_export_before.png'), 'Resolution', 150);

%% ── AFTER — figure-export Common + IEEE single column 프리셋
% 논문용 figure 스타일 (IEEE single column)
figWidth    = 8.89;                % 칼럼 폭 (cm)
figHeight   = 6.0;                 % 높이 (cm)
fontSize    = 8;                   % 최종 인쇄 크기 기준 (pt)
fontName    = 'Times New Roman';
lineWidth   = 1.0;                 % 데이터 곡선 (pt)
axLineWidth = 0.5;                 % 축 박스·그리드 (pt)
gridStyle   = '--';
gridAlpha   = 0.25;
lineStyles  = {'-', '--', ':', '-.'};   % 흑백 구분 1순위
colorOrder  = [0 0 0; 0.85 0.1 0.1; 0 0.2 0.8];   % 명도 차이 확보 (회색조 보조 구분)

figAfter = figure('Name', 'figure-export AFTER', 'Color', 'w', ...
                  'Units', 'centimeters', 'Position', [2 2 figWidth figHeight]);
ax = axes('Parent', figAfter);
hold(ax, 'on');

hPlot = gobjects(1, numel(zetas));
for k = 1:numel(zetas)
    hPlot(k) = plot(ax, t, y(k,:), 'LineStyle', lineStyles{k}, ...
                    'Color', colorOrder(k,:), 'LineWidth', lineWidth);
end

xlabel(ax, 'Time (s)');
ylabel(ax, 'Output (-)');                  % 무차원 출력
xlim(ax, [0, 2]);
ylim(ax, [0, 1.6]);                        % 최대 오버슈트(약 1.53) 포함
set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', ...
        'LineWidth', axLineWidth, 'XGrid', 'on', 'YGrid', 'on', ...
        'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha, ...
        'GridLineWidth', axLineWidth, ...                          % R2023a+
        'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1);

legend(ax, hPlot, {'\zeta = 0.2', '\zeta = 0.5', '\zeta = 0.8'}, ...
       'Location', 'southeast', 'NumColumns', 1, ...
       'FontSize', fontSize, 'FontName', fontName);

% 축이 캔버스를 채우도록 — tight crop 후에도 내보낸 폭 = 칼럼 폭 유지
% TightInset이 라벨 위치에 따라 변하므로 2회 반복으로 수렴
set(ax, 'Units', 'normalized');
for fillIter = 1:2
    drawnow;
    ti = get(ax, 'TightInset');
    set(ax, 'Position', [ti(1), ti(2), 1 - ti(1) - ti(3), 1 - ti(2) - ti(4)]);
end
drawnow;

%% 내보내기 — 제출용 벡터 PDF + 검토용 600 dpi PNG + 회색조 변환본
% 'Padding', 0: exportgraphics 기본 여백 제거 (R2025a+). 구버전은 해당 인수 삭제
% — 약 0.1 cm(1%) 커지므로 LaTeX에서 width=\columnwidth로 흡수
ax.Toolbar.Visible = 'off';        % 마우스 호버 시 axes toolbar가 내보내기에 섞이는 것 방지
figName = 'figure_export_after';
exportgraphics(figAfter, fullfile(outDir, [figName '.pdf']), 'ContentType', 'vector', 'Padding', 0);
exportgraphics(figAfter, fullfile(outDir, [figName '_preview.png']), 'Resolution', 600, 'Padding', 0);

rgb = imread(fullfile(outDir, [figName '_preview.png']));
imwrite(rgb2gray(rgb), fullfile(outDir, [figName '_gray.png']));   % 흑백 인쇄 생존성 확인용

% 치수 자가 검증 — 600 dpi PNG 픽셀 수로 실제 내보낸 크기 확인
info = imfinfo(fullfile(outDir, [figName '_preview.png']));
fprintf('exported: %.2f x %.2f cm (target %.2f x %.2f cm)\n', ...
        info.Width/600*2.54, info.Height/600*2.54, figWidth, figHeight);
fprintf('saved: %s\n', fullfile(outDir, [figName '.pdf']));
