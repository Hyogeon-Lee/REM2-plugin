%% BEFORE — over-commented
% function L = coilInductance(N, mu_r, A_core, l_core, g)
% % First, we define the permeability of free space.
% mu0 = 4*pi*1e-7; % permeability of free space
% % Next, we calculate the reluctance of the core.
% % The reluctance is the length divided by permeability times area.
% R_core = l_core / (mu_r * mu0 * A_core); % calculate core reluctance
% % Now we calculate the reluctance of the air gap.
% % The air gap reluctance uses mu0 only because air has mu_r = 1.
% R_gap = g / (mu0 * A_core); % calculate air gap reluctance
% % The total reluctance is the sum of the two reluctances.
% R_total = R_core + R_gap; % total reluctance
% % Finally, the inductance is N squared over the total reluctance.
% L = N^2 / R_total; % calculate inductance
% end

%% AFTER — concise, algorithm-critical only
function L = coilInductance(N, mu_r, A_core, l_core, g)
mu0 = 4*pi*1e-7;                         % vacuum permeability (H/m)

% magnetic circuit: core and gap reluctances in series
R_core = l_core / (mu_r * mu0 * A_core);
R_gap  = g / (mu0 * A_core);

L = N^2 / (R_core + R_gap);              % L = N^2 / R_total
end
