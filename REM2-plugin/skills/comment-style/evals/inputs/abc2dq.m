function [d, q] = abc2dq(a, b, c, theta)
alpha = (2*a - b - c) / 3;
beta = (b - c) / sqrt(3);
d = alpha .* cos(theta) + beta .* sin(theta);
q = -alpha .* sin(theta) + beta .* cos(theta);
end
