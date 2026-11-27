function [y_clean, y_noisy] = noise_gen_core(Ts, sig_amp, sig_freq, sig_offset, noise_std)
%NOISE_GEN_CORE One sample of a sine test signal plus white Gaussian noise.
%   [y_clean, y_noisy] = noise_gen_core(Ts, sig_amp, sig_freq, sig_offset, noise_std)
%
%   y_clean = sig_offset + sig_amp*sin(phase)
%   y_noisy = y_clean + noise_std*randn
%   phase  <- phase + 2*pi*sig_freq*Ts   (wrapped to [0, 2*pi))
%
%   The phase is accumulated with Ts instead of read from model time, so
%   the signal frequency stays correct when Ts is changed at run time.
%   Ts must equal the real loop period on the target.

persistent ph
if isempty(ph), ph = 0; end

y_clean = sig_offset + sig_amp*sin(ph);
y_noisy = y_clean + noise_std*randn;
ph = mod(ph + 2*pi*sig_freq*Ts, 2*pi);
end
