% uhrig_local_global_task.m
% MonkeyLogic 2 task — Uhrig et al. (2014) local-global auditory paradigm
%                       with continuous pupillometry
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                   PRE-SESSION CHECKLIST
%  Action these in the MonkeyLogic GUI before every run:
%
%  [ ] 1. Block mode       : SET TO "Sequential"
%                            (GUI: Timing > Block > Sequential)
%                            WARNING: Random or Weighted mode will
%                            destroy the deviant spacing constraints
%
%  [ ] 2. Repetitions      : SET TO 1
%
%  [ ] 3. ITI              : SET TO 0 ms
%                            (GUI: Timing > ITI = 0)
%                            Trial timing is handled entirely within
%                            (GUI: Timing > Block > Repetitions = 1)
%                            this script
%
%  [ ] 4. Conditions file  : LOAD CORRECT FILE FOR THIS RUN
%                            Run A or C (HIGH repeating):
%                              conditions_RunA_highRepeat.txt
%                            Run B or D (LOW repeating):
%                              conditions_RunB_lowRepeat.txt
%
%  [ ] 5. Sound files      : CONFIRM IN TASK DIRECTORY
%                            high_50ms.wav  (1600 Hz, 70 dB, 50 ms)
%                            low_50ms.wav   ( 800 Hz, 70 dB, 50 ms)
%
%  [ ] 6. Eye calibration  : RUN BEFORE FIRST RUN OF SESSION
%
%  [ ] 7. REQUIRE_FIXATION : CHECK TOGGLE BELOW MATCHES SESSION TYPE
%                            true  = training / awake recording
%                            false = anaesthetised / passive recording
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% PRIMARY REFERENCE:
%   Uhrig L, Dehaene S, Jarraya B (2014).
%   "A hierarchy of responses to auditory regularities in the macaque brain."
%   Journal of Neuroscience, 34(4):1127-1132.
%   https://doi.org/10.1523/JNEUROSCI.3165-13.2014
%
% PARADIGM ORIGIN:
%   Bekinschtein TA, Dehaene S, Rohaut B, Tadel F, Cohen L, Naccache L (2009).
%   "Neural signature of the conscious processing of auditory regularities."
%   PNAS, 106(5):1672-1677.
%   https://doi.org/10.1073/pnas.0809667106
%
% PUPILLOMETRY REFERENCE:
%   Quirins M, Marois C, Valente M, Seassau M, Weiss N, El Karoui I,
%   Hochmann JR, Naccache L (2018).
%   "Conscious processing of auditory regularities induces a pupil dilation."
%   Scientific Reports, 8(1):14819.
%   https://doi.org/10.1038/s41598-018-33202-7
%
%   Key finding (Quirins et al., 2018): pupil dilation is selectively driven
%   by violations of GLOBAL (inter-trial) regularity — i.e. global deviants
%   (Cond 3 and 4) produce larger dilation than global standards (Cond 1 and 2).
%   LOCAL deviance alone (Cond 2) does NOT reliably drive pupil dilation.
%   Epoch window used: 0–3000 ms from first tone onset.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Paradigm overview (Uhrig et al., 2014):
%   Each trial = 5 tones (50 ms each, 150 ms SOA => 650 ms sequence total)
%   Pitches: HIGH = 1600 Hz, LOW = 800 Hz, 70 dB
%   Tones 1–4 always identical; tone 5 same (local std) or different (local dev)
%   850 ms ISI after last tone => total trial duration = 1500 ms
%
% Four conditions (2x2 factorial):
%   Cond 1 — LocalStd / GlobalStd  : xxxxX  (frequent,  no local change)
%   Cond 2 — LocalDev / GlobalStd  : xxxxY  (frequent,  local deviant)
%   Cond 3 — LocalStd / GlobalDev  : xxxxX  (rare,      no local change)
%   Cond 4 — LocalDev / GlobalDev  : xxxxY  (rare,      local deviant)
%
% Run structure:
%   4 runs (one global standard per run, counterbalanced)
%   Each run: 6 TR rest | 5 x [24 trials + 6 TR rest] | = 111 TRs = 266.4 s
%   Each 24-trial series: 4 habituation (100% std) + 20 trials (16 std / 4 dev)
%   Deviants always followed by >= 2 consecutive standards
%
% TaskObject layout (set in MonkeyLogic conditions file):
%   TaskObject#1  — fixation point
%   TaskObject#2  — tone position 1 ('x' pitch, 50 ms)
%   TaskObject#3  — tone position 2 ('x' pitch, 50 ms)
%   TaskObject#4  — tone position 3 ('x' pitch, 50 ms)
%   TaskObject#5  — tone position 4 ('x' pitch, 50 ms)
%   TaskObject#6  — tone position 5, SAME pitch  (local standard 5th tone)
%   TaskObject#7  — tone position 5, DIFF pitch  (local deviant  5th tone)
%
%   For LOW-pitch global standard runs, reassign sound files in the
%   conditions file (swap 'x'=800 Hz, 'Y'=1600 Hz). Task logic is identical.
%
% Fixation-bypass toggle (REQUIRE_FIXATION below):
%   true  — standard mode: trial aborts on fixation break (rewarded training)
%   false — free-viewing mode: fixation breaks are logged but trial continues
%           regardless; reward always given. Use for passive/anaesthetised
%           recordings, or during initial shaping when fixation is unreliable.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Fixation enforcement ---
REQUIRE_FIXATION = true;   % <<<< SET false TO BYPASS FIXATION REQUIREMENT >>>>
                            % false: trial continues on fix break; reward always given
                            % true:  trial aborts on fix break (standard training mode)

