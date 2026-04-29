#!/usr/bin/env python3
"""
generate_stimuli.py
===================
Pre-generates all beep-train WAV files and the MonkeyLogic 2 conditions file
for the temporal decision-making task.

Run this ONCE before the experiment. Outputs:
  wavs/
      beep_train_001.wav  ...  (one per trial row)
      catch_tone.wav
  temporal_task_conditions.csv   <- paste into ML2 conditions file dialog

Design parameters match temporal_task.m exactly.

Author: Steven Errington
Date:   2026
"""

import numpy as np
import os
import csv
import soundfile as sf   # pip install soundfile
from itertools import product as iproduct

# ============================================================
# PARAMETERS — must match temporal_task.m
# ============================================================

FS = 44100   # sample rate (Hz) — match your ML2 audio device

BLOCK_CONFIGS = [
    {'name': 'short',  'mean_dur': 2.0, 'base_isi': 0.22, 'n_lambda': 6},
    {'name': 'medium', 'mean_dur': 5.0, 'base_isi': 0.38, 'n_lambda': 11},
    {'name': 'long',   'mean_dur': 8.0, 'base_isi': 0.50, 'n_lambda': 14},
]

GAMMA_SHAPE            = 4.0
ISI_PREDICTABILITY_LEVELS = [0.0, 0.25, 0.50, 0.75, 1.0]
BEEP_COUNT_MIN         = 4
BEEP_COUNT_MAX         = 25
ISI_NOISE_MAX          = 0.15   # s
ISI_MIN_ABS            = 0.08   # s

BEEP_DURATION          = 0.05   # s
BEEP_FREQ              = 880    # Hz
CATCH_FREQ             = 1320   # Hz
BEEP_VOL               = 0.70
CATCH_VOL              = 0.80

CATCH_PROB             = 0.05
TRIALS_PER_BLOCK       = 60
N_PRACTICE             = 5

RAMP_DURATION          = 0.005  # s — onset/offset cosine ramp to avoid clicks

# Output paths
WAV_DIR        = 'wavs'
CONDITIONS_CSV = 'temporal_task_conditions.csv'

os.makedirs(WAV_DIR, exist_ok=True)

# ============================================================
# AUDIO HELPERS
# ============================================================

