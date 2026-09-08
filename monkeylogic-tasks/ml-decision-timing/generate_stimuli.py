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
BEEP_VOL               = 0.70

TRIALS_PER_BLOCK       = 60

RAMP_DURATION          = 0.005  # s — onset/offset cosine ramp to avoid clicks

# Output paths
WAV_DIR        = 'wavs'
CONDITIONS_CSV = 'kikuchi_decisiontiming_v1_conditions.txt'   # real ML2 format is tab-delimited .txt, not .csv

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
# GENERATE TRIAL LIST
# ============================================================

rng = np.random.default_rng(seed=42)   # fixed seed for reproducibility

def generate_block_trials(block_config, block_num, block_name,
                           trials_per_block, practice=False):
    """
    Returns list of trial dicts for one block.
    Predictability levels are balanced (equal n per level), randomly ordered.
    """
    trials_per_level = trials_per_block // len(ISI_PREDICTABILITY_LEVELS)
    pred_list = (ISI_PREDICTABILITY_LEVELS * trials_per_level)[:]
    rng.shuffle(pred_list)

    trials = []
    for t_idx in range(trials_per_block):
        pred   = float(pred_list[t_idx])

        onsets, actual_dur, n_beeps, isis = build_sequence(
            block_config, pred, rng
        )

        trials.append({
            'block_name'   : block_name,
            'block_num'    : block_num,
            'mean_dur'     : block_config['mean_dur'],
            'predictability': pred,
            'actual_seq_dur': round(actual_dur, 4),
            'n_beeps'      : n_beeps,
            'isis_mean'    : round(float(np.mean(isis)) if len(isis) > 0 else np.nan, 4),
            'isis_std'     : round(float(np.std(isis))  if len(isis) > 0 else np.nan, 4),
            'practice'     : int(practice),
            '_onsets'      : onsets,   # used for WAV generation, not written to CSV
        })

    return trials


# Main blocks only — practice has been dropped from this task (fixed order
# here; ML2 block randomisation is handled by shuffling block groups in the
# conditions file or via ML2 block control)
all_trials = []
for b_idx, cfg in enumerate(BLOCK_CONFIGS):
    block_trials = generate_block_trials(
        cfg, block_num=b_idx + 1, block_name=cfg['name'],
        trials_per_block=TRIALS_PER_BLOCK, practice=False
    )
    all_trials.extend(block_trials)

# ============================================================
# WRITE WAV FILES AND BUILD CONDITIONS CSV
# ============================================================
# ML2 conditions file — valid headers ONLY are:
#   "Condition", "Frequency", "Block", "Timing File", "Info",
#   and "TaskObject#1" through "TaskObject#N".
# Arbitrary named columns (e.g. "BLOCK_NAME") are NOT valid and will
# cause a load error. All per-trial variables instead go through the
# single reserved "Info" column, as a flat comma-separated list of
# 'key',value pairs — ML2 parses this into a struct that the timing
# script reads as Info.key (e.g. Info.block_name, Info.actual_seq_dur).
#
# TaskObject syntax (must be tab-delimited, quoted as shown):
#   "fix(x_dva,y_dva)"                      — fixation-type spot at a position
#   "sqr(radius_dva,[R G B 0-1],alpha,x,y)" — coloured square at a position
#   snd('relative/path.wav')                — sound, no volume argument
#
# TaskObject#2 IS the saccade target (green square, 7 dva up) — there is
# no separate cue object in this design.

FIX_WHITE_DEF  = '"fix(0,0)"'
TARGET_DEF     = '"sqr(0.5,[0.61 0.61 0.61],1,0,7)"'   # 0.5 dva radius, gray, 7 dva up

conditions_fieldnames = ['Condition', 'Block', 'Frequency', 'Timing File', 'Info',
                          'TaskObject#1', 'TaskObject#2', 'TaskObject#3']

def build_info(trial, wav_index):
    """Flat 'key',value list for the Info column -> Info.key in the timing script."""
    return (f"'block_name','{trial['block_name']}',"
            f"'mean_dur',{trial['mean_dur']},"
            f"'predictability',{trial['predictability']},"
            f"'actual_seq_dur',{trial['actual_seq_dur']},"
            f"'n_beeps',{trial['n_beeps']},"
            f"'isis_mean',{trial['isis_mean']},"
            f"'isis_std',{trial['isis_std']},"
            f"'practice',{trial['practice']},"
            f"'beep_wav_index',{wav_index}")

rows = []
for trial_idx, trial in enumerate(all_trials):
    wav_index  = trial_idx + 1
    wav_fname  = f"beep_train_{wav_index:04d}.wav"
    wav_fpath  = os.path.join(WAV_DIR, wav_fname)
    wav_relpath = f"./wavs/{wav_fname}"  # relative to ML2 task folder

    # Write WAV
    buf = build_beep_train_wav(trial['_onsets'], trial['n_beeps'])
    sf.write(wav_fpath, buf, FS)

    # ML2 block assignment (Block must be a natural number, 1 or larger):
    #   block 1    = practice (shown first, not randomised)
    #   blocks 2-4 = main blocks
    # To randomise main block order: set ML2 GUI → Block Order → Random
    ml2_block = trial['block_num']

    row = [
        wav_index,
        ml2_block,
        1,
        'kikuchi_decisiontiming_v1.m',
        build_info(trial, wav_index),
        FIX_WHITE_DEF,
        TARGET_DEF,
        f"snd('{wav_relpath}')",
    ]
    rows.append(row)

# Written by hand (not csv.writer) to avoid auto-quoting the embedded
# double quotes in the TaskObject fields — ML2 expects them literal.
with open(CONDITIONS_CSV, 'w', newline='') as f:
    f.write('\t'.join(conditions_fieldnames) + '\n')
    for row in rows:
        f.write('\t'.join(str(x) for x in row) + '\n')

print(f"\nDone.")
print(f"  {len(all_trials)} WAV files written to '{WAV_DIR}/'")
print(f"  Conditions file written: '{CONDITIONS_CSV}'")
print(f"\n  Trial breakdown:")
for cfg in BLOCK_CONFIGS:
    print(f"    {cfg['name'].capitalize():<8} : {TRIALS_PER_BLOCK}")
print(f"    TOTAL    : {len(all_trials)}")
print(f"\n  Next steps:")
print(f"    1. Copy '{WAV_DIR}/' and 'kikuchi_decisiontiming_v1.m'")
print(f"       into your ML2 task folder.")
print(f"    2. In ML2 GUI → Conditions → load '{CONDITIONS_CSV}'.")
print(f"    3. Set Block Order to 'Random' if desired.")
print(f"    4. Run kikuchi_decisiontiming_v1.m as the timing file.")