%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                L-CAPT: Latent Context Auditory Prediction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fixation_point = 1;
context_audio = 2;
toneA_audio = 3;
toneB_audio = 4;

l_targ = 5;
r_targ = 6;

fix_window = 2;
choice_window = 3;

fix_hold = 500;
context_duration = 400;
tone_duration = 100;

delay_duration = randi([500 1000]); % WM delay

choice_time_limit = 1000;

RT_fast = 250;
RT_med  = 500;

reward_dur = 0;
reward_large = 300;
reward_medium = 200;
reward_small = 100;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FixOn = 10;
ContextOn = 20;
DelayOn = 30;
ToneNOn = 40;
ChoiceOn = 50;
OutcomeOn = 60;
RewardOn = 70;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 1: FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(fixation_point,'eventmarker',FixOn);

ontarget = eyejoytrack('acquirefix', fixation_point, fix_window, 2000);
if ~ontarget
    trialerror(4); % no fixation
    return
end

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, fix_hold);
if ~ontarget
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 2: CONTEXT CUE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(context_audio,'eventmarker',ContextOn);

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, context_duration);
toggleobject(context_audio,'status','off');

if ~ontarget
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 3: WORKING MEMORY DELAY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

eventmarker(DelayOn);

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, delay_duration);
if ~ontarget
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 4: TONE N
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


toggleobject(toneA_audio,'eventmarker',ToneNOn);
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, tone_duration);
toggleobject(toneA_audio,'status','off');

if ~ontarget
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 5: CHOICE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject([l_targ r_targ],'eventmarker',ChoiceOn);

rt = 0;
choice = 0;

[touch, rt] = eyejoytrack('acquirefix', [l_targ r_targ], choice_window, choice_time_limit);

if ~touch
    trialerror(2); % no response
    toggleobject([l_targ r_targ],'status','off');
    return
end

if touch == 1
    choice = 1; % predicted Tone 1
else
    choice = 2; % predicted Tone 2
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 6: OUTCOME (S_{n+1})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
idle(2000)
toggleobject(toneB_audio,'eventmarker',OutcomeOn);
idle(tone_duration);
toggleobject(toneB_audio,'status','off');
toggleobject([l_targ r_targ],'status','off');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% REWARD LOGIC
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if rt < RT_fast
    reward_dur = reward_large;
elseif rt < RT_med
    reward_dur = reward_medium;
else
    reward_dur = reward_small;
end

goodmonkey(reward_dur,'eventmarker',RewardOn);
% 
% 
% if choice == S_next
%     trialerror(0); % correct
% 
% else
%     trialerror(6); % incorrect
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CLEANUP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(fixation_point,'status','off');
idle(1000);
