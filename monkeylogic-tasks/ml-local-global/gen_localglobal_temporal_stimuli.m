% make_five_tone_temporal_local_global_AB.m
% Creates timing-based stimuli for A and B:
% AAAAA_regular, AAAA_delayA
% BBBBB_regular, BBBB_delayB
% All stimuli RMS-matched

fs = 44100;          % sampling rate
toneDur = 0.500;     % tone duration (s)
interTone = 0.500;   % standard silence between tones (s)
rampDur = 0.005;     % 5 ms linear ramp

A_freq = 350;        % Tone A frequency (Hz)
B_freq = 750;        % Tone B frequency (Hz)

% -----------------
% Helper: tone with ramp
% -----------------
makeTone = @(f) applyRamp( ...
    sin(2*pi*f*(0:1/fs:toneDur-1/fs)).', fs, rampDur );

toneA = makeTone(A_freq);
toneB = makeTone(B_freq);

% Silence definitions
sil_short = zeros(round(interTone * fs), 1);
sil_long  = zeros(round(2 * interTone * fs), 1);

% -----------------
% Define conditions
% -----------------
conds = struct();
conds.AAAAA_regular = {'A','A','A','A','A'};
conds.AAAA_delayA   = {'A','A','A','A','A'};
conds.BBBBB_regular = {'B','B','B','B','B'};
conds.BBBB_delayB   = {'B','B','B','B','B'};

fields = fieldnames(conds);

% -----------------
% Build stimuli
% -----------------
stimStore = struct();

for i = 1:numel(fields)
    name = fields{i};
    letters = conds.(name);
    stim = [];

    for t = 1:5

        % Select tone identity
        if letters{t} == "A"
            stim = [stim; toneA];
        else
            stim = [stim; toneB];
        end

        % Insert silence (except after last tone)
        if t < 5
            if contains(name,'delay') && t == 4
                stim = [stim; sil_long];   % delayed final tone
            else
                stim = [stim; sil_short];  % regular timing
            end
        end
    end

    stimStore.(name) = stim;
end

% -----------------
% RMS matching
% -----------------
rmsVals = zeros(numel(fields),1);
for i = 1:numel(fields)
    x = stimStore.(fields{i});
    rmsVals(i) = sqrt(mean(x.^2));
end

targetRMS = mean(rmsVals);

for i = 1:numel(fields)
    name = fields{i};
    x = stimStore.(name);
    x = x * (targetRMS / sqrt(mean(x.^2)));
    stimStore.(name) = x;
end

% -----------------
% Write WAV files
% -----------------
for i = 1:numel(fields)
    name = fields{i};
    audiowrite([name '.wav'], stimStore.(name), fs);
    fprintf('Wrote %s.wav  (RMS = %.5f)\n', ...
        name, sqrt(mean(stimStore.(name).^2)));
end

%% -----------------
% Helper: ramp function
% -----------------
function y = applyRamp(y, fs, rampDur)
    n = round(rampDur * fs);
    if n > 0
        ramp = linspace(0,1,n).';
        y(1:n) = y(1:n) .* ramp;
        y(end-n+1:end) = y(end-n+1:end) .* flipud(ramp);
    end
end
