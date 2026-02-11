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
auditory_stimulus = 1;       % TaskObject# for sound file

sound_reward_delay = 250;
sound_duration = get_object_duration(auditory_stimulus) + sound_reward_delay;  % duration in ms

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
InfoStart    = 100;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         TRIAL SEQUENCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Present stimulus 
toggleobject(auditory_stimulus, 'eventmarker', AudioOn);
idle(sound_duration)
toggleobject(auditory_stimulus, 'eventmarker', AudioOff);

trialerror(0); % Correct
eventmarker(ITIStart);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         INFO SEQUENCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
eventmarker(ITIStart);

% Trial number
eventmarker(200);
low_byte  = bitand(TrialRecord.CurrentTrialNumber, 255);
high_byte = bitshift(TrialRecord.CurrentTrialNumber, -8);
eventmarker(low_byte);
eventmarker(high_byte);
eventmarker(201);

% Condition
eventmarker(202);
eventmarker(TrialRecord.CurrentCondition);
eventmarker(203);

% Block
eventmarker(204);
eventmarker(TrialRecord.CurrentBlock);
eventmarker(205);
