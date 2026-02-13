% Parameters
N = 1000;
t_min = 1000;   % ms
t_max = 1500;   % ms
tau   = 200;    % time constant (controls steepness)

% Generate truncated exponential samples
u = rand(N,1);

% Inverse CDF for truncated exponential
foreperiod = t_min - tau * log( ...
    1 - u .* (1 - exp(-(t_max - t_min)/tau)) ...
    );

save('foreperiod_dist.mat',"foreperiod")