%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         L-CAPT: Delayed Match-To-Sample (Auditory)
%         Sample tone → Delay → Choose target → Confirm tone → Reward
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fixation_point  = 1;   % Central fixation spot (white)
grey_fix        = 2;   % Grey fixation spot (shown during sample)
sample_tone     = 3;   % Sample tone (low or high, set in conditions file)
targ_left       = 4;   % Left target  (colour varies by condition)
targ_right      = 5;   % Right target (colour varies by condition)
low_tone_confirm  = 6;  % low tone  = cyan target
high_tone_confirm = 7;  % high tone = magenta target

fix_window      = 3;   % Fixation window radius (deg)
targ_window     = 4;   % Target window radius (deg)


delay_dist = linspace(500,2000,100);

fix_acquire     = 2000; % Time to acquire fixation (ms)
fix_hold        = 500;  % Hold fixation before sample (ms)
sample_duration = 400;  % Sample tone duration (ms)
delay_duration  = delay_dist(randperm(length(delay_dist),1)); % WM delay between sample and choice (ms)
targ_hold       = 500;  % Hold on chosen target (ms)
confirm_duration = 400; % Confirmation tone duration (ms)
post_tone_delay = 500;  % Delay after confirm tone before reward (ms)
iti             = 2000; % Inter-trial interval (ms)

reward_duration = 750;  % Juice reward duration (ms)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TRIAL CONDITIONS
%   Cond 1: Low tone,  cyan=left,  magenta=right → correct = left
%   Cond 2: Low tone,  magenta=left, cyan=right  → correct = right
%   Cond 3: High tone, cyan=left,  magenta=right → correct = right
%   Cond 4: High tone, magenta=left, cyan=right  → correct = left
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cond = TrialRecord.CurrentCondition;

% Assign cyan/magenta identity based on which side they appear
if cond == 1 || cond == 3
    cyan_targ    = targ_left;
    magenta_targ = targ_right;
else
    cyan_targ    = targ_right;
    magenta_targ = targ_left;
end

% Correct target: low tone → cyan, high tone → magenta
if cond == 1 || cond == 2
    correct_targ = cyan_targ;
else
    correct_targ = magenta_targ;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FixOn       = 10;
SampleOn    = 20;
DelayOn     = 30;
ChoiceOn    = 40;
ConfirmOn   = 50;
RewardOn    = 60;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALISE BEHAVIOURAL VARIABLES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

correct     = 0;
rt          = NaN;
chosen_targ = NaN;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 1: FIXATION
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
% EPOCH 2: SAMPLE TONE
% Fixation point swaps to grey for duration of sample
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(fixation_point, 'status', 'off');
toggleobject(grey_fix, 'eventmarker', SampleOn);
toggleobject(sample_tone);

ontarget = eyejoytrack('holdfix', grey_fix, fix_window, sample_duration);
toggleobject(sample_tone, 'status', 'off');
toggleobject(grey_fix, 'status', 'off');
toggleobject(fixation_point, 'status', 'on');

if ~ontarget
    trialerror(3); % broke fixation during sample
    toggleobject([fixation_point grey_fix sample_tone], 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 3: DELAY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

eventmarker(DelayOn);

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, delay_duration);
if ~ontarget
    trialerror(3); % broke fixation during delay
    toggleobject(fixation_point, 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 4: CHOICE (free view)
% Fixation point off; monkey freely looks around
% Selection = dwelling on a target for targ_hold ms
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(fixation_point, 'status', 'off');
toggleobject([targ_left targ_right], 'eventmarker', ChoiceOn);

choice = 0;
while ~choice
    [look, rt] = eyejoytrack('acquirefix', [targ_left targ_right], targ_window, 2000);
    
    if ~look
        trialerror(2);
        toggleobject([targ_left targ_right], 'status', 'off');
        idle(iti);
        return
    end
    
    if look == 1; candidate = targ_left; else; candidate = targ_right; end
    
    held = eyejoytrack('holdfix', candidate, targ_window, targ_hold);
    if held
        chosen_targ = candidate;
        choice = 1;
    end
    % If not held, loop back and allow re-fixation
end

% Turn off unchosen target once selection confirmed
if chosen_targ == targ_left
    toggleobject(targ_right, 'status', 'off');
else
    toggleobject(targ_left, 'status', 'off');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 5: CONFIRM TONE
% Play tone paired with chosen target; monkey holds gaze

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Select confirm tone based on chosen target colour
if chosen_targ == cyan_targ
    confirm_tone = low_tone_confirm;
else
    confirm_tone = high_tone_confirm;
end

toggleobject(confirm_tone, 'eventmarker', ConfirmOn);

ontarget = eyejoytrack('holdfix', chosen_targ, targ_window, confirm_duration);
toggleobject(confirm_tone, 'status', 'off');

if ~ontarget
    trialerror(3); % broke fixation during confirm tone
    toggleobject([fixation_point chosen_targ confirm_tone], 'status', 'off');
    idle(iti);
    return
end

% Post-tone hold
ontarget = eyejoytrack('holdfix', chosen_targ, targ_window, post_tone_delay);
if ~ontarget
    trialerror(3); % broke fixation during post-tone delay
    toggleobject([fixation_point chosen_targ], 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 6: OUTCOME
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if chosen_targ == correct_targ
    correct = 1;
    trialerror(0); % correct
else
    correct = 0;
    trialerror(6); % incorrect
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% REWARD (correct trials only)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if correct
    goodmonkey(reward_duration, 'NumReward', 1, ...
        'PauseTime', 50, 'eventmarker', RewardOn);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SAVE BEHAVIOURAL DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

TrialRecord.User.RT(TrialRecord.CurrentTrialNumber)        = rt;
TrialRecord.User.Condition(TrialRecord.CurrentTrialNumber) = cond;
TrialRecord.User.Correct(TrialRecord.CurrentTrialNumber)   = correct;
TrialRecord.User.ChosenTarget(TrialRecord.CurrentTrialNumber) = chosen_targ;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CLEANUP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject([fixation_point chosen_targ], 'status', 'off');
idle(iti);