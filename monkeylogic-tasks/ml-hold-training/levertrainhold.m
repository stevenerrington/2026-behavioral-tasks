%levertrainhold (timing script)
% This task requires the animal to hold a lever down for a specific length
% of time. Once the animal presses the lever, the target will appear. The
% animal must not release the lever until the target changes, and is not
% rewarded if it is released too early.

% Naming for TaskObjects defined in the conditions file:
start_spot = 1;
sound_a = 2;

% Define Time Intervals (in ms):
wait_press = 5000;
hold_time = 400; %250 when initially training
wait_release = 500;
sound_reward_delay = 750;
sound_duration = 300;  % duration in ms

%%%%%%%%% TASK %%%%%%%%

% Ensure the lever is NOT being held before the trial begins
released = ~eyejoytrack('holdtouch', 1, [], wait_release);
if ~released
    trialerror(4); % Lever held continuously before trial start
    idle(200);
    return
end

% Show Fixation Spot, Cues the Beginning of a Trial:
toggleobject(start_spot, 'eventmarker', 120); % Fixation Spot Shown

% Waits for press
pressed = eyejoytrack('acquiretouch', 1, [], wait_press); % Here '1' = button/lever index, not the target
if ~pressed
    toggleobject(start_spot, 'eventmarker', 125); % Didn't press by end of fixation cue
    trialerror(1); % Didn't press in time
    idle(200); % Red Error Screen
    return
end

% % Play sound
% toggleobject(sound_a, 'eventmarker', 121); % Targ 1 On

% Tests lever remains pressed
held = eyejoytrack('holdtouch', 1, [], sound_duration);
if ~held
    toggleobject(sound_a, 'eventmarker', 126); % Turn off target
    toggleobject(start_spot, 'eventmarker', 126); % Turn off target
    trialerror(2); % Released too soon
    idle(200); % Red Error Screen
    return
end

% % Waits for release
% released = ~eyejoytrack('holdtouch', 1, [], wait_release);
% if (~released)
%     trialerror(4); % Did not release in time
%     toggleobject(start_spot, 'eventmarker', 124); % Turn off target
%     idle(200, [1, 0, 0]); % Red Error Screen
%     return
% end

toggleobject(start_spot, 'eventmarker', 124); % Turn off target
trialerror(0); % Correct
goodmonkey(500); % Reward