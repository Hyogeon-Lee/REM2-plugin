import numpy as np


def lowpass_filter(x, fs, fc):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, d=1.0 / fs)
    H = 1.0 / (1.0 + 1j * (f / fc))
    return np.fft.irfft(X * H, n)
