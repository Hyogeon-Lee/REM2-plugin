% 지저분한 시간 응답 플롯 — plot-style eval 입력 (규칙 위반: shorthand 색 문자열,
% 라벨/단위/한계/그리드/범례 없음, title 있음)
t = linspace(0, 5, 500);
y1 = exp(-0.5*t) .* sin(4*t);
y2 = exp(-0.3*t) .* sin(3*t);
figure;
plot(t, y1, 'r-', t, y2, 'b--');
title('response');
