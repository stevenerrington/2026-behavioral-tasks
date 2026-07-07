% levertrainhold 
% Un trial = una pressione completa.
% tocco → fix spot ON → suono + hold → fix spot OFF → reward → rilascio (fine trial)
 
% Naming for TaskObjects defined in the conditions file:
start_spot = 1;
sound_a    = 2;
 
% Define Time Intervals (in ms):
hold_time      = 400;
wait_release   = 5000;
sound_duration = 300;
wait_press     = 30000;  % wait touch time and discrd trial
 
%%%%%%%%% TASK %%%%%%%%%
 
% all objcts off — spot on with touch
toggleobject(start_spot, 'status', 'off');
toggleobject(sound_a, 'status', 'off');
 
% --- STEP 1: wait hold
pressed = eyejoytrack('acquiretouch', 1, [], wait_press);
if ~pressed
    trialerror(1); % Nessuna pressione — trial scartato, MonkeyLogic passa al prossimo
    return
end
 
% --- STEP 2: spot on
toggleobject(start_spot, 'status', 'on', 'eventmarker', 120);
 
% --- STEP 3: sound ON ---
toggleobject(sound_a, 'status', 'on', 'eventmarker', 121);
 
% --- STEP 4: hold for the sound duration
[held, rt] = eyejoytrack('holdtouch', 1, [], sound_duration);
if ~held
    toggleobject(sound_a, 'status', 'off', 'eventmarker', 126);
    toggleobject(start_spot, 'status', 'off', 'eventmarker', 126);
    trialerror(2); % Relese too fast
    idle(200);
    return
end
  
% --- STEP 6: wait realese to stop the current trial
released = ~eyejoytrack('holdtouch', 1, [], wait_release);
if ~released
    toggleobject(start_spot, 'status', 'off', 'eventmarker', 124);
    trialerror(4); % %no release
    idle(200);
    return
end
% --- STEP 5
goodmonkey(500);
toggleobject(sound_a, 'status', 'off', 'eventmarker', 122);
toggleobject(start_spot, 'status', 'off', 'eventmarker', 124);
trialerror(0); % Correct
% Fine trial 