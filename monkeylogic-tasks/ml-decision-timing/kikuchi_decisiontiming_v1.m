% temporal_task.m
% =========================================================================
% Temporal Decision-Making Task — MonkeyLogic 2 Timing Script
% =========================================================================
%
% Design:
%   - Monkey fixates a white spot to initiate trial
%   - After 500–1500 ms fixation, spot turns green (cue: sequence incoming)
%   - 500 ms later, pre-generated beep-train WAV plays
%   - Monkey presses the response button when it thinks the train has ended
%   - Catch trials: a high-pitched tone plays at sequence offset
%   - Commitment timing relative to sequence offset is the primary DV
%   - Implicit ITI feedback: shorter ITI for accurate post-offset responses
%
% Orthogonal manipulations (encoded in conditions file):
%   1. ISI predictability  (0, 0.25, 0.5, 0.75, 1.0)
%   2. Block duration prior (short / medium / long)
%
% TaskObjects (defined in conditions file, referenced by index here):
%   1  — fixation spot (white, small)
%   2  — fixation spot green (cue that sequence is starting)
%   3  — beep-train WAV  (trial-unique, pre-generated)
%   4  — catch WAV       (high-pitched tone)
%   5  — catch flash (yellow triangle bitmap, shown with catch tone)
%
% Behavioural codes  (sent to event log):
%   10 — trial start
%   20 — fixation acquired
%   21 — fixation cue onset (green fix spot)
%   30 — beep train onset
%   31 — beep train offset
%   40 — response (button press)
%   41 — premature response
%   50 — catch tone onset
%   51 — catch detected
%   60 — trial end (correct)
%   61 — trial end (no response)
%   62 — trial end (premature)
%   70 — abort (fixation break)
%
% Author : Steven Errington  (adapted from PsychoPy version)
% Date   : 2026
% =========================================================================

% ---- Retrieve trial-level parameters from conditions file ---------------
% These variables are injected by ML2 from the conditions file columns.
%
%   BLOCK_NAME       — char: 'short' | 'medium' | 'long'
%   MEAN_DUR         — float: mean sequence duration (s)
%   PREDICTABILITY   — float: 0 | 0.25 | 0.5 | 0.75 | 1.0
%   IS_CATCH         — int:   0 | 1
%   BEEP_WAV_INDEX   — int:   index into the WAV file list (1-based)
%   ACTUAL_SEQ_DUR   — float: actual duration of this trial's beep train (s)
%   N_BEEPS          — int:   number of beeps in this trial's sequence
%   ISIS_MEAN        — float: mean ISI for this trial
%   ISIS_STD         — float: std of ISIs for this trial
%   PRACTICE         — int:   0 | 1

% ---- Timing constants ---------------------------------------------------
FIXATION_HOLD_MIN  = 500;    % ms — minimum fixation before cue
FIXATION_HOLD_MAX  = 1500;   % ms — maximum fixation before cue
CUE_TO_BEEP_DELAY  = 500;    % ms — green fix → beep train onset
RESPONSE_WINDOW    = 3000;   % ms — post-offset response window
CATCH_WINDOW       = 800;    % ms — window to respond to catch tone
FIX_RADIUS         = 3;      % dva — fixation window radius
ACCURATE_THRESHOLD = 500;    % ms — post-offset commits within this get ITI bonus

% ITI implicit feedback (ms)
ITI_BASE          = 1000;
ITI_ACCURATE_BONUS = -300;   % subtracted for accurate commits
ITI_EARLY_PENALTY  =  600;   % added for premature commits
ITI_MIN           =  400;    % hard floor

% Button assignment
RESPONSE_BUTTON = 1;         % ML2 button index for the response key

% =========================================================================
% SCENE 1: Fixation acquisition
% =========================================================================
% Show white fixation spot; wait for monkey to acquire fixation.
% If fixation not acquired within 5 s, abort trial.

eventmarker(10);   % trial start

fix_white = SingleTarget(eye_);
fix_white.Target   = 1;          % TaskObject #1 = white fix spot
fix_white.Threshold = FIX_RADIUS;

scene_fix = create_scene(fix_white, 1);   % TaskObject 1 drawn
outcome = run_scene(scene_fix, 5000);     % 5 s acquisition timeout

