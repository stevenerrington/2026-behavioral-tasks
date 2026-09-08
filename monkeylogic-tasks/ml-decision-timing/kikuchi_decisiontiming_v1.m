%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Temporal Decision-Making Task — Saccade-Response Version
%   MonkeyLogic 2 Timing Script
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Design:
%   - Monkey fixates a central white spot
%   - After a variable 500-1500 ms hold, a peripheral target appears
%     (7 dva up). Monkey must keep fixating centrally for a further
%     fixed 500 ms while the target is visible but not yet actionable.
%   - The beep-train WAV then plays. From this moment, the monkey is
%     free to saccade to the target at any time.
%       - Saccade BEFORE the train ends  -> early response (error, no reward)
%       - Saccade AFTER  the train ends  -> correct response
%       - No saccade to target within the allowed time -> fixation error
%   - On a correct response, reward is delivered 500 ms after the
%     saccade is registered (not immediately).
%
% Orthogonal manipulations (encoded in conditions file Info column):
%   1. ISI predictability   (0, 0.25, 0.5, 0.75, 1.0)
%   2. Block duration prior (short / medium / long)
%
% TaskObjects (defined in conditions file, referenced by index here):
%   1  — fixation spot (white, center)
%   2  — saccade target (green square, 7 dva up)
%   3  — beep-train WAV (trial-unique, pre-generated)
%
% Trial variables are passed via the reserved "Info" column of the
% conditions file (the only ML2-valid way to carry custom per-trial
% variables — named columns like "BLOCK_NAME" are NOT valid conditions
% file headers). ML2 auto-parses Info into a struct available here as
% "Info", so trial variables are read as Info.block_name, Info.mean_dur,
% etc. (see generate_stimuli.py for how the Info column is built).
%
% Behavioural codes (event markers):
%   10 — trial start
%   20 — fixation acquired
%   21 — target onset
%   30 — beep train onset
%   40 — saccade acquired, correct (post-offset)
%   41 — saccade acquired, early (pre-offset)
%   42 — failure to attain target (timeout)
%   50 — reward delivered
%
% Author : Steven Errington
% Date   : 2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TASK OBJECTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fixation_point  = 1;   % white fixation spot (center)
target_obj      = 2;   % saccade target (green square, 7 dva up)
beep_train      = 3;   % trial-unique beep-train WAV

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fix_window          = 3;     % dva — fixation window radius
targ_window          = 5;     % dva — target window radius

fix_acquire          = 5000;  % ms — time allowed to acquire fixation
hold_dist            = linspace(500, 1500, 100);
fix_hold             = hold_dist(randperm(length(hold_dist), 1));  % ms — variable foreperiod

target_to_sound_delay = 500;  % ms — target visible, fixation must be held, before sound starts
response_timeout_extra = 2500; % ms — extra time allowed after train end before timing out

reward_delay_ms      = 1000;   % ms — delay between correct saccade and reward delivery
reward_duration      = 1000;   % ms — juice reward duration
iti                  = 1000;  % ms — inter-trial interval

seq_duration_ms      = get_object_duration(beep_train);   % from conditions file Info
total_watch_ms        = seq_duration_ms + response_timeout_extra;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

TrialStart   = 10;
FixAcq       = 20;
TargOn       = 21;
TrainOn      = 30;
SaccCorrect  = 40;
SaccEarly    = 41;
NoTarget     = 42;
RewardOn     = 50;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 1: FIXATION ACQUISITION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

eventmarker(TrialStart);

toggleobject(fixation_point, 'eventmarker', FixAcq);

ontarget = eyejoytrack('acquirefix', fixation_point, fix_window, fix_acquire);
if ~ontarget
    trialerror(4); % no fixation
    toggleobject(fixation_point, 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 2: VARIABLE FIXATION HOLD (foreperiod)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, fix_hold);
if ~ontarget
    trialerror(3); % broke fixation during foreperiod
    toggleobject(fixation_point, 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 3: TARGET ONSET — target visible but not yet actionable.
% Monkey must continue holding central fixation for a fixed period
% before the sound (and the response window) begins.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(target_obj, 'eventmarker', TargOn);   % target on; fixation_point stays on

ontarget = eyejoytrack('holdfix', fixation_point, fix_window, target_to_sound_delay);
if ~ontarget
    trialerror(3); % broke fixation before sound started
    toggleobject([fixation_point target_obj], 'status', 'off');
    idle(iti);
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EPOCH 4: BEEP TRAIN + SACCADE MONITORING
% From sound onset, the monkey may saccade to the target at any time.
% One continuous acquirefix call watches for that saccade across the
% full sound duration plus a grace period after it ends. RT is read
% directly from eyejoytrack (time from sound onset to acquisition) and
% classified relative to true train offset (seq_duration_ms).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

toggleobject(beep_train, 'eventmarker', TrainOn);  % beep on; fixation_point & target_obj stay on

[ontarget, rt] = eyejoytrack('acquirefix', target_obj, targ_window, total_watch_ms);

toggleobject(beep_train, 'status', 'off');   % ensure sound object off (playback will have finished by now)

response_made    = ontarget;
rt_from_onset_ms = NaN;
rt_from_offset_ms = NaN;
rewarded          = 0;

if ~ontarget
    % Never reached the target in time
    eventmarker(NoTarget);
    trialerror(4); % failure to attain target
    toggleobject([fixation_point target_obj], 'status', 'off');
    idle(iti);

else
    rt_from_onset_ms  = rt;
    rt_from_offset_ms = rt - seq_duration_ms;

    rt = rt_from_offset_ms;
    if rt_from_offset_ms < 0
        % Saccade landed before the train ended -> early response
        eventmarker(SaccEarly);
        trialerror(6); % early
        toggleobject([fixation_point target_obj], 'status', 'off');
        idle(iti);

    else
        % Saccade landed after the train ended -> correct
        eventmarker(SaccCorrect);
        idle(reward_delay_ms);   % reward is delivered 500 ms after the response, not immediately

        rewarded = 1;
        goodmonkey(reward_duration, 'NumReward', 1, 'PauseTime', 50, ...
            'eventmarker', RewardOn);
        toggleobject([fixation_point target_obj], 'status', 'off');
        trialerror(0); % correct
        idle(iti);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Write behavioural data to TrialRecord
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

TrialRecord.User.block_name        = Info.block_name;
TrialRecord.User.mean_dur          = Info.mean_dur;
TrialRecord.User.predictability    = Info.predictability;
TrialRecord.User.actual_seq_dur    = Info.actual_seq_dur;
TrialRecord.User.n_beeps           = Info.n_beeps;
TrialRecord.User.isis_mean         = Info.isis_mean;
TrialRecord.User.isis_std          = Info.isis_std;
TrialRecord.User.practice          = Info.practice;
TrialRecord.User.fix_hold_ms       = fix_hold;
TrialRecord.User.response_made     = response_made;
TrialRecord.User.rt_from_onset_ms  = rt_from_onset_ms;
TrialRecord.User.rt_from_offset_ms = rt_from_offset_ms;
TrialRecord.User.rewarded          = rewarded;