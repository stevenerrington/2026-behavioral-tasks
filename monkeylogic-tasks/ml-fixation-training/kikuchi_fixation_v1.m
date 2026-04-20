% continuous_gaze_reward.m
% MonkeyLogic 2 task:
% A white square is displayed at the centre of the screen.
% An invisible circular fixation window surrounds the square.
% While gaze is held within the window, reward is delivered continuously.
% When gaze leaves the window, reward stops.
% When gaze returns, reward resumes.
% There are no trials - this runs as a continuous loop within a single 'trial'.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
white_square   = 1;       % TaskObject # for white square (filled rect)

fix_window     = 5;       % fixation window radius (deg) — invisible circle
acquire_time   = 10000;   % ms to wait for initial gaze (large, near-infinite)
hold_check_dur = 1;      % ms per gaze-check polling interval
reward_dur     = 1000;      % ms reward pulse per polling cycle (continuous drip)
reward_pause   = 0;      % ms pause between reward pulses

max_task_dur   = 3600000; % ms total task duration before hard exit (1 hour)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         EVENT CODES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SquareOn       = 20;
GazeEnter      = 21;
GazeExit       = 22;
RewardOnset    = 31;
TaskEnd        = 40;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                         TASK SEQUENCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Display - white square - stays on for entire task
toggleobject(white_square, 'eventmarker', SquareOn);

% 2. Initiliase state tracking
gaze_inside = false; % tracks whether gaze is currently in window
elapsed     = 0;     % ms elapsed since task start;

% 3. Continuous reward loop
while elapsed < max_task_dur

    if ~gaze_inside
        % --- Gaze is OUTSIDE: wait for monkey to look at square ---
        ontarget = eyejoytrack('acquirefix', white_square, fix_window, acquire_time);

        if ontarget
            % Gaze entered window
            gaze_inside = true;
            eventmarker(GazeEnter);
        else
            % acquire_time expired but no fixation - exit gracefully
            break
        end
    else
        % --- Gaze is INSIDE: poll fixation and deliver reward ---
        ontarget = eyejoytrack('holdfix', white_square, fix_window, hold_check_dur);

        if ontarget
            % Still fixating — deliver one reward pulse
            goodmonkey(reward_dur,'eventmarker', RewardOnset);
        else
            % Gaze left the window
            gaze_inside = false;
            eventmarker(GazeExit);
        end
    end

    elapsed = elapsed + hold_check_dur;

end

% 4. Task end — turn off square
toggleobject(white_square, 'status', 'off', 'eventmarker', TaskEnd);
trialerror(0); % Mark as correct so MonkeyLogic logs it cleanly