if ~outcome
    % Fixation not acquired — abort
    eventmarker(70);
    idle(500);
    trialerror(4);   % ML2 code 4 = no fixation
    return
end

eventmarker(20);   % fixation acquired

% =========================================================================
% SCENE 2: Fixation hold (variable, 500–1500 ms)
% =========================================================================
% Monkey must hold fixation for a randomly drawn interval.
% If fixation breaks, abort.

hold_dur = FIXATION_HOLD_MIN + randi(FIXATION_HOLD_MAX - FIXATION_HOLD_MIN + 1) - 1;

fix_hold = SingleTarget(eye_);
fix_hold.Target    = 1;
fix_hold.Threshold = FIX_RADIUS;

% WaitThenHold: already fixating, must stay for hold_dur ms
wth = WaitThenHold(fix_hold);
wth.HoldTime = hold_dur;

scene_hold = create_scene(wth, 1);
outcome = run_scene(scene_hold);

if ~outcome
    eventmarker(70);
    idle(500);
    trialerror(3);   % break fixation
    return
end

% =========================================================================
% SCENE 3: Cue — green fixation spot (500 ms)
% =========================================================================
% Switch fix spot to green; monkey must maintain fixation.

eventmarker(21);   % cue onset

fix_hold_cue = SingleTarget(eye_);
fix_hold_cue.Target    = 2;          % TaskObject #2 = green fix spot
fix_hold_cue.Threshold = FIX_RADIUS;

wth_cue = WaitThenHold(fix_hold_cue);
wth_cue.HoldTime = CUE_TO_BEEP_DELAY;

scene_cue = create_scene(wth_cue, 2);
outcome = run_scene(scene_cue);

if ~outcome
    eventmarker(70);
    idle(500);
    trialerror(3);
    return
end

