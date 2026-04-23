import scipy.io as sio
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# Load the converted .mat file
mat = sio.loadmat('/Users/benslates/Documents/MATLAB/260415_chief_kikuchi_localglobal_v1_conditions.mat', simplify_cells=True)

# Top-level keys
print(mat.keys())
# Typically: 'MLConfig', 'TrialRecord', and a trial data array

# Collect all trials into a list
num_trials = len([k for k in mat.keys() if k.startswith('Trial') and k != 'TrialRecord'])

data = [mat[f'Trial{i+1}'] for i in range(num_trials)]

# Inspect the fields available in a single trial
print(data[0].keys())

mlconfig = mat['MLConfig']  # session configuration

# Each trial is a dict-like struct. Common fields:
trial = data[0]             # first trial

print(trial.keys())
# Typical fields:
#   'EyeSignal'       — Nx2 array of (x, y) gaze in degrees, sampled at 1 kHz
#   'BehavioralCodes' — dict with 'CodeTimes' and 'CodeNumbers'
#   'ReactionTime'    — ms
#   'TrialError'      — 0 = correct, 4 = no fixation, etc.
#   'AbsoluteTrialStartTime'


# ── Extract pupil size per trial ──────────────────────────────
def get_pupil(trial):
    """
    EyeExtra is Nx2 — columns are pupil width and height.
    We take the mean of both as an estimate of pupil size.
    """
    pupil = trial['AnalogData']['EyeExtra']   # Nx2
    if pupil.size == 0:
        return None
    pupil_size = np.mean(pupil, axis=1)       # average width & height
    return pupil_size

# ── Collect per-trial mean pupil size ─────────────────────────
trial_means  = []
trial_nums   = []

for t, trial in enumerate(data):
    pupil = get_pupil(trial)
    if pupil is not None and len(pupil) > 0:
        trial_means.append(np.mean(pupil))
        trial_nums.append(t + 1)

trial_means = np.array(trial_means)
trial_nums  = np.array(trial_nums)

# ── Plot 1: Mean pupil size per trial ─────────────────────────
fig, ax = plt.subplots(figsize=(12, 4))
ax.plot(trial_nums, trial_means, lw=1.5, color='steelblue', marker='o',
        markersize=3, label='Mean pupil size')

# Rolling average (window = 10 trials)
window = 10
rolling = np.convolve(trial_means, np.ones(window)/window, mode='valid')
rolling_x = trial_nums[window-1:]
ax.plot(rolling_x, rolling, lw=2.5, color='tomato', label=f'{window}-trial rolling mean')

ax.set_xlabel('Trial number')
ax.set_ylabel('Pupil size (a.u.)')
ax.set_title('Pupil size across trials')
ax.legend()
ax.spines[['top', 'right']].set_visible(False)
plt.tight_layout()
plt.show()

# ── Plot 2: Full pupil trace heatmap (time x trial) ───────────
# Trim all trials to the shortest length so they can be stacked
traces = []
for trial in data:
    pupil = get_pupil(trial)
    if pupil is not None and len(pupil) > 0:
        traces.append(pupil)

min_len = min(len(t) for t in traces)
pupil_matrix = np.array([t[:min_len] for t in traces])  # shape: (n_trials, time)

fig, ax = plt.subplots(figsize=(12, 6))
im = ax.imshow(pupil_matrix, aspect='auto', origin='lower',
               cmap='viridis',
               extent=[0, min_len, 1, len(traces)])
ax.set_xlabel('Time within trial (ms)')
ax.set_ylabel('Trial number')
ax.set_title('Pupil size over time — all trials')
plt.colorbar(im, ax=ax, label='Pupil size (a.u.)')
plt.tight_layout()
plt.show()

import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import uniform_filter1d

# ── Parameters ────────────────────────────────────────────────
BASELINE_START_MS = 0      # ms — start of baseline window
BASELINE_END_MS   = 200    # ms — end of baseline window
SMOOTH_WINDOW_MS  = 20     # ms — smoothing kernel

