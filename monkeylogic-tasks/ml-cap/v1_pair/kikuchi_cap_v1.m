%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         L-CAPT: Latent Context Auditory Prediction
%         REVISED: Peripheral Target + Sound Pairing Task
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fixation_point  = 1;   % Central fixation spot
tone_obj        = 2;   % Low frequency tone (paired with cyan)
target_obj      = 3;   % Left peripheral target

fix_window      = 3;   % Fixation window radius (deg)
targ_window     = 5;   % Target window radius (deg)

delay_dist = linspace(500,2000,100);

fix_acquire     = 2000; % Time allowed to acquire fixation (ms)
fix_hold        = delay_dist(randperm(length(delay_dist),1));;  % Fixation hold before target appears (ms)
targ_hold       = 500;  % Duration monkey must hold gaze on target (ms)
tone_duration   = 400;  % Duration of tone (ms)
post_tone_delay = 500;  % Delay between tone offset and reward (ms)
iti             = 1000; % Inter-trial interval (ms)

reward_duration = 750;  % Juice reward duration (ms)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TRIAL CONDITIONS
% Assumes TrialRecord.CurrentCondition encodes:
%   1 = Left target,  cyan,    low tone
%   2 = Left target,  magenta, high tone
%   3 = Right target, cyan,    low tone
%   4 = Right target, magenta, high tone
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cond = TrialRecord.CurrentCondition;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FixOn       = 10;
TargOn      = 20;
ToneOn      = 30;
RewardOn    = 40;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 1: FIXATION ACQUISITION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(fixation_point, 'eventmarker', FixOn);

ontarget = eyejoytrack('acquirefix', fixation_point, fix_window, fix_acquire);
if ~ontarget
    trialerror(4); % no fixation
    toggleobject(fixation_point, 'status', 'off');
    idle(iti);
    return
end

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, fix_hold);
if ~ontarget
    trialerror(3); % broke fixation
    toggleobject(fixation_point, 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 2: PERIPHERAL TARGET APPEARS
% Monkey must look at the target and hold for 500 ms
% Fixation point remains on
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(target_obj, 'eventmarker', TargOn);

% Allow monkey to shift gaze to target
[ontarget, rt] = eyejoytrack('acquirefix', target_obj, targ_window, 2000);

% Can build in here saccade contingencies - after leaving the fixation
% window, they must arrive in the target window within 50 ms

if ~ontarget
    trialerror(4); % failed to acquire target
    toggleobject([fixation_point target_obj], 'status', 'off');
    idle(iti);
    return
end

% Hold gaze on target for 500 ms
ontarget = eyejoytrack('holdfix', target_obj, targ_window, targ_hold);
if ~ontarget
    trialerror(3); % broke fixation on target
    toggleobject([fixation_point target_obj], 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 3: TONE PLAYS
% Monkey must maintain fixation on target throughout
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(tone_obj, 'eventmarker', ToneOn);

ontarget = eyejoytrack('holdfix', target_obj, targ_window, tone_duration);
toggleobject(tone_obj, 'status', 'off');

if ~ontarget
    trialerror(3); % broke fixation during tone
    toggleobject([fixation_point target_obj tone_obj], 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 5: REWARD
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

goodmonkey(reward_duration, 'NumReward', 1, ...
    'PauseTime', 50, 'eventmarker', RewardOn);

trialerror(0); % correct

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CLEANUP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject([fixation_point target_obj], 'status', 'off');
idle(iti);