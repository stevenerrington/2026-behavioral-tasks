%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% auditory_oddball_saccade.m
%
% Condition 1 : Standard
%     Hold fixation throughout the sound.
%
% Condition 2 : Oddball
%     Hold fixation until the oddball (last 50 ms of sound),
%     then saccade to the peripheral target.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TASK OBJECTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fixation_point = 1;
auditory_stim  = 2;
target         = 3;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fix_window      = 5;      % deg

fix_hold_pre    = 500;    % before target
target_delay    = 500;    % target before sound

response_window = 1500;    % ms allowed to initiate saccade
target_hold     = 200;    % hold target fixation

reward_duration = 800;
reward_prob     = 1.00;

sound_duration  = get_object_duration(auditory_stim);
oddball_time    = sound_duration - 50;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FixspotOn   = 20;
NoFix       = 21;
Fixation    = 22;
FixBreak1   = 23;
FixBreak2   = 24;
FixBreak3   = 25;

TargetOn    = 26;

AudioOn     = 28;
AudioOff    = 29;

RewardOnset = 31;
ITIStart    = 32;
ITIEnd      = 33;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TRIAL TYPE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

is_oddball = (TrialRecord.CurrentCondition == 3 |...
    TrialRecord.CurrentCondition == 4 |...
    TrialRecord.CurrentCondition == 6 |...
    TrialRecord.CurrentCondition == 9 |...
    TrialRecord.CurrentCondition == 12);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1. SHOW FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(fixation_point,'eventmarker',FixspotOn);

ontarget = eyejoytrack('acquirefix',fixation_point,fix_window,2000);

if ~ontarget
    toggleobject(fixation_point,'status','off');
    eventmarker(NoFix);
    trialerror(4);
    return
end

eventmarker(Fixation);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2. HOLD FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ontarget = eyejoytrack('holdfix',fixation_point,fix_window,fix_hold_pre);

if ~ontarget
    toggleobject(fixation_point,'status','off');
    eventmarker(FixBreak1);
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3. SHOW TARGET
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(target,'eventmarker',TargetOn);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 4. HOLD FIXATION WITH TARGET PRESENT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ontarget = eyejoytrack('holdfix',fixation_point,fix_window,target_delay);

if ~ontarget
    toggleobject([fixation_point target],'status','off');
    eventmarker(FixBreak2);
    trialerror(3);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 5. PLAY SOUND
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
oddball_trial_time = trialtime + 1000;

toggleobject(auditory_stim,'eventmarker',AudioOn);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STANDARD TRIAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~is_oddball

    ontarget = eyejoytrack('holdfix', ...
        fixation_point, fix_window, sound_duration);

    toggleobject(auditory_stim,'status','off','eventmarker',AudioOff);

    if ~ontarget
        toggleobject([fixation_point target],'status','off');
        eventmarker(FixBreak3);
        trialerror(5);
        return
    end

    idle(500)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ODDBALL TRIAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

else

    % Hold fixation until oddball onset
    ontarget = eyejoytrack('holdfix', ...
        fixation_point, fix_window, oddball_time);

    if ~ontarget
        toggleobject(auditory_stim,'status','off','eventmarker',AudioOff);
        toggleobject([fixation_point target],'status','off');
        eventmarker(FixBreak3);
        trialerror(5);
        return
    end

    % Allow saccade to target
    acquired = eyejoytrack('acquirefix', ...
        target, fix_window, response_window);
    acq_time = trialtime;

    rt = acq_time - oddball_trial_time;
    
    if ~acquired
        toggleobject(auditory_stim,'status','off','eventmarker',AudioOff);
        toggleobject([fixation_point target],'status','off');
        trialerror(6);      % no response
        return
    end

    % Hold fixation on target
    held = eyejoytrack('holdfix', ...
        target, fix_window, target_hold);

    toggleobject(auditory_stim,'status','off','eventmarker',AudioOff);

    if ~held
        toggleobject([fixation_point target],'status','off');
        trialerror(5);
        return
    end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CORRECT TRIAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

trialerror(0);

if rand <= reward_prob
    goodmonkey(reward_duration,...
        'NumReward',1,...
        'PauseTime',50,...
        'eventmarker',RewardOnset);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CLEAN UP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject([fixation_point target],'status','off','eventmarker',ITIStart);

idle(500);

eventmarker(ITIEnd);