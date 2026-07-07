%% Generate tone sequences
clear;
clc;

%% Parameters
fs = 48000;          % Sampling rate (Hz)
toneDur = 0.050;     % Tone duration (s)
SOA = 0.150;         % Stimulus onset asynchrony (s)

freqA = 800;         % Hz
freqB = 1600;        % Hz

amplitude = 0.8;

%% Derived parameters
toneSamples = round(toneDur * fs);
silenceSamples = round((SOA - toneDur) * fs);

t = (0:toneSamples-1)/fs;

% Generate tones
toneA = amplitude * sin(2*pi*freqA*t);
toneB = amplitude * sin(2*pi*freqB*t);

silence = zeros(1, silenceSamples);

%% Sequence definitions
seqs = {
    {'A','A','A','A','A'}, 'AAAAA';
    {'A','A','A','A','B'}, 'AAAAB';
    {'B','B','B','B','B'}, 'BBBBB';
    {'B','B','B','B','A'}, 'BBBBA';
    };

%% Generate first four sequences
for s = 1:size(seqs,1)

    pattern = seqs{s,1};
    filename = seqs{s,2};

    y = [];

    for k = 1:length(pattern)

        if pattern{k} == 'A'
            y = [y toneA];
        else
            y = [y toneB];
        end

        % Add silence after tones 1-4 only
        if k < length(pattern)
            y = [y silence];
        end
    end

    audiowrite(fullfile('C:\Experiments\MonkeyLogic\monkeylogic-tasks\ml-local-global\stimuli',[filename '.wav']), y, fs);

end

%% Generate AAAA_A (double SOA before final tone)

doubleSilence = zeros(1, round((2*SOA - toneDur) * fs));
% = 250 ms silence after the 4th tone

y = [];

% First four A tones
for k = 1:4
    y = [y toneA];

    if k < 4
        % Normal SOA
        y = [y silence];
    else
        % Double SOA before final tone
        y = [y doubleSilence];
    end
end

% Fifth tone
y = [y toneA];

audiowrite('AAAA_A.wav', y, fs);

disp('Finished writing all wav files.');