# ── Extract and baseline-correct pupil traces ─────────────────
def get_pupil_trace(trial):
    """Return mean pupil size (width+height averaged) as 1D array."""
    pupil = trial['AnalogData']['EyeExtra']
    if pupil.size == 0 or pupil.ndim < 2:
        return None
    return np.mean(pupil, axis=1)   # Nx2 -> N

def baseline_correct(trace, baseline_start=BASELINE_START_MS,
                     baseline_end=BASELINE_END_MS):
    """Subtract mean of baseline window from entire trace."""
    baseline = np.mean(trace[baseline_start:baseline_end])
    return trace - baseline

# ── Collect traces ────────────────────────────────────────────
traces = []
for trial in data:
    p = get_pupil_trace(trial)
    if p is not None and len(p) > BASELINE_END_MS:
        traces.append(baseline_correct(p))

if not traces:
    raise ValueError("No valid pupil traces found.")

# Trim to shortest trial
min_len = min(len(t) for t in traces)
traces  = np.array([t[:min_len] for t in traces])  # (n_trials, time)
time_ms = np.arange(min_len)

# ── Split into conditions by TrialError ───────────────────────
# Adjust this grouping to match your actual conditions
conditions = {}
for t, trial in enumerate(data):
    p = get_pupil_trace(trial)
    if p is None or len(p) <= BASELINE_END_MS:
        continue
    key = trial['TrialError']   # group by outcome; change to suit your design
    if key not in conditions:
        conditions[key] = []
    conditions[key].append(baseline_correct(p[:min_len]))

# Error code labels — adjust to match your task
error_labels = {
    0: 'Correct',
    3: 'Broke fixation',
    4: 'No fixation',
}

# ── Colour palette (matching the figure style) ────────────────
colours = ['black', 'blue', 'green', 'red', 'magenta']

# ── Plot ──────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(9, 5))

sig_y    = -0.12   # y position for significance bars
sig_step = 0.03    # vertical spacing between bars

for i, (cond_key, cond_traces) in enumerate(sorted(conditions.items())):
    cond_array = np.array(cond_traces)           # (n, time)
    mean  = np.mean(cond_array, axis=0)
    sem   = np.std(cond_array, axis=0) / np.sqrt(len(cond_array))

    # Smooth
    mean_smooth = uniform_filter1d(mean, size=SMOOTH_WINDOW_MS)
    sem_smooth  = uniform_filter1d(sem,  size=SMOOTH_WINDOW_MS)

    colour = colours[i % len(colours)]
    label  = error_labels.get(cond_key, f'Condition {cond_key}')

    ax.plot(time_ms, mean_smooth, lw=2, color=colour, label=label)
    ax.fill_between(time_ms,
                    mean_smooth - sem_smooth,
                    mean_smooth + sem_smooth,
                    color=colour, alpha=0.15)

    # ── Significance bar (periods where mean > 0 + SEM) ──────
    sig_mask = mean_smooth > sem_smooth
    if sig_mask.any():
        sig_times = time_ms[sig_mask]
        ax.hlines(sig_y - i * sig_step,
                  xmin=sig_times[0], xmax=sig_times[-1],
                  colors=colour, linewidth=5)

# ── Formatting ────────────────────────────────────────────────
ax.axhline(0, color='grey', linewidth=0.8, linestyle='--')
ax.axvline(BASELINE_END_MS, color='grey', linewidth=0.8,
           linestyle=':', label='Baseline end')

ax.set_xlabel('Time (ms)', fontsize=12)
ax.set_ylabel('Change in pupil diameter (a.u.)', fontsize=12)
ax.set_title('Pupil dilation time course', fontsize=13)
ax.set_xlim([0, min_len])
ax.legend(frameon=False, fontsize=10)
ax.spines[['top', 'right']].set_visible(False)

plt.tight_layout()
plt.show()