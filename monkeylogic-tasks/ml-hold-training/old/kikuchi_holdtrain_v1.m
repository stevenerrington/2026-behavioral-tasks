% auditory_button_task.m
%
% ML 2.2.49
%
% Task:
%   Red dot appears
%   Wait for button press
%   Dot turns green
%   Hold button 500 ms
%   Sound plays while button remains held
%   Release within 1000 ms after sound offset
%   Wait 1500 ms
%   Reward
%
% Penalty:
%   Failure to release within 1000 ms
%   -> no reward on NEXT trial

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

button_num = 1;
sound_obj  = 2;      % TaskObject#1 = sound

pre_hold       = 500;    % ms
release_window = 1000;   % ms
reward_delay   = 1500;   % ms
reward_dur     = 100;    % ms

sound_dur = get_object_duration(sound_obj);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

RED_ON       = 10;
BUTTON_DOWN  = 11;
GREEN_ON     = 12;
AUDIO_ON     = 13;
AUDIO_OFF    = 14;
RELEASED     = 15;
LATE_RELEASE = 16;
REWARD_ON    = 17;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PENALTY STATE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~isfield(TrialRecord.User,'NoRewardThisTrial')
    TrialRecord.User.NoRewardThisTrial = false;
end

if ~isfield(TrialRecord.User,'NoRewardNextTrial')
    TrialRecord.User.NoRewardNextTrial = false;
end

TrialRecord.User.NoRewardThisTrial = ...
    TrialRecord.User.NoRewardNextTrial;

TrialRecord.User.NoRewardNextTrial = false;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GRAPHICS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

red_dot = CircleGraphic(null_);
red_dot.List = { ...
    [1 0 0], ...     % edge color
    [1 0 0], ...     % face color
    0.25, ...        % radius (deg)
    [0 0] ...        % position
    };

green_dot = CircleGraphic(null_);
green_dot.List = { ...
    [0 1 0], ...
    [0 1 0], ...
    0.25, ...
    [0 0] ...
    };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BUTTON OBJECT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

btn = SingleButton(button_);
btn.Button = button_num;
btn.TouchMode = true;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCENE 1
% WAIT FOR BUTTON PRESS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

wait_press = WaitThenHold(btn);
wait_press.WaitTime = 10000;
wait_press.HoldTime = 0;

scene1 = create_scene(red_dot);

run_scene(scene1,RED_ON);

scene_press = create_scene(wait_press);

run_scene(scene_press);

if ~wait_press.Success
    trialerror(1);
    return
end

eventmarker(BUTTON_DOWN);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCENE 2
% HOLD 500 ms
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hold_pre = WaitThenHold(btn);
hold_pre.WaitTime = 0;
hold_pre.HoldTime = pre_hold;

scene2 = create_scene(hold_pre,green_dot);

run_scene(scene2,GREEN_ON);

if ~hold_pre.Success
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCENE 3
% HOLD THROUGH SOUND
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hold_sound = WaitThenHold(btn);
hold_sound.WaitTime = 0;
hold_sound.HoldTime = sound_dur;

snd = AudioSound(hold_sound);
snd.List = {sound_obj};

scene3 = create_scene(snd,green_dot);

run_scene(scene3,AUDIO_ON);

eventmarker(AUDIO_OFF);

if ~hold_sound.Success
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCENE 4
% REQUIRE RELEASE WITHIN 1000 ms
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

released_btn = NotAdapter(btn);

release_check = WaitThenHold(released_btn);
release_check.WaitTime = release_window;
release_check.HoldTime = 20;

scene4 = create_scene(release_check,green_dot);

run_scene(scene4);

if ~release_check.Success

    TrialRecord.User.NoRewardNextTrial = true;

    eventmarker(LATE_RELEASE);

    trialerror(6);
    return
end

eventmarker(RELEASED);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DELAY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

idle(reward_delay);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% REWARD
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~TrialRecord.User.NoRewardThisTrial
    goodmonkey(reward_dur,'eventmarker',REWARD_ON);
end

trialerror(0);