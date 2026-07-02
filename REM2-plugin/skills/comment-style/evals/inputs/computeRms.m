function r = computeRms(x)
% first we square every sample of the signal
xsq = x.^2; % squared signal
% then we take the mean of the squared samples
m = mean(xsq); % mean of squares
% finally we take the square root to get the rms
r = sqrt(m); % root mean square
end
