function thd = computeThd(x, fs, f0, nHarm)
N = numel(x);
w = hann(N);
X = fft(x(:) .* w);
X = X(1:floor(N/2)+1);
mag = abs(X) / sum(w) * 2;
f = (0:floor(N/2))' * fs / N;
amp = zeros(nHarm, 1);
for h = 1:nHarm
    [~, ix] = min(abs(f - h*f0));
    lo = max(1, ix-2);
    hi = min(numel(mag), ix+2);
    amp(h) = max(mag(lo:hi));
end
thd = sqrt(sum(amp(2:end).^2)) / amp(1);
end
