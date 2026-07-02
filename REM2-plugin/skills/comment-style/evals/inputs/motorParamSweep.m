function results = motorParamSweep(gapValues) %#codegen
% MOTORPARAMSWEEP Sweep air-gap length and collect torque results.
%   results = MOTORPARAMSWEEP(gapValues) evaluates the analytic torque
%   model for each air-gap length in gapValues (mm) and returns the
%   torque (N*m), scaled by the converged-point ratio.

% Preallocate the results vector before the main loop for speed.
results = zeros(size(gapValues)); % preallocated result array
nConverged = 0; % number of converged points
debugGap = gapValues(1); %#ok<NASGU> kept for breakpoint inspection
% Loop over each of the gap values one at a time.
for k = 1:numel(gapValues)
    g = gapValues(k); % the current gap value in millimeters
    % old scaling approach, kept for reference:
    % results(k) = 0.8 / (1 + g) + 0.2;
    % Now we evaluate the torque model for this gap.
    results(k) = 1 / (1 + g); % evaluate the model
    if results(k) > 0.1
        nConverged = nConverged + 1; % count the converged point
    end
end
% Finally we scale by the number of converged points.
results = results * nConverged / numel(gapValues);
end