% =========================================================================
% SCENE 4: Beep train + response monitoring
% =========================================================================
% Play the pre-generated WAV (TaskObject #3).
% Monitor the response button throughout.
% Sequence plays to completion regardless of premature press.
%
% ML2 approach:
%   - Sound is loaded as a TaskObject and triggered at scene start.
%   - We poll the button in real time.
%   - ACTUAL_SEQ_DUR (from conditions file) tells us when the sequence ends.
%   - We run two back-to-back scenes: one for the sequence duration,
%     one for the post-offset response window, so we can cleanly separate
%     premature from post-offset responses.

eventmarker(30);   % beep train onset

% -- Scene 4a: Sequence period --
% Fix spot returns to white during playback (green was just the cue).
% Monkey is free to respond (we record premature presses).

seq_duration_ms = round(ACTUAL_SEQ_DUR * 1000);

% Response button tracker
btn = ButtonTracker(joy_);       % joy_ = ML2 button input object
btn.Button = RESPONSE_BUTTON;

% We want the scene to run for exactly seq_duration_ms.
% Use a TimeCounter to enforce duration.
tc_seq = TimeCounter(null_);
tc_seq.Duration = seq_duration_ms;

scene_seq = create_scene(tc_seq, [1, 3]);   % draw fix #1, play sound #3
outcome_seq = run_scene(scene_seq);

% Check whether a button press occurred during the sequence
premature       = 0;
response_made   = 0;
commit_time_ms  = NaN;   % ms from beep train onset

% ML2 stores button-press times in the reactiontime variable after run_scene.
% We read the button log via getkeypress or the scene output.
% Use ontarget() or the ButtonTracker output to detect press timing.
btn_log = btn.Time;   % times (ms, scene-relative) of button presses

if ~isempty(btn_log)
    premature      = 1;
    response_made  = 1;
    commit_time_ms = btn_log(1);   % first press, scene-relative ms
    eventmarker(41);               % premature response
end

eventmarker(31);   % beep train offset

% =========================================================================
% SCENE 5: Post-offset response window (if not yet committed)
% =========================================================================

commit_time_from_offset_ms = NaN;

if ~premature
    % Reset button tracker for post-offset window
    btn2 = ButtonTracker(joy_);
    btn2.Button = RESPONSE_BUTTON;

    tc_post = TimeCounter(null_);
    tc_post.Duration = RESPONSE_WINDOW;

    % Switch fix spot to white (no sound TaskObject needed)
    scene_post = create_scene(tc_post, 1);
    run_scene(scene_post);

    btn2_log = btn2.Time;

    if ~isempty(btn2_log)
        response_made              = 1;
        commit_time_from_offset_ms = btn2_log(1);
        commit_time_ms             = seq_duration_ms + btn2_log(1);
        eventmarker(40);           % response
    end
end

if premature
    commit_time_from_offset_ms = commit_time_ms - seq_duration_ms;   % negative
end

% =========================================================================
% SCENE 6: Catch trial (if IS_CATCH == 1)
% =========================================================================

catch_detected = NaN;
catch_rt_ms    = NaN;

if IS_CATCH
    if premature
        % Already committed — cannot respond to catch
        catch_detected = 0;
        eventmarker(50);   % catch onset (even though missed by design)

        % Play catch tone anyway (trial integrity), no flash needed
        tc_catch = TimeCounter(null_);
        tc_catch.Duration = CATCH_WINDOW;
        scene_catch = create_scene(tc_catch, 4);   % TaskObject #4 = catch WAV
        run_scene(scene_catch);
    else
        eventmarker(50);   % catch tone onset

        btn3 = ButtonTracker(joy_);
        btn3.Button = RESPONSE_BUTTON;

        tc_catch = TimeCounter(null_);
        tc_catch.Duration = CATCH_WINDOW;

        % Show catch flash (TaskObject #5) + play catch WAV (#4)
        scene_catch = create_scene(tc_catch, [4, 5]);
        run_scene(scene_catch);

        btn3_log = btn3.Time;

        if ~isempty(btn3_log)
            catch_detected = 1;
            catch_rt_ms    = btn3_log(1);
            eventmarker(51);   % catch detected
        else
            catch_detected = 0;
        end
    end
end

% =========================================================================
% ITI — implicit feedback
% =========================================================================

if premature
    iti_ms = ITI_BASE + ITI_EARLY_PENALTY;
elseif ~response_made
    iti_ms = ITI_BASE + ITI_EARLY_PENALTY;   % no response = same as premature
elseif ~isnan(commit_time_from_offset_ms) && ...
       commit_time_from_offset_ms >= 0 && ...
       commit_time_from_offset_ms <= ACCURATE_THRESHOLD
    iti_ms = max(ITI_MIN, ITI_BASE + ITI_ACCURATE_BONUS);
else
    late_penalty = min(600 * ((commit_time_from_offset_ms - ACCURATE_THRESHOLD) / 1000), 1500);
    iti_ms = ITI_BASE + late_penalty;
end

idle(round(iti_ms));   % blank screen ITI (no fix spot)

% =========================================================================
% Set ML2 trial outcome
% =========================================================================

if premature
    eventmarker(62);
    trialerror(6);   % early response
elseif ~response_made
    eventmarker(61);
    trialerror(1);   % no response
else
    eventmarker(60);
    trialerror(0);   % correct
end

% =========================================================================
% Write behavioural data to TrialRecord
% =========================================================================
% ML2 stores custom trial data in TrialRecord.User (a struct).
% These are saved to the .bhv2 file and readable with mlread().

TrialRecord.User.block_name                  = BLOCK_NAME;
TrialRecord.User.mean_dur                    = MEAN_DUR;
TrialRecord.User.predictability              = PREDICTABILITY;
TrialRecord.User.is_catch                    = IS_CATCH;
TrialRecord.User.n_beeps                     = N_BEEPS;
TrialRecord.User.actual_seq_dur              = ACTUAL_SEQ_DUR;
TrialRecord.User.isis_mean                   = ISIS_MEAN;
TrialRecord.User.isis_std                    = ISIS_STD;
TrialRecord.User.premature                   = premature;
TrialRecord.User.response_made               = response_made;
TrialRecord.User.commit_time_from_onset_ms   = commit_time_ms;
TrialRecord.User.commit_time_from_offset_ms  = commit_time_from_offset_ms;
TrialRecord.User.catch_detected              = catch_detected;
TrialRecord.User.catch_rt_ms                 = catch_rt_ms;
TrialRecord.User.iti_ms                      = iti_ms;
TrialRecord.User.practice                    = PRACTICE;
TrialRecord.User.beep_wav_index              = BEEP_WAV_INDEX;
