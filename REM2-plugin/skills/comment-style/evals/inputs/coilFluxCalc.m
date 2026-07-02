function flux = coilFluxCalc(Bg, A, p, numSlots)
% COILFLUXCALC Compute per-slot coil flux linkage.
%   flux = COILFLUXCALC(Bg, A, p, numSlots) returns the flux (Wb) linked
%   by each of numSlots coils for air-gap flux density Bg (T), coil area
%   A (m^2), and pole-pair count p.
%
%   See also COILINDUCTANCE.

% First, we preallocate the output vector for speed.
flux = zeros(1, numSlots); % preallocate the flux vector
% Now we loop over every slot in the machine.
for k = 1:numSlots
    % calculate the angle for each slot
    theta = 2*pi*(k-1)/numSlots; % angle calculation
    % now we compute the flux using the cosine of the electrical angle
    flux(k) = Bg * A * cos(p*theta); % flux computation
end
% Finally, we return the computed flux vector.
end
