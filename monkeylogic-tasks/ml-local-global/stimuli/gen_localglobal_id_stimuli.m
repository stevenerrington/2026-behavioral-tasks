% make_five_tone_stimuli_RMSmatched.m
% Creates four single-trial stimuli:
% AAAAA, BBBBB, AAAAB, BBBBA
% with equal RMS amplitude across all stimuli.

fs = 44100;          % sampling rate
toneDur = 0.500;     % tone duration (s)
interTone = 0.500;   % silence between tones (s)
rampDur = 0.005;     % 5 ms linear ramp

A_freq = 350;        % Tone A frequency (Hz)
B_freq = 750;       % Tone B frequency (Hz)

% -----------------
% Helper: tone with ramp
% -----------------
makeTone = @(f) applyRamp( ...
    sin(2*pi*f*(0:1/fs:toneDur-1/fs)).', fs, rampDur );

toneA = makeTone(A_freq);
toneB = makeTone(B_freq);

% Silence between tones
sil = zeros(round(interTone * fs), 1);

% -----------------
% Define sequences
% -----------------
seqs = struct();
seqs.AAAAA = {'A','A','A','A','A'};
seqs.BBBBB = {'B','B','B','B','B'};
seqs.AAAAB = {'A','A','A','A','B'};
seqs.BBBBA = {'B','B','B','B','A'};

fields = fieldnames(seqs);

% -----------------
% First pass: build stimuli
% -----------------
stimStore = struct();

for i = 1:numel(fields)
    name = fields{i};
    letters = seqs.(name);
    stim = [];

    for t = 1:5
        if letters{t} == "A"
            stim = [stim; toneA];
        else
            stim = [stim; toneB];
        end

        if t < 5
            stim = [stim; sil];
        end
    end

    stimStore.(name) = stim;
end

% -----------------
% RMS-match all four
% -----------------
rmsVals = zeros(numel(fields),1);

for i = 1:numel(fields)
    x = stimStore.(fields{i});
    rmsVals(i) = sqrt(mean(x.^2));
end

targetRMS = mean(rmsVals);   % or min(rmsVals) for conservative scaling

% Scale each stimulus
for i = 1:numel(fields)
    name = fields{i};
    x = stimStore.(name);
    currentRMS = sqrt(mean(x.^2));

    if currentRMS > 0
        x = x * (targetRMS / currentRMS);
    end

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
