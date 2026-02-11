% auditory_fixation_task.m
% MonkeyLogic 2 task:
%   Monkey fixates a central point for 500 ms
%   -> then a 5s auditory stimulus plays
%   -> monkey must hold fixation throughout
%
% Outcome:
%   Reward if fixation is maintained for full duration

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fixation_point     = 1;       % TaskObject# for fixation point
visual_stimulus    = 2;       % TaskObject# for image file
auditory_stimulus  = 3;       % TaskObject# for sound file

fix_window    = 2;        % fixation window radius (deg)
fix_hold_pre  = 500;      % ms fixation before sound

sound_reward_delay = 750;
sound_duration = 500 + sound_reward_delay;  % duration in ms

reward_duration = 300;    % ms juice reward
iti_duration = 1000;      % ms inter-trial interval

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FixspotOn    = 20;
NoFix        = 21;
Fixation     = 22;
FixBreak1    = 23;
FixBreak2    = 24;
FixBreak3    = 25;
FixBreak4    = 26;
TargetOn     = 27;
AudioOn      = 28;
TargetOff    = 30;
AudioOff     = 29;
RewardOnset  = 31;
ITIStart     = 32;
ITIEnd       = 33;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         TRIAL SEQUENCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Show fixation point
toggleobject(fixation_point, 'eventmarker', FixspotOn);

ontarget = eyejoytrack('acquirefix', fixation_point, fix_window, 2000);

if ~ontarget
    toggleobject(fixation_point, 'status', 'off');
    eventmarker(NoFix);
    trialerror(4); % No fixation
    return
end

eventmarker(Fixation);

% 2. Hold fixation before sound
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, fix_hold_pre);

if ~ontarget
    toggleobject(fixation_point, 'status', 'off');
    eventmarker(FixBreak2);
    trialerror(3); % Broke fixation
    return
end

% 3. Present stimulus during fixation
toggleobject(auditory_stimulus, 'eventmarker', AudioOn);
toggleobject(visual_stimulus,   'eventmarker', TargetOn);

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, sound_duration);

toggleobject(auditory_stimulus, 'eventmarker', AudioOff);
toggleobject(visual_stimulus,   'eventmarker', TargetOff);

if ~ontarget
    toggleobject(fixation_point, 'status', 'off');
    eventmarker(FixBreak3);
    trialerror(3); % Broke fixation during stimuli
    return
end

% ----------------------------------------------------------
% 4. Reward
trialerror(0); % Correct
goodmonkey(reward_duration, 'NumReward', 1, ...
    'PauseTime', 50, 'eventmarker', RewardOnset);

% 5. End fixation + ITI
toggleobject(fixation_point, 'status', 'off', 'eventmarker', ITIStart);