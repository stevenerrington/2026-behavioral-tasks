% kikuchi_fixation_v2.m
% MonkeyLogic 2 task:
% A white square ("attractor", TaskObject#1) is briefly blinked, then held on,
% at a position set by the conditions file (kikuchi_fixation_v2_conditions.txt).
% While gaze is held within an invisible circular fixation window around it,
% reward is delivered continuously (as in v1). Once fixation is acquired, the
% attractor is replaced by a trial-specific target (TaskObject#2) at the same
% position - either a coloured square or a fractal image, again set by the
% conditions file.
%
% Unlike v1, this is now a single DISCRETE TRIAL rather than one long
% continuous loop. Each trial ends after either:
%   - fixation was never (re)acquired within acquire_time, or
%   - continuous fixation reward has accumulated for max_hold_dur, or
%   - the trial has run for max_trial_dur regardless of outcome.
% trialerror is always set to 0 (correct) so that no trial is penalised or
% auto-repeated - the point at this stage is reward delivery, not scoring.
%
% IMPORTANT - set on the MonkeyLogic main menu:
%   Task submenu -> Blocks pane -> select the block, set trial selection to
%   "Random" with "no immediate repeat" (or similar), and set the block/task
%   to repeat indefinitely (a large trial count or "infinite"). This is what
%   makes the target relocate to a new position/stimulus every trial - the
%   position and image are entirely determined by which condition the menu
%   picks next, not by this script.
%
% version 1: 2026-04-30 - continuous_gaze_reward.m (single continuous loop,
%                         fixed centre position, colour change on fixation)
% version 2: 2026-07-22 - restructured as a discrete, self-repeating trial;
%                         target position now varies across a 3x3 grid
%                         (~8 deg eccentricity) via the conditions file, so
%                         reward is associated with the OBJECT rather than a
%                         fixed screen location; added 6 fractal-image
%                         target options alongside the original 6 coloured
%                         squares; added a brief pre-trial attention "blink"
%                         since the target is not always at screen centre.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
white_square   = 1;       % TaskObject# for white attractor square
target_stim    = 2;       % TaskObject# for trial-specific colour/fractal target
fix_window     = 9;       % fixation window radius (deg) - invisible circle
acquire_time   = 10000;   % ms to wait for gaze to (re)land on the object
hold_check_dur = 100;     % ms per gaze-check polling interval
reward_dur     = 5000;    % ms reward pulse per polling cycle (continuous drip)
max_hold_dur   = 8000;    % ms of *cumulative* rewarded fixation before ending the trial
max_trial_dur  = 30000;   % ms hard cap on total trial length (safety backstop)
n_blinks       = 3;       % attention-grabbing blinks of the attractor before acquisition
blink_on_dur   = 150;     % ms each blink stays on
blink_off_dur  = 150;     % ms each blink stays off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SquareOn       = 20;
SquareOff      = 21;
GazeEnter      = 22;
GazeExit       = 23;
RewardOnset    = 31;
TrialEnd       = 40;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         TASK SEQUENCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 0. Hotkey escape
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% 1. Attention-grab: blink the attractor a few times at this trial's
%    position before asking for fixation, since the target is not always
%    at the centre of the screen any more.
for b = 1:n_blinks
    toggleobject(white_square, 'status', 'on', 'eventmarker', SquareOn);
    idle(blink_on_dur);
    toggleobject(white_square, 'status', 'off', 'eventmarker', SquareOff);
    idle(blink_off_dur);
end
toggleobject(white_square, 'status', 'on', 'eventmarker', SquareOn);

% 2. Initialise state tracking
elapsed      = 0;     % ms elapsed in this trial
hold_elapsed = 0;     % ms of cumulative rewarded fixation this trial
gaze_inside  = false;

% 3. Continuous reward loop, bounded to this trial
while elapsed < max_trial_dur && hold_elapsed < max_hold_dur

    if ~gaze_inside

        % --- Gaze is OUTSIDE: wait for the monkey to look at the attractor ---
        ontarget = eyejoytrack('acquirefix', white_square, fix_window, acquire_time);

        if ontarget
            % Gaze entered window - swap attractor for the trial's target stimulus
            gaze_inside = true;
            eventmarker(GazeEnter);
            toggleobject(white_square, 'status', 'off', 'eventmarker', SquareOff);
            toggleobject(target_stim, 'status', 'on', 'eventmarker', SquareOn);
        else
            % acquire_time expired with no fixation - give up on this trial
            break
        end

    else

        % --- Gaze is INSIDE: poll fixation and deliver reward ---
        ontarget = eyejoytrack('holdfix', target_stim, fix_window, hold_check_dur);

        if ontarget
            % Still fixating - deliver one reward pulse
            goodmonkey(reward_dur, 'eventmarker', RewardOnset);
            hold_elapsed = hold_elapsed + hold_check_dur;
        else
            % Gaze left the window - bring the attractor back and try to
            % re-acquire at the same position for the rest of the trial
            gaze_inside = false;
            eventmarker(GazeExit);
            toggleobject(target_stim, 'status', 'off', 'eventmarker', SquareOff);
            toggleobject(white_square, 'status', 'on', 'eventmarker', SquareOn);
        end
    end

    elapsed = elapsed + hold_check_dur;
end

% 4. Trial end - turn everything off
toggleobject([white_square target_stim], 'status', 'off', 'eventmarker', TrialEnd);
trialerror(0); % Mark as correct so MonkeyLogic logs it cleanly and advances to the next (repositioned) trial
