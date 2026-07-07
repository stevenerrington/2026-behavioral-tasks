%% Parameters
Fs = 44100;          % Sampling frequency (Hz)
toneDur = 0.050;     % Tone duration (s)
gapDur  = 0.1;     % Silence duration (s)
amp = 0.8;           % Amplitude (0-1)

%% Time vectors
tTone = 0:1/Fs:toneDur-1/Fs;

%% Generate tones
tone800  = amp * sin(2*pi*800*tTone);
tone1600 = amp * sin(2*pi*1600*tTone);

%% Silence
gap = zeros(1, round(gapDur*Fs));

%% Construct stimulus
stimulus = [ ...
    tone800 gap ...
    tone800 gap ...
    tone800 gap ...
    tone800 gap ...
    tone1600 ];

%% Save as WAV
audiowrite('beep_train_0003.wav', stimulus, Fs);

%% Optional: Listen
sound(stimulus, Fs);

%% Optional: Plot waveform
t = (0:length(stimulus)-1)/Fs;
figure;
plot(t, stimulus);
xlabel('Time (s)');
ylabel('Amplitude');
title('Four 800-Hz tones followed by one 1600-Hz tone');
grid on;