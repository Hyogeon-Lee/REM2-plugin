% 이름   : frequency_response_example
% 용도   : plot-style frequency-response 케이스 — before/after 비교 예제 (FRF, 물리 단위 mag)
% 작성자 : REM2 / 2026
% 사용법 : MATLAB에서 직접 실행 (외부 데이터 불필요). image_fig/에 PNG 저장
% 의존성 : 없음 (기본 MATLAB, Control System Toolbox 불필요)

%% 합성 데이터 — 2차 시스템 주파수응답 (변위/전류, mm/A)
clear; clc;
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

%% ── BEFORE — 흔한 문제: 단일 패널, mag에 semilogx(물리단위인데 로그-로그 아님), bare 'Magnitude', 얇은 선, 위상 없음, grid 없음
figBefore = figure('Name', 'frequency-response BEFORE');
semilogx(f, mag, 'b');                      % 물리 단위인데 semilogx + 얇은 선
xlabel('freq');                             % 단위 없음
ylabel('Magnitude');                        % 물리 단위 없음
title('Bode');
exportgraphics(figBefore, fullfile(outDir, 'frequency_response_before.png'), 'Resolution', 300);

%% ── AFTER — plot-style Common + frequency-response 케이스 적용
fontSize  = 24;  fontName = 'Times New Roman';  lineWidth = 3.0;
gridStyle = '--';  gridAlpha = 0.25;
colorOrder = [0 0 0; 1 0 0; 0 0 1];

figAfter = figure('Name', 'frequency-response AFTER', 'Color', 'w', ...
                  'Units', 'pixels', 'Position', [100 100 900 760]);
axMag   = subplot(2, 1, 1, 'Parent', figAfter);
axPhase = subplot(2, 1, 2, 'Parent', figAfter);

% 크기: 물리 단위 → loglog (로그 스케일 먼저 그린 뒤 hold)
loglog(axMag, f, mag, 'LineStyle', '-', 'Color', colorOrder(1,:), 'LineWidth', lineWidth);
ylabel(axMag, 'Magnitude (mm/A)');          % 출력/입력 물리 단위 명시
xlim(axMag, [f(1), f(end)]);
ylim(axMag, [1e-2, 1e2]);                   % 데이터(약 0.013~20) 포함, decade tick

% 위상: 항상 semilogx
semilogx(axPhase, f, phase, 'LineStyle', '-', 'Color', colorOrder(1,:), 'LineWidth', lineWidth);
ylabel(axPhase, 'Phase (deg)');
xlabel(axPhase, 'Frequency (Hz)');          % 아래 패널만 x라벨
xlim(axPhase, [f(1), f(end)]);
ylim(axPhase, [-190, 10]);

% per-axes styling 적용 (두 패널 모두)
for ax = [axMag, axPhase]
    set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', ...
            'XGrid', 'on', 'YGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha);
    pbaspect(ax, [2 1 1]);                  % 종횡비 명시 (Common 기본; freq 모듈은 미지정)
end
% 범례: 모든 axes에 존재 (단일 시리즈라도 두 패널 모두)
legend(axMag,   {'FRF'}, 'Location', 'northeast', 'FontSize', fontSize, 'FontName', fontName);
legend(axPhase, {'FRF'}, 'Location', 'northeast', 'FontSize', fontSize, 'FontName', fontName);
linkaxes([axMag, axPhase], 'x');
exportgraphics(figAfter, fullfile(outDir, 'frequency_response_after.png'), 'Resolution', 300);

disp('frequency_response_example: before/after PNG 저장 완료 → image_fig/');
