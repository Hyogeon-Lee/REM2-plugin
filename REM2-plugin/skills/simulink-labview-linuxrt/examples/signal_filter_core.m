function y = signal_filter_core(u, mode, Ts, lpf_fc, ma_len, proc_q, meas_r, pf_N) %#codegen
%SIGNAL_FILTER_CORE One-sample step of a selectable denoising filter.
%   y = signal_filter_core(u, mode, Ts, lpf_fc, ma_len, proc_q, meas_r, pf_N)
%
%   mode    0 bypass
%           1 Butterworth low-pass, 1st order   (lpf_fc)     butter + filter
%           2 Butterworth low-pass, 2nd order   (lpf_fc)     butter + filter
%           3 moving average                    (ma_len)     filter
%           4 Kalman filter, const. velocity    (proc_q, meas_r)         trackingKF
%           5 particle filter, const. velocity  (proc_q, meas_r, pf_N)   static SIR
%   Ts      sample period [s]; must equal the real loop period on the target
%   lpf_fc  cutoff frequency [Hz]
%   ma_len  window length [samples], 1..1000
%   proc_q  white-acceleration spectral density [unit^2/s^3]
%   meas_r  measurement noise variance per sample [unit^2]
%   pf_N    particle count, 1..1000
%
%   The selected filter is re-initialised from u whenever mode changes,
%   so switching modes at run time does not start from stale state.
%   All state is fixed-size: generated code needs no dynamic memory.

persistent lastMode
if isempty(lastMode), lastMode = -1; end

% Parameters come from LabVIEW at run time: clamp to safe ranges.
Ts = max(Ts, 1e-6);
fc = min(max(lpf_fc, 1e-3), 0.45/Ts);   % stay below Nyquist
q  = max(proc_q, 0);
r  = max(meas_r, 1e-12);

m = round(mode);
init = m ~= lastMode;
lastMode = m;

switch m
    case 1
        y = butterLowpass1(u, Ts, fc, init);
    case 2
        y = butterLowpass2(u, Ts, fc, init);
    case 3
        y = movingAverage(u, ma_len, init);
    case 4
        y = kalmanCv(u, Ts, q, r, init);
    case 5
        y = particleCv(u, Ts, q, r, pf_N, init);
    otherwise
        y = u;
end
end

%--------------------------------------------------------------------------
function y = butterLowpass1(u, Ts, fc, init)
% 1st-order Butterworth (bilinear transform), Wn = fc/(fs/2) = 2*fc*Ts.
% Coefficients are redesigned only when Wn changes.
persistent b a z wn
if isempty(b), wn = 0.1; [b, a] = butter(1, wn); z = 0; end
if 2*fc*Ts ~= wn, wn = 2*fc*Ts; [b, a] = butter(1, wn); end
if init, z(:) = filtic(b, a, u, u); end   % DC steady state at y = u; (:) keeps z fixed-size
[y, z] = filter(b, a, u, z);
end

%--------------------------------------------------------------------------
function y = butterLowpass2(u, Ts, fc, init)
% 2nd-order Butterworth (bilinear transform), Wn = 2*fc*Ts.
persistent b a z wn
if isempty(b), wn = 0.1; [b, a] = butter(2, wn); z = zeros(2, 1); end
if 2*fc*Ts ~= wn, wn = 2*fc*Ts; [b, a] = butter(2, wn); end
if init, z(:) = filtic(b, a, [u; u], [u; u]); end
[y, z] = filter(b, a, u, z);
end

%--------------------------------------------------------------------------
function y = movingAverage(u, len, init)
% Moving average as an FIR filter b = [1/L ... 1/L 0 ... 0] of fixed
% length MA_MAX, so the state size never changes at run time.
MA_MAX = 1000;
persistent b z L
if isempty(b), b = zeros(1, MA_MAX); z = zeros(MA_MAX - 1, 1); L = 0; end
Lnew = min(max(round(len), 1), MA_MAX);
if Lnew ~= L
    L = Lnew;
    b(:) = 0;
    b(1:L) = 1/L;
    init = true;
end
if init, z(:) = filtic(b, 1, u, u*ones(MA_MAX - 1, 1)); end
[y, z] = filter(b, 1, u, z);
end

%--------------------------------------------------------------------------
function y = kalmanCv(u, Ts, q, r, init)
% Kalman filter with the built-in 1-D constant-velocity model:
%   x = [p; v],  x(k) = [1 Ts; 0 1]*x(k-1) + [Ts^2/2; Ts]*a,  a ~ N(0, q/Ts)
%   z(k) = p(k) + v,  v ~ N(0, r)
% q/Ts turns the continuous acceleration density q into the variance of a
% piecewise-constant acceleration over one sample.
persistent kf
if isempty(kf)
    kf = trackingKF('MotionModel', '1D Constant Velocity', 'State', [0; 0], ...
        'StateCovariance', eye(2), 'ProcessNoise', 1, 'MeasurementNoise', 1);
end
if init
    kf.State = [u; 0];
    kf.StateCovariance = [r 0; 0 2*r/Ts^2];   % velocity variance of a two-sample difference
end
kf.ProcessNoise = q/Ts;
kf.MeasurementNoise = r;
predict(kf, Ts);
x = correct(kf, u);
y = x(1);
end

%--------------------------------------------------------------------------
function y = particleCv(u, Ts, q, r, N, init)
% Bootstrap particle filter (SIR) with the same model as kalmanCv:
%   propagate each particle with a ~ N(0, q/Ts), weight by the Gaussian
%   likelihood exp(-(z - p)^2/(2r)), estimate = weighted mean, then
%   systematic resampling every step.
% Hand-written because trackingPF needs dynamic memory in generated code;
% all arrays here are fixed at PF_NMAX.
PF_NMAX = 1000;
persistent p v pn vn w Nact
if isempty(p)
    p = zeros(PF_NMAX, 1); v = p; pn = p; vn = p; w = p; Nact = 0;
end
N = min(max(round(N), 1), PF_NMAX);
if init || N ~= Nact
    Nact = N;
    for i = 1:N
        p(i) = u + sqrt(r)*randn;
        v(i) = sqrt(2*r)/Ts*randn;
    end
end

sigA = sqrt(q/Ts);
lwmax = -inf;
for i = 1:N
    a = sigA*randn;
    p(i) = p(i) + Ts*v(i) + 0.5*Ts^2*a;
    v(i) = v(i) + Ts*a;
    d = u - p(i);
    w(i) = -0.5*d*d/r;                % log-weight
    if w(i) > lwmax, lwmax = w(i); end
end
wsum = 0;  pe = 0;
for i = 1:N
    w(i) = exp(w(i) - lwmax);         % subtract max: no underflow
    wsum = wsum + w(i);
    pe = pe + w(i)*p(i);
end
y = pe/wsum;

% Systematic resampling: N evenly spaced pointers, one random offset.
stepw = wsum/N;
c = rand*stepw;
j = 1;  cum = w(1);
for i = 1:N
    while c > cum && j < N
        j = j + 1;
        cum = cum + w(j);
    end
    pn(i) = p(j);  vn(i) = v(j);
    c = c + stepw;
end
for i = 1:N
    p(i) = pn(i);  v(i) = vn(i);
end
end
