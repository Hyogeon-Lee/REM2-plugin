% 이름   : figure_export_multipanel_example
% 용도   : figure-export 스킬 — 어려운 케이스 예제: 6곡선(마커 분기) + 2패널 tiledlayout
%          + 외부 범례 + (a)/(b) 패널 라벨 (IEEE double column)
% 작성자 : REM2 / 2026
% 사용법 : MATLAB에서 직접 실행 (외부 데이터 불필요). image_fig/에 PDF·PNG 저장
% 의존성 : 없음 (기본 MATLAB R2020b+ — tiledlayout은 R2019b+지만 버전 게이트에 쓰는
%          isMATLABReleaseOlderThan이 R2020b+. exportgraphics 'Padding'은 R2025a+
%          전용, 구버전에서는 버전 게이트로 자동 생략)

%% 합성 데이터 — 2차 시스템 계단응답 (감쇠비 6종) + 정착시간 비교
clear; clc;
wn    = 2*pi*5;                            % 고유진동수 (rad/s)
zetas = [0.1, 0.2, 0.3, 0.5, 0.7, 0.9];    % 감쇠비 — 곡선 6개 (마커 분기 시연)
t     = linspace(0, 2, 400);               % 시간 (s)
y     = zeros(numel(zetas), numel(t));
for k = 1:numel(zetas)
    z      = zetas(k);
    wd     = wn*sqrt(1 - z^2);             % 감쇠 고유진동수 (rad/s)
    phi    = acos(z);
    y(k,:) = 1 - exp(-z*wn*t)./sqrt(1 - z^2) .* sin(wd*t + phi);
end
ts = 4 ./ (zetas * wn);                    % 2% 정착시간 근사 (s)

%% 출력 폴더
thisDir = fileparts(mfilename('fullpath'));
outDir  = fullfile(thisDir, 'image_fig');
if ~exist(outDir, 'dir'); mkdir(outDir); end

%% 스타일 블록 — IEEE double column (다중 패널이라 가로 폭 필요)
figWidth    = 18.16;               % IEEE double column (cm)
figHeight   = 6.5;                 % 높이 (cm)
fontSize    = 8;                   % 최종 인쇄 크기 기준 (pt)
fontName    = 'Times New Roman';
lineWidth   = 1.0;                 % 데이터 곡선 (pt)
axLineWidth = 0.5;                 % 축 박스·그리드 (pt)
gridStyle   = '--';
gridAlpha   = 0.25;
lineStyles  = {'-', '--', ':', '-.'};   % 흑백 구분 1순위
markerSet   = {'o', 's', '^', 'd', 'v', '>'};   % 흑백 구분 2순위 (5번째 곡선부터)
numMarkers  = 10;                  % 곡선당 마커 개수 (MarkerIndices로 솎기)
colorOrder  = [                    % 명도 간격 확보 — 회색조 변환 시 보조 구분
    0,    0,    0;
    0.85, 0.10, 0.10;
    0,    0.20, 0.80;
    0.93, 0.60, 0;
    0.45, 0.45, 0.45;
    0,    0.60, 0.30
];

fig = figure('Name', 'figure-export multipanel', 'Color', 'w', ...
             'Units', 'centimeters', 'Position', [2 2 figWidth figHeight]);

% 외부 범례 + 다중 패널 → TightInset fill loop 무효 케이스 → tiledlayout 경로
tl = tiledlayout(fig, 1, 2, 'Padding', 'tight', 'TileSpacing', 'compact');

%% ── 패널 (a): 계단응답 6곡선 — 5번째부터 마커 분기
axA = nexttile(tl);
hold(axA, 'on');
hPlot = gobjects(1, numel(zetas));
labels = cell(1, numel(zetas));
for k = 1:numel(zetas)
    ci = mod(k-1, size(colorOrder, 1)) + 1;           % 색 순환 — index 에러 방지
    if k <= 4
        hPlot(k) = plot(axA, t, y(k,:), 'LineStyle', lineStyles{k}, ...
                        'Color', colorOrder(ci,:), 'LineWidth', lineWidth);
    else
        idx = unique(round(linspace(1, numel(t), min(numMarkers, numel(t)))));     % 마커 솎기 — 짧은 신호에서도 유효
        idx = unique(min(idx + round((k-5)*numel(t)/(2*numMarkers)), numel(t)));   % 곡선별 오프셋 — 인접 곡선 마커 겹침 방지
        hPlot(k) = plot(axA, t, y(k,:), 'LineStyle', lineStyles{mod(k-1, 4) + 1}, ...
                        'Color', colorOrder(ci,:), 'LineWidth', lineWidth, ...
                        'Marker', markerSet{mod(k-5, numel(markerSet)) + 1}, ...
                        'MarkerIndices', idx, 'MarkerSize', 3);
    end
    labels{k} = sprintf('\\zeta = %.1f', zetas(k));
