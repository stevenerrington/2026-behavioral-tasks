% function Mk_basic_sound_v2()
% 
% % -----------------------
% % PARAMETERS
% % -----------------------
% auditory_stim = 2;   % TaskObject#2 = snd(stim.wav)
% 
% SoundOn  = 25;
% SoundOff = 26;
% 
% % Optional (solo se vuoi etichette nel bhv file)
% % bhv_code(25,'SoundOn');
% % bhv_code(26,'SoundOff');
% 
% % -----------------------
% % GET SOUND DURATION
% % -----------------------
% sound_ms = get_object_duration(auditory_stim);
% 
% if isempty(sound_ms) || sound_ms <= 0
%     error('Invalid sound duration. Check snd(stim.wav).');
% end
% 
% % -----------------------
% % CREATE AUDIO ADAPTER
% % -----------------------
% snd = AudioSound(null_);
% snd.List = auditory_stim;    % reference TaskObject#2
% 
% % Run for entire duration
% tc = TimeCounter(snd);
% tc.Duration = sound_ms;
% 
% scene = create_scene(tc);
% 
% % -----------------------
% % RUN SCENE
% % -----------------------
% run_scene(scene, SoundOn);   % eventmarker sent automatically here
% 
% eventmarker(SoundOff);
% 
% trialerror(0);
% 
% end

%% ML1  version 1

hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');  % stop the task immediately


auditory_stim = 2;


SoundOn = 25 ;
SoundOff = 26;

% Get duration 
sound_ms = get_object_duration(auditory_stim);

if isempty(sound_ms) || sound_ms <= 0
    error('Sound duration invalid. Check conditions file.');
end

% Turn sound ON
toggleobject(auditory_stim, 'status', 'on', 'eventmarker', SoundOn);

% Wait full duration
idle(sound_ms);

% Turn sound OFF
toggleobject(auditory_stim, 'status', 'off', 'eventmarker', SoundOff);