% --- TaskObject references ---
fixation_point = 1;
tone_1         = 2;
tone_2         = 3;
tone_3         = 4;
tone_4         = 5;
tone_5_std     = 6;   % same pitch as tones 1-4 (local standard)
tone_5_dev     = 7;   % different pitch         (local deviant)

% --- Fixation ---
fix_window      = 7;     % fixation window radius (deg)
fix_acquire_t   = 2000;  % max time to acquire fixation (ms)
                         % in bypass mode, gaze can be anywhere; we still
                         % show the fixation spot as a visual anchor

% --- Tone / sequence timing (Uhrig et al., 2014) ---
tone_dur        = 50;    % tone duration (ms)
soa             = 150;   % stimulus onset asynchrony (ms)
tone_gap        = soa - tone_dur;   % = 100 ms inter-tone gap
seq_dur         = 4 * soa + tone_dur;  % = 650 ms total sequence
isi_dur         = 850;   % ISI after sequence (ms)
                         % Quirins et al. (2018) epoched to 3000 ms post-onset;
                         % extend isi_dur to ~2350 ms to capture full pupil peak

% --- Reward ---
reward_dur      = 800;   % juice reward (ms)

% --- Pupillometry ---
pre_seq_baseline_dur = 300;  % ms of pre-sequence fixation used as pupil baseline
                              % (taken from end of the 500 ms pre-sequence hold)
pupil_sample_flag    = true; % save trial-level timestamps to TrialRecord.UserVars
                              % Full continuous trace always saved in BHV2 regardless

% --- Condition selection ---
cond = TrialRecord.CurrentCondition;
if cond == 2 || cond == 4
    fifth_tone = tone_5_dev;
else
    fifth_tone = tone_5_std;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FixspotOn          = 20;
