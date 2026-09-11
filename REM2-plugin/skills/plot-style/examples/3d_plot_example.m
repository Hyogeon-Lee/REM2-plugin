% 이름   : 3d_plot_example
% 용도   : plot-style 3d-plot 케이스 — before/after 비교 예제 (합성 표면; figure 1개, Before/After 탭)
% 작성자 : REM2 / 2026
% 사용법 : 파일명이 숫자로 시작해 이름 호출/run() 불가 — 에디터에서 열어
%          섹션 실행(Ctrl+Enter)으로 위에서부터 순서대로 실행 (외부 데이터 불필요).
%          축(패널)별 PNG를 image_fig/에 저장
% 의존성 : 없음 (기본 MATLAB R2020a+ — exportgraphics 탭 export)

%% 합성 데이터 — 2D 가우시안 합 표면 (예: 자기장 세기 분포)
clear; clc;
gx = linspace(-3, 3, 80);
gy = linspace(-3, 3, 80);
[X, Y] = meshgrid(gx, gy);                  % 공간 좌표 (mm)
Z = 3*exp(-((X-1).^2 + (Y-1).^2)) ...       % 봉우리 1
  + 2*exp(-((X+1.2).^2 + (Y+0.8).^2)/0.7);  % 봉우리 2  → 세기 (mT)

%% 출력 폴더
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end         % 섹션 실행 시 mfilename이 빈 값 → 현재 폴더 사용
outDir  = fullfile(thisDir, 'image_fig');
if ~exist(outDir, 'dir'); mkdir(outDir); end

%% Figure 1개 + Before/After 탭 (Common: 스크립트당 figure 1개, 플롯마다 탭 1개)
fig = figure('Name', '3d-plot before/after', 'Color', 'w', ...
             'Units', 'pixels', 'Position', [80 80 1150 980]);    % 2x2 패널 높이 확보
tabGroup  = uitabgroup(fig);
tabBefore = uitab(tabGroup, 'Title', 'Before');
tabAfter  = uitab(tabGroup, 'Title', 'After');

%% ── BEFORE — 흔한 문제: 인덱스축 surf(Z), 라벨 없음, colorbar 없음, 격자선 난잡, 기본 view
axes('Parent', tabBefore);                  % 현재 축 = Before 탭 → 아래 bare 호출이 여기에 그려짐
surf(Z);                                    % X,Y 없이 인덱스 축, 촘촘한 검은 격자
title('Surface');

%% ── AFTER — plot-style 3d-plot 케이스: 2x2 (상단 surf mesh, 하단 point cloud), 각 iso/top 2시점
fontSize  = 16;            % 2x2 밀집 레이아웃 → 가독성 위해 폰트 축소 (단일 패널 기본은 24)
fontName  = 'Times New Roman';
axLineWidth = 1.0;                              % 축 박스·그리드 선 두께
gridStyle = '--';  gridAlpha = 0.25;

% 연속 필드 함수 (그리드 surf + 포인트 클라우드 공용)
fieldFn = @(x, y) 3*exp(-((x-1).^2 + (y-1).^2)) ...
                + 2*exp(-((x+1.2).^2 + (y+0.8).^2)/0.7);

% surf용 그리드 (mesh 형태가 보이도록 적당한 해상도)
sgx = linspace(-3, 3, 45);  sgy = linspace(-3, 3, 45);
[Xs, Ys] = meshgrid(sgx, sgy);
Zs = fieldFn(Xs, Ys);

% 포인트 클라우드 (측정점 모사: 무작위 위치 + 약간의 노이즈)
M  = 1500;
px = -3 + 6*rand(M, 1);  py = -3 + 6*rand(M, 1);
pz = fieldFn(px, py) + 0.12*randn(M, 1);

zMax = 1.1*max(Zs(:));

% 동일 필드의 시점/표현 비교 = 결합 패널 → 같은 탭 안에 2x2 subplot
ax1 = subplot(2, 2, 1, 'Parent', tabAfter);   % surf — iso
ax2 = subplot(2, 2, 2, 'Parent', tabAfter);   % surf — top
ax3 = subplot(2, 2, 3, 'Parent', tabAfter);   % point cloud — iso
ax4 = subplot(2, 2, 4, 'Parent', tabAfter);   % point cloud — top

% 상단: surf (mesh 형태 — 엣지 표시)
surf(ax1, Xs, Ys, Zs, 'EdgeColor', [0.2 0.2 0.2], 'FaceAlpha', 0.9);
surf(ax2, Xs, Ys, Zs, 'EdgeColor', [0.2 0.2 0.2], 'FaceAlpha', 0.9);

% 하단: point cloud (값으로 색)
scatter3(ax3, px, py, pz, 14, pz, 'filled');
scatter3(ax4, px, py, pz, 14, pz, 'filled');

colormap(fig, 'parula');

allAx = [ax1, ax2, ax3, ax4];
for k = 1:numel(allAx)
    ax = allAx(k);
    set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', 'LineWidth', axLineWidth, ...
            'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', ...
            'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha, ...
            'GridLineWidth', axLineWidth);      % GridLineWidth: R2023a+
    xlabel(ax, 'X Position (mm)');           % 3축 모두 라벨 + 단위
    ylabel(ax, 'Y Position (mm)');
    zlabel(ax, 'Flux Density (mT)');         % z축이 값(세기)을 나타냄 → colorbar 불필요
    xlim(ax, [-3, 3]);  ylim(ax, [-3, 3]);  zlim(ax, [0, zMax]);
    clim(ax, [0, max(Zs(:))]);               % 패널 간 색 범위만 통일 (colorbar 없음)
    pbaspect(ax, [1 1 0.7]);                 % 단위 다름(mm vs mT) → 데이터 종횡비 대신 가독성 박스
end
view(ax1, 30, 15);  view(ax3, 30, 15);       % iso 시점
view(ax2, 0, 90);   view(ax4, 0, 90);        % top-down 시점

%% 축(subplot 패널)별 PNG 저장 — 탭 figure에서 exportgraphics(fig)/print(fig)는 오류 → 축 단위 export
figName = '3d_plot';
tabs = findobj(fig, 'Type', 'uitab');                       % 생성 순서 유지
for k = 1:numel(tabs)
    tabName = matlab.lang.makeValidName(tabs(k).Title);
    axList  = flipud(findobj(tabs(k), 'Type', 'axes'));     % Children는 최신 우선 → 생성 순서로
    for j = 1:numel(axList)
        pngName = sprintf('%s_%d_%s_%d.png', figName, k, tabName, j);   % 탭 번호·축 번호 항상 포함 → 파일명 고유
        exportgraphics(axList(j), fullfile(outDir, pngName), 'Resolution', 300);
    end
end

disp('3d_plot_example: before/after PNG 저장 완료 → image_fig/');