end
xlabel(axA, 'Time (s)');
ylabel(axA, 'Output (-)');
xlim(axA, [0, 2]);
ylim(axA, [0, 1.8]);

%% ── 패널 (b): 감쇠비별 2% 정착시간
axB = nexttile(tl);
plot(axB, zetas, ts, 'LineStyle', '-', 'Color', colorOrder(1,:), ...
     'LineWidth', lineWidth, 'Marker', 'o', 'MarkerSize', 3);
xlabel(axB, 'Damping ratio (-)');
ylabel(axB, 'Settling time (s)');
xlim(axB, [0, 1]);
ylim(axB, [0, 1.4]);

%% 공통 축 스타일 + 외부 범례 + (a)/(b) 라벨
for ax = [axA, axB]
    set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', ...
            'LineWidth', axLineWidth, 'XGrid', 'on', 'YGrid', 'on', ...
            'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha, ...
            'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1);
    if ~isMATLABReleaseOlderThan("R2023a")
        set(ax, 'GridLineWidth', axLineWidth);     % R2023a+ 전용 속성 — 구버전은 기본값 유지
    end
end

lgd = legend(axA, hPlot, labels, 'NumColumns', 3, ...
             'FontSize', fontSize, 'FontName', fontName);
lgd.Layout.Tile = 'north';                 % tiledlayout 외부 범례 — 패널 위 전체 폭

% 패널 라벨 (a)/(b) — 본문 fontSize와 동일, 각 패널 좌하단 안쪽 (데이터 없는 곳)
% 좌상단(0.95)은 zeta=0.1 오버슈트 곡선과 겹치므로 금지
text(axA, 0.03, 0.08, '(a)', 'Units', 'normalized', ...
     'FontSize', fontSize, 'FontName', fontName);
text(axB, 0.03, 0.08, '(b)', 'Units', 'normalized', ...
     'FontSize', fontSize, 'FontName', fontName);

%% 내보내기 — 제출용 벡터 PDF + 검토용 600 dpi PNG + 회색조 변환본
axA.Toolbar.Visible = 'off';
axB.Toolbar.Visible = 'off';
figName = 'figure_export_multipanel';
padArgs = {};                      % 버전 게이트 — R2025a 미만에는 'Padding' 인수가 없음
if ~isMATLABReleaseOlderThan("R2025a")
    padArgs = {'Padding', 0};
end
exportgraphics(fig, fullfile(outDir, [figName '.pdf']), 'ContentType', 'vector', padArgs{:});
exportgraphics(fig, fullfile(outDir, [figName '_preview.png']), 'Resolution', 600, padArgs{:});

rgb = imread(fullfile(outDir, [figName '_preview.png']));
if exist('im2gray', 'file')        % Image Processing Toolbox 불필요 — im2gray 있으면 사용
    grayImg = im2gray(rgb);
else                               % 없으면 수동 luma 변환 (ITU-R BT.601)
    grayImg = uint8(0.2989*double(rgb(:,:,1)) + 0.5870*double(rgb(:,:,2)) + 0.1140*double(rgb(:,:,3)));
end
imwrite(grayImg, fullfile(outDir, [figName '_gray.png']));   % 흑백 인쇄 생존성 확인용

% 치수 자가 검증 — 600 dpi PNG 픽셀 수로 실제 내보낸 크기 확인
info = imfinfo(fullfile(outDir, [figName '_preview.png']));
fprintf('exported: %.2f x %.2f cm (target %.2f x %.2f cm)\n', ...
        info.Width/600*2.54, info.Height/600*2.54, figWidth, figHeight);
fprintf('saved: %s\n', fullfile(outDir, [figName '.pdf']));