NoFix              = 21;   % logged but non-aborting in bypass mode
Fixation           = 22;
FixBreak_pre       = 23;   % fixation break before sequence
FixBreak_tone1     = 24;
FixBreak_tone2     = 25;
FixBreak_tone3     = 26;
FixBreak_tone4     = 27;
AudioSeqOn         = 28;   % onset of tone 1 — t=0 for pupil epoch
AudioSeqOff        = 29;   % offset of tone 5
FixBreak_tone5     = 30;
RewardOnset        = 31;
ITIStart           = 32;
ITIEnd             = 33;
Code_LS_GS         = 41;   % cond 1: LocalStd  / GlobalStd
Code_LD_GS         = 42;   % cond 2: LocalDev  / GlobalStd
Code_LS_GD         = 43;   % cond 3: LocalStd  / GlobalDev
Code_LD_GD         = 44;   % cond 4: LocalDev  / GlobalDev
TonePos1           = 51;
TonePos2           = 52;
TonePos3           = 53;
TonePos4           = 54;
TonePos5_std       = 55;
TonePos5_dev       = 56;
PupilBaselineOn    = 60;   % start of baseline window
PupilBaselineOff   = 61;   % end of baseline / coincides with AudioSeqOn
PupilEpochOff      = 62;   % end of pupil response epoch

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             HELPER: fixation-aware holdfix
%
% In REQUIRE_FIXATION = false mode we still call eyejoytrack to preserve
% accurate timing, but we ignore the return value and never abort.
% Fix breaks are still eventmarkered for offline identification of
% contaminated epochs.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Condition identity marker ---
switch cond
    case 1,  eventmarker(Code_LS_GS);
    case 2,  eventmarker(Code_LD_GS);
    case 3,  eventmarker(Code_LS_GD);
    case 4,  eventmarker(Code_LD_GD);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         TRIAL SEQUENCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% ── 1. Show fixation point and acquire fixation ──────────────────────
toggleobject(fixation_point, 'eventmarker', FixspotOn);

ontarget = eyejoytrack('acquirefix', fixation_point, fix_window, fix_acquire_t);
if ~ontarget
    eventmarker(NoFix);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(4);   % no fixation — abort
        return
    end
    % bypass mode: log and continue — fixation spot stays on as anchor
else
    eventmarker(Fixation);
end

% ── 2. Pre-sequence hold: first portion (before baseline window) ─────
pre_baseline_hold = 500 - pre_seq_baseline_dur;  % = 200 ms

if pre_baseline_hold > 0
    ontarget = eyejoytrack('holdfix', fixation_point, fix_window, pre_baseline_hold);
    if ~ontarget
        eventmarker(FixBreak_pre);
        if REQUIRE_FIXATION
            toggleobject(fixation_point, 'status', 'off');
            trialerror(3);
            return
        end
    end
end

% ── 3. Pupil baseline window (final 300 ms before sequence) ──────────
eventmarker(PupilBaselineOn);
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, pre_seq_baseline_dur);
if ~ontarget
    eventmarker(FixBreak_pre);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(3);
        return
    end
end

if pupil_sample_flag
    TrialRecord.UserVars.pupil_baseline_t_end = trialtime();
    TrialRecord.UserVars.pupil_cond           = cond;
    TrialRecord.UserVars.fix_required         = REQUIRE_FIXATION;
end
eventmarker(PupilBaselineOff);

% ── 4. Play 5-tone sequence ───────────────────────────────────────────

% --- Tone 1 ---
toggleobject(tone_1, 'eventmarker', AudioSeqOn);
eventmarker(TonePos1);
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, tone_dur);
toggleobject(tone_1, 'status', 'off');
if ~ontarget
    eventmarker(FixBreak_tone1);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(3);
        return
    end
end
idle(tone_gap);

% --- Tone 2 ---
toggleobject(tone_2, 'eventmarker', TonePos2);
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, tone_dur);
toggleobject(tone_2, 'status', 'off');
if ~ontarget
    eventmarker(FixBreak_tone2);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(3);
        return
    end
end
idle(tone_gap);

% --- Tone 3 ---
toggleobject(tone_3, 'eventmarker', TonePos3);
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, tone_dur);
toggleobject(tone_3, 'status', 'off');
if ~ontarget
    eventmarker(FixBreak_tone3);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(3);
        return
    end
end
idle(tone_gap);

% --- Tone 4 ---
toggleobject(tone_4, 'eventmarker', TonePos4);
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, tone_dur);
toggleobject(tone_4, 'status', 'off');
if ~ontarget
    eventmarker(FixBreak_tone4);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(3);
        return
    end
end
idle(tone_gap);

% --- Tone 5 (standard or deviant) ---
if fifth_tone == tone_5_dev
    toggleobject(fifth_tone, 'eventmarker', TonePos5_dev);
else
    toggleobject(fifth_tone, 'eventmarker', TonePos5_std);
end
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, tone_dur);
toggleobject(fifth_tone, 'status', 'off', 'eventmarker', AudioSeqOff);
if ~ontarget
    eventmarker(FixBreak_tone5);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(3);
        return
    end