def make_tone(freq, duration, vol, fs=FS, ramp=RAMP_DURATION):
    """Synthesise a pure tone with cosine onset/offset ramps."""
    t    = np.linspace(0, duration, int(fs * duration), endpoint=False)
    tone = vol * np.sin(2 * np.pi * freq * t)

    # Cosine ramp
    ramp_samples = int(fs * ramp)
    ramp_samples = min(ramp_samples, len(tone) // 2)
    ramp_env = 0.5 * (1 - np.cos(np.pi * np.arange(ramp_samples) / ramp_samples))
    tone[:ramp_samples]  *= ramp_env
    tone[-ramp_samples:] *= ramp_env[::-1]

    return tone.astype(np.float32)


def build_beep_train_wav(onsets, n_beeps, fs=FS):
    """
    Render a complete beep-train to a numpy array.
    onsets: array of beep start times in seconds.
    Returns mono float32 array.
    """
    if n_beeps == 0:
        return np.zeros(int(fs * 0.1), dtype=np.float32)

    beep  = make_tone(BEEP_FREQ, BEEP_DURATION, BEEP_VOL, fs)
    total_samples = int(fs * (onsets[-1] + BEEP_DURATION + 0.01))
    buf   = np.zeros(total_samples, dtype=np.float32)

    for onset in onsets:
        start = int(onset * fs)
        end   = start + len(beep)
        if end > len(buf):
            end = len(buf)
        buf[start:end] += beep[:end - start]

    # Clip to [-1, 1] safety
    buf = np.clip(buf, -1.0, 1.0)
    return buf


# ============================================================
# SEQUENCE GENERATION (mirrors PsychoPy version exactly)
# ============================================================

def draw_beep_count(block_config, rng):
    n = rng.poisson(block_config['n_lambda'])
    return int(np.clip(n, BEEP_COUNT_MIN, BEEP_COUNT_MAX))


def generate_isis(n_beeps, base_isi, predictability, rng):
    if n_beeps <= 1:
        return np.array([])
    noise_amp = (1.0 - predictability) * ISI_NOISE_MAX
    noise     = rng.uniform(-noise_amp, noise_amp, n_beeps - 1)
    isis      = base_isi + noise
    return np.clip(isis, ISI_MIN_ABS, None)


def build_sequence(block_config, predictability, rng):
    n_beeps = draw_beep_count(block_config, rng)
    isis    = generate_isis(n_beeps, block_config['base_isi'], predictability, rng)

    onsets = np.zeros(n_beeps)
    for i in range(1, n_beeps):
        onsets[i] = onsets[i - 1] + isis[i - 1] + BEEP_DURATION

    actual_dur = float(onsets[-1] + BEEP_DURATION)
    return onsets, actual_dur, n_beeps, isis


# ============================================================
# GENERATE CATCH TONE (single shared WAV)
# ============================================================

catch_tone = make_tone(CATCH_FREQ, BEEP_DURATION, CATCH_VOL)
catch_path = os.path.join(WAV_DIR, 'catch_tone.wav')
sf.write(catch_path, catch_tone, FS)
print(f"  Written: {catch_path}")

# ============================================================
# GENERATE TRIAL LIST
# ============================================================

rng = np.random.default_rng(seed=42)   # fixed seed for reproducibility

def generate_block_trials(block_config, block_num, block_name,
                           trials_per_block, practice=False):
    """
    Returns list of trial dicts for one block.
    Predictability levels are balanced (equal n per level), randomly ordered.
    Catch trials assigned randomly at CATCH_PROB.
    """
    trials_per_level = trials_per_block // len(ISI_PREDICTABILITY_LEVELS)
    pred_list = (ISI_PREDICTABILITY_LEVELS * trials_per_level)[:]
    rng.shuffle(pred_list)

    catch_flags = rng.random(trials_per_block) < CATCH_PROB

    trials = []
    for t_idx in range(trials_per_block):
        pred   = float(pred_list[t_idx])
        is_cat = int(catch_flags[t_idx])

        onsets, actual_dur, n_beeps, isis = build_sequence(
            block_config, pred, rng
        )

        trials.append({
            'block_name'   : block_name,
            'block_num'    : block_num,
            'mean_dur'     : block_config['mean_dur'],
            'predictability': pred,
            'is_catch'     : is_cat,
            'actual_seq_dur': round(actual_dur, 4),
            'n_beeps'      : n_beeps,
            'isis_mean'    : round(float(np.mean(isis)) if len(isis) > 0 else np.nan, 4),
            'isis_std'     : round(float(np.std(isis))  if len(isis) > 0 else np.nan, 4),
            'practice'     : int(practice),
            '_onsets'      : onsets,   # used for WAV generation, not written to CSV
        })

    return trials


# Practice block
practice_config = {'name': 'practice', 'mean_dur': 4.0,
                   'base_isi': 0.32, 'n_lambda': 9}
practice_trials = generate_block_trials(
    practice_config, block_num=0, block_name='practice',
    trials_per_block=N_PRACTICE, practice=True
)

# Main blocks (fixed order here; ML2 block randomisation is handled
# by shuffling block groups in the conditions file or via ML2 block control)
all_trials = list(practice_trials)
for b_idx, cfg in enumerate(BLOCK_CONFIGS):
    block_trials = generate_block_trials(
        cfg, block_num=b_idx + 1, block_name=cfg['name'],
        trials_per_block=TRIALS_PER_BLOCK, practice=False
    )
    all_trials.extend(block_trials)

# ============================================================
# WRITE WAV FILES AND BUILD CONDITIONS CSV
# ============================================================
# ML2 conditions file columns (non-ML2-reserved columns become trial variables):
#
#   Condition     — integer condition number (required by ML2)
#   Block         — ML2 block number (controls block structure in GUI)
#   TaskObject1   — white fixation spot  (defined once; same every trial)
#   TaskObject2   — green fixation spot  (defined once; same every trial)
#   TaskObject3   — beep train WAV       (trial-unique path)
#   TaskObject4   — catch tone WAV       (same path every trial)
#   TaskObject5   — catch flash bitmap   (same path every trial)
#   BLOCK_NAME    — passed to timing script
#   MEAN_DUR      — passed to timing script
#   PREDICTABILITY — passed to timing script
#   IS_CATCH      — passed to timing script
#   BEEP_WAV_INDEX — for bookkeeping
#   ACTUAL_SEQ_DUR — passed to timing script (controls scene duration)
#   N_BEEPS        — passed to timing script
#   ISIS_MEAN      — passed to timing script
#   ISIS_STD       — passed to timing script
#   PRACTICE       — passed to timing script
#
# TaskObject syntax for ML2 CSV (sound):
#   snd(path, vol)         where vol is 0–1 (ML2 maps to dB internally)
# TaskObject syntax for fixation spot:
#   fix(radius_dva)        or a bitmap path
# TaskObject syntax for bitmap:
#   bmp(path)

# Paths — adjust to match your ML2 task folder structure
FIX_WHITE_DEF  = "fix(0.3)"          # 0.3 dva radius white square (ML2 default fix)
FIX_GREEN_DEF  = "fix(0.3,[0 255 0])"  # green fix spot — RGB colour arg
CATCH_WAV_REL  = "wavs/catch_tone.wav"
CATCH_FLASH_DEF = "bmp(catch_flash.bmp)"  # place a yellow triangle BMP in task folder

csv_fieldnames = [
    'Condition', 'Block',
    'TaskObject1', 'TaskObject2', 'TaskObject3', 'TaskObject4', 'TaskObject5',
    'BLOCK_NAME', 'MEAN_DUR', 'PREDICTABILITY', 'IS_CATCH',
    'BEEP_WAV_INDEX', 'ACTUAL_SEQ_DUR', 'N_BEEPS', 'ISIS_MEAN', 'ISIS_STD',
    'PRACTICE',
]

rows = []
for trial_idx, trial in enumerate(all_trials):
    wav_index  = trial_idx + 1
    wav_fname  = f"beep_train_{wav_index:04d}.wav"
    wav_fpath  = os.path.join(WAV_DIR, wav_fname)
    wav_relpath = f"wavs/{wav_fname}"  # relative to ML2 task folder

    # Write WAV
    buf = build_beep_train_wav(trial['_onsets'], trial['n_beeps'])
    sf.write(wav_fpath, buf, FS)

    # ML2 block assignment:
    #   block 0  = practice (shown first, not randomised)
    #   blocks 1-3 = main blocks
    # To randomise main block order: set ML2 GUI → Block Order → Random
    ml2_block = trial['block_num']

    row = {
        'Condition'    : wav_index,
        'Block'        : ml2_block,
        'TaskObject1'  : FIX_WHITE_DEF,
        'TaskObject2'  : FIX_GREEN_DEF,
        'TaskObject3'  : f"snd({wav_relpath},{BEEP_VOL:.2f})",
        'TaskObject4'  : f"snd({CATCH_WAV_REL},{CATCH_VOL:.2f})",
        'TaskObject5'  : CATCH_FLASH_DEF,
        'BLOCK_NAME'   : trial['block_name'],
        'MEAN_DUR'     : trial['mean_dur'],
        'PREDICTABILITY': trial['predictability'],
        'IS_CATCH'     : trial['is_catch'],
        'BEEP_WAV_INDEX': wav_index,
        'ACTUAL_SEQ_DUR': trial['actual_seq_dur'],
        'N_BEEPS'      : trial['n_beeps'],
        'ISIS_MEAN'    : trial['isis_mean'],
        'ISIS_STD'     : trial['isis_std'],
        'PRACTICE'     : trial['practice'],
    }
    rows.append(row)

with open(CONDITIONS_CSV, 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=csv_fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"\nDone.")
print(f"  {len(all_trials)} WAV files written to '{WAV_DIR}/'")
print(f"  Conditions file written: '{CONDITIONS_CSV}'")
print(f"\n  Trial breakdown:")
print(f"    Practice : {N_PRACTICE}")
for cfg in BLOCK_CONFIGS:
    print(f"    {cfg['name'].capitalize():<8} : {TRIALS_PER_BLOCK}")
print(f"    TOTAL    : {len(all_trials)}")
print(f"\n  Next steps:")
print(f"    1. Copy '{WAV_DIR}/', 'temporal_task.m', and 'catch_flash.bmp'")
print(f"       into your ML2 task folder.")
print(f"    2. In ML2 GUI → Conditions → load '{CONDITIONS_CSV}'.")
print(f"    3. Set Block Order to 'Random' for main blocks if desired.")
print(f"    4. Run temporal_task.m as the timing file.")
