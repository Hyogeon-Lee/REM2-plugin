% 스타일 없는 FRF magnitude 플롯 — plot-style eval 입력 (선형 주파수축, 라벨/단위 없음)
f = logspace(0, 3, 200);
H = 1 ./ (1 + 1i*f/50);
figure;
plot(f, abs(H));