end

% ── 5. ISI / pupil response epoch (850 ms) ───────────────────────────
% Primary pupil response window. Quirins et al. (2018) used 0–3000 ms
% from first tone onset; to capture the full pupil peak extend isi_dur
% to ~2350 ms in PARAMETERS above (total trial = 3000 ms).
ontarget = eyejoytrack('holdfix', fixation_point, fix_window, isi_dur);
eventmarker(PupilEpochOff);
if ~ontarget
    eventmarker(FixBreak_pre);
    if REQUIRE_FIXATION
        toggleobject(fixation_point, 'status', 'off');
        trialerror(3);
        return
    end
end

if pupil_sample_flag
    TrialRecord.UserVars.pupil_epoch_t_end = trialtime();
end

% ── 6. Reward ────────────────────────────────────────────────────────
% In bypass mode reward is always delivered (trialerror = 0).
% In standard mode this line is only reached if fixation was maintained.
trialerror(0);
goodmonkey(reward_dur, 'NumReward', 1, 'PauseTime', 50, ...
    'eventmarker', RewardOnset);

% ── 7. End fixation + ITI ────────────────────────────────────────────
toggleobject(fixation_point, 'eventmarker', ITIStart);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%           OFFLINE PUPIL ANALYSIS GUIDE (comments only)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Recommended workflow using MonkeyLogic's mlread():
%
%   data = mlread('session.bhv2');
%
%   For each trial t:
%     codes    = data(t).BehavioralCodes.CodeNumbers;
%     times    = data(t).BehavioralCodes.CodeTimes;   % ms from trial start
%     eye      = data(t).EyeSignal;                   % [samples x 3]: X, Y, Pupil
%     eye_t    = data(t).EyeSignalTime;               % ms timestamps
%     cond     = data(t).Condition;
%
%     % t=0: onset of tone 1 (AudioSeqOn = 28)
%     t0       = times(codes == 28);
%
%     % Baseline: PupilBaselineOn (60) to PupilBaselineOff (61)
%     t_bsl_on  = times(codes == 60);
%     t_bsl_off = times(codes == 61);
%     bsl_idx   = eye_t >= t_bsl_on & eye_t < t_bsl_off;
%     baseline  = nanmean(eye(bsl_idx, 3));
%
%     % Response epoch: AudioSeqOn (28) to PupilEpochOff (62)
%     t_ep_off  = times(codes == 62);
%     ep_idx    = eye_t >= t0 & eye_t <= t_ep_off;
%     pupil_bc  = eye(ep_idx, 3) - baseline;   % baseline-corrected
%     pupil_t   = eye_t(ep_idx) - t0;          % ms relative to seq onset
%
%     % Flag trials with fixation breaks for exclusion (if bypass mode used)
%     fix_break_codes = [23 24 25 26 27 30];
%     had_fix_break   = any(ismember(codes, fix_break_codes));
%
%   Average pupil_bc by condition (1–4):
%     Cond 1: LocalStd  / GlobalStd  — baseline (no surprise)
%     Cond 2: LocalDev  / GlobalStd  — local deviant only
%     Cond 3: LocalStd  / GlobalDev  — global deviant only
%     Cond 4: LocalDev  / GlobalDev  — both deviants
%
%   Key contrasts (Quirins et al., 2018):
%     Global effect : (Cond3 + Cond4) - (Cond1 + Cond2)   <- main pupil effect
%     Local effect  : (Cond2 + Cond4) - (Cond1 + Cond3)   <- typically absent
%     Interaction   : (Cond4 - Cond3) - (Cond2 - Cond1)
%
%   Preprocessing steps:
%     1. Detect and interpolate blinks (pupil = 0 or sudden drop > threshold)
%        Quirins et al.: blink = successive difference > 200 pixels
%     2. Low-pass filter at 4 Hz (pupil dynamics are slow)
%     3. Reject trials with > 30% blink contamination during epoch
%     4. Normalise: % change from baseline, or z-score across session
%     5. In bypass mode: optionally exclude fix-break trials from fMRI
%        analysis while retaining them for pupil analysis
%
