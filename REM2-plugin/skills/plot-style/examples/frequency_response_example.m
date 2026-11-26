% 이름   : frequency_response_example
% 용도   : plot-style frequency-response 케이스 — before/after 비교 예제 (FRF, 물리 단위 mag; figure 1개, Before/After 탭)
% 작성자 : REM2 / 2026
% 사용법 : MATLAB에서 직접 실행 (외부 데이터 불필요). 축(패널)별 PNG를 image_fig/에 저장
% 의존성 : 없음 (기본 MATLAB R2020a+, Control System Toolbox 불필요)

%% 합성 데이터 — 2차 시스템 주파수응답 (변위/전류, mm/A)
close all; clear all; clc; warning off;
fn   = 80;                                  % 고유진동수 (Hz)
wn   = 2*pi*fn;                             % (rad/s)
zeta = 0.05;                                % 저감쇠 → 공진 피크
Kdc  = 2.0;                                 % DC 게인 (mm/A)
f    = logspace(0, 3, 1000);               % 주파수 (Hz), 1 ~ 1000
w    = 2*pi*f;
H    = Kdc * wn^2 ./ (wn^2 - w.^2 + 1i*2*zeta*wn.*w);   % FRF (mm/A)
mag  = abs(H);                              % 크기 (mm/A) — 물리 단위
phase = unwrap(angle(H)) * 180/pi;         % 위상 (deg), unwrap 후 변환

%% 출력 폴더
thisDir = fileparts(mfilename('fullpath'));
outDir  = fullfile(thisDir, 'image_fig');
if ~exist(outDir, 'dir'); mkdir(outDir); end

%% Figure 1개 + Before/After 탭 (Common: 스크립트당 figure 1개, 플롯마다 탭 1개)
fig = figure('Name', 'frequency-response before/after', 'Color', 'w', ...
             'Units', 'pixels', 'Position', [100 100 900 760]);   % mag+phase 2단 패널 높이 확보
tabGroup  = uitabgroup(fig);
tabBefore = uitab(tabGroup, 'Title', 'Before');
tabAfter  = uitab(tabGroup, 'Title', 'After');

%% ── BEFORE — 흔한 문제: 단일 패널, mag에 semilogx(물리단위인데 로그-로그 아님), bare 'Magnitude', 얇은 선, 위상 없음, grid 없음
axes('Parent', tabBefore);                  % 현재 축 = Before 탭 → 아래 bare 호출이 여기에 그려짐
semilogx(f, mag, 'b');                      % 물리 단위인데 semilogx + 얇은 선
xlabel('freq');                             % 단위 없음
ylabel('Magnitude');                        % 물리 단위 없음
title('Bode');

%% ── AFTER — plot-style Common + frequency-response 케이스 적용
fontSize  = 24;  fontName = 'Times New Roman';  lineWidth = 3.0;
axLineWidth = 1.0;                              % 축 박스·그리드 선 두께
gridStyle = '--';  gridAlpha = 0.25;
legendMaxHeightFrac = 0.4;                      % 범례 띠가 박스 높이의 이 비율을 넘으면 축 밖으로
yTickInsetFrac = 0.05;                          % 맨 위·아래 y 눈금과 박스 끝 사이 최소 간격
colorOrder = [0 0 0; 1 0 0; 0 0 1];

% mag+phase는 결합 패널 → 같은 탭 안에 subplot (독립 플롯이면 탭 분리)
axMag   = subplot(2, 1, 1, 'Parent', tabAfter);
axPhase = subplot(2, 1, 2, 'Parent', tabAfter);

% 크기: 물리 단위 → loglog (로그 스케일 먼저 그린 뒤 hold)
loglog(axMag, f, mag, 'LineStyle', '-', 'Color', colorOrder(1,:), 'LineWidth', lineWidth);
ylabel(axMag, 'Magnitude (mm/A)');          % 출력/입력 물리 단위 명시
xlabel(axMag, 'Frequency (Hz)');            % 패널별 PNG 분리 저장 → 위 패널에도 x라벨
xlim(axMag, [f(1), f(end)]);
ylim(axMag, [1e-2, 1e2]);                   % 데이터(약 0.013~20) 포함, decade tick (눈금 여유는 finalizeYLimits)

% 위상: 항상 semilogx
semilogx(axPhase, f, phase, 'LineStyle', '-', 'Color', colorOrder(1,:), 'LineWidth', lineWidth);
ylabel(axPhase, 'Phase (deg)');
xlabel(axPhase, 'Frequency (Hz)');
xlim(axPhase, [f(1), f(end)]);
ylim(axPhase, [-190, 10]);

% per-axes styling 적용 (두 패널 모두)
for ax = [axMag, axPhase]
    set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', 'LineWidth', axLineWidth, ...
            'XGrid', 'on', 'YGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha, ...
            'GridLineWidth', axLineWidth);      % GridLineWidth: R2023a+
    pbaspect(ax, [2 1 1]);                  % 종횡비 명시 (Common 기본; freq 모듈은 미지정)
end
% 범례: 모든 axes에 존재 (단일 시리즈라도 두 패널 모두) — 1개 항목 → 축 안 northeast
lgdMag   = legend(axMag,   {'FRF'}, 'Location', 'northeast', 'NumColumns', 1, 'FontSize', fontSize, 'FontName', fontName);
lgdPhase = legend(axPhase, {'FRF'}, 'Location', 'northeast', 'NumColumns', 1, 'FontSize', fontSize, 'FontName', fontName);
finalizeYLimits(axMag,   lgdMag,   legendMaxHeightFrac, yTickInsetFrac);   % 범례 여유 + y 눈금 안쪽 배치 (패널마다)
finalizeYLimits(axPhase, lgdPhase, legendMaxHeightFrac, yTickInsetFrac);
linkaxes([axMag, axPhase], 'x');

%% 축(subplot 패널)별 PNG 저장 — 탭 figure에서 exportgraphics(fig)/print(fig)는 오류 → 축 단위 export
figName = 'frequency_response';
tabs = findobj(fig, 'Type', 'uitab');                       % 생성 순서 유지
for k = 1:numel(tabs)
    tabName = matlab.lang.makeValidName(tabs(k).Title);
    axList  = flipud(findobj(tabs(k), 'Type', 'axes'));     % Children는 최신 우선 → 생성 순서로
    for j = 1:numel(axList)
        pngName = sprintf('%s_%d_%s_%d.png', figName, k, tabName, j);   % 탭 번호·축 번호 항상 포함 → 파일명 고유
        exportgraphics(axList(j), fullfile(outDir, pngName), 'Resolution', 300);
    end
end

disp('frequency_response_example: before/after PNG 저장 완료 → image_fig/');

%% 로컬 함수 — plot-style SKILL.md의 finalizeYLimits (그대로 붙여넣기)
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
