clc; clear;

%% ---------------- PARAMETERS ----------------

fs = 44100;          % Sample rate (Hz)

context_dur = 0.4;   % seconds
tone_dur = 0.1;      % seconds

low_freq = 600;      % Hz (macaque-friendly)
high_freq = 3000;    % Hz

ramp_dur = 0.01;     % 10 ms onset/offset ramps

target_rms = 0.05;   % controls loudness (adjust for rig)

outdir = 'stimuli';
if ~exist(outdir,'dir')
    mkdir(outdir);
end

%% ---------------- TIME VECTORS ----------------

t_context = (0:1/fs:context_dur-1/fs)';
t_tone = (0:1/fs:tone_dur-1/fs)';

%% ---------------- WHITE NOISE ----------------

white_noise = randn(length(t_context),1);
white_noise = applyRamp(white_noise, fs, ramp_dur);
white_noise = rmsMatch(white_noise, target_rms);

audiowrite('white_noise.wav', white_noise, fs);

%% ---------------- PINK NOISE ----------------

pink_noise = generatePinkNoise(length(t_context));
pink_noise = applyRamp(pink_noise, fs, ramp_dur);
pink_noise = rmsMatch(pink_noise, target_rms);

audiowrite('pink_noise.wav', pink_noise, fs);

%% ---------------- LOW TONE ----------------

low_tone = sin(2*pi*low_freq*t_tone);
low_tone = applyRamp(low_tone, fs, ramp_dur);
low_tone = rmsMatch(low_tone, target_rms);

audiowrite('low_tone.wav', low_tone, fs);

%% ---------------- HIGH TONE ----------------

high_tone = sin(2*pi*high_freq*t_tone);
high_tone = applyRamp(high_tone, fs, ramp_dur);
high_tone = rmsMatch(high_tone, target_rms);

audiowrite('high_tone.wav', high_tone, fs);

fprintf('Stimuli generated successfully.\n');

%% =========================================================
%% FUNCTIONS
%% =========================================================

function y = applyRamp(x, fs, ramp_dur)
    nRamp = round(ramp_dur * fs);
    ramp = linspace(0,1,nRamp)';
    
    y = x;
    y(1:nRamp) = y(1:nRamp) .* ramp;
    y(end-nRamp+1:end) = y(end-nRamp+1:end) .* flipud(ramp);
end

function y = rmsMatch(x, target_rms)
    x = x - mean(x);
    current_rms = sqrt(mean(x.^2));
    y = x * (target_rms / current_rms);
end

function pink = generatePinkNoise(N)
    white = randn(N,1);

    % Paul Kellet filter (stable, widely used)
    b = [0.049922035 -0.095993537 0.050612699 -0.004408786];
    a = [1 -2.494956002 2.017265875 -0.522189400];

    pink = filter(b, a, white);
end
