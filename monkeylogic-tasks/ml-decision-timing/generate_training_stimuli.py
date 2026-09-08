#!/usr/bin/env python3
"""
generate_training_stimuli.py
=============================
Training-only stimulus set: 100% ISI predictability across all three
duration-prior blocks (short/medium/long), for initial monkey training
before the full task (which crosses 5 predictability levels).

Mirrors generate_stimuli.py's audio/sequence parameters exactly, but
fixes PREDICTABILITY = 1.0 for every trial and drops practice/catch.
"""

import numpy as np
import os
import soundfile as sf

FS = 44100

BLOCK_CONFIGS = [
    {'name': 'short',  'mean_dur': 2.0, 'base_isi': 0.22, 'n_lambda': 6},
    {'name': 'medium', 'mean_dur': 5.0, 'base_isi': 0.38, 'n_lambda': 11},
    {'name': 'long',   'mean_dur': 8.0, 'base_isi': 0.50, 'n_lambda': 14},
]

PREDICTABILITY   = 1.0   # fixed — training set only
BEEP_COUNT_MIN   = 4
BEEP_COUNT_MAX   = 25
ISI_NOISE_MAX    = 0.15
ISI_MIN_ABS      = 0.08
BEEP_DURATION    = 0.05
BEEP_FREQ        = 880
BEEP_VOL         = 0.70
RAMP_DURATION    = 0.005
TRIALS_PER_BLOCK = 60

WAV_DIR = 'wavs'
CONDITIONS_TXT = 'kikuchi_decisiontiming_v1_conditions_training.txt'
os.makedirs(WAV_DIR, exist_ok=True)

def make_tone(freq, duration, vol, fs=FS, ramp=RAMP_DURATION):
    t = np.linspace(0, duration, int(fs * duration), endpoint=False)
    tone = vol * np.sin(2 * np.pi * freq * t)
    ramp_samples = min(int(fs * ramp), len(tone) // 2)
    ramp_env = 0.5 * (1 - np.cos(np.pi * np.arange(ramp_samples) / ramp_samples))
    tone[:ramp_samples] *= ramp_env
    tone[-ramp_samples:] *= ramp_env[::-1]
    return tone.astype(np.float32)

def build_beep_train_wav(onsets, n_beeps, fs=FS):
    if n_beeps == 0:
        return np.zeros(int(fs * 0.1), dtype=np.float32)
    beep = make_tone(BEEP_FREQ, BEEP_DURATION, BEEP_VOL, fs)
    total_samples = int(fs * (onsets[-1] + BEEP_DURATION + 0.01))
    buf = np.zeros(total_samples, dtype=np.float32)
    for onset in onsets:
        start = int(onset * fs)
        end = start + len(beep)
        if end > len(buf):
            end = len(buf)
        buf[start:end] += beep[:end - start]
    return np.clip(buf, -1.0, 1.0)

def draw_beep_count(block_config, rng):
    n = rng.poisson(block_config['n_lambda'])
    return int(np.clip(n, BEEP_COUNT_MIN, BEEP_COUNT_MAX))

def generate_isis(n_beeps, base_isi, predictability, rng):
    if n_beeps <= 1:
        return np.array([])
    noise_amp = (1.0 - predictability) * ISI_NOISE_MAX
    noise = rng.uniform(-noise_amp, noise_amp, n_beeps - 1)
    return np.clip(base_isi + noise, ISI_MIN_ABS, None)

def build_sequence(block_config, predictability, rng):
    n_beeps = draw_beep_count(block_config, rng)
    isis = generate_isis(n_beeps, block_config['base_isi'], predictability, rng)
    onsets = np.zeros(n_beeps)
    for i in range(1, n_beeps):
        onsets[i] = onsets[i - 1] + isis[i - 1] + BEEP_DURATION
    actual_dur = float(onsets[-1] + BEEP_DURATION)
    return onsets, actual_dur, n_beeps, isis

rng = np.random.default_rng(seed=42)

FIX_WHITE_DEF = '"fix(0,0)"'
TARGET_DEF    = '"sqr(0.5,[0.61 0.61 0.61],1,0,7)"'
fieldnames = ['Condition','Block','Frequency','Timing File','Info',
              'TaskObject#1','TaskObject#2','TaskObject#3']

def build_info(block_name, mean_dur, actual_dur, n_beeps, isis_mean, isis_std, wav_index):
    return (f"'block_name','{block_name}',"
            f"'mean_dur',{mean_dur},"
            f"'predictability',{PREDICTABILITY},"
            f"'actual_seq_dur',{round(actual_dur,4)},"
            f"'n_beeps',{n_beeps},"
            f"'isis_mean',{isis_mean},"
            f"'isis_std',{isis_std},"
            f"'practice',0,"
            f"'beep_wav_index',{wav_index}")

rows = []
wav_index = 0
condition_num = 0
for b_idx, cfg in enumerate(BLOCK_CONFIGS):
    ml2_block = b_idx + 1   # 1=short, 2=medium, 3=long — natural numbers, no practice
    for t in range(TRIALS_PER_BLOCK):
        wav_index += 1
        condition_num += 1

        onsets, actual_dur, n_beeps, isis = build_sequence(cfg, PREDICTABILITY, rng)
        isis_mean = round(float(np.mean(isis)) if len(isis) > 0 else np.nan, 4)
        isis_std  = round(float(np.std(isis)) if len(isis) > 0 else 0.0, 4)

        wav_fname = f"beep_train_{wav_index:04d}.wav"
        buf = build_beep_train_wav(onsets, n_beeps)
        sf.write(os.path.join(WAV_DIR, wav_fname), buf, FS)

        info = build_info(cfg['name'], cfg['mean_dur'], actual_dur, n_beeps,
                           isis_mean, isis_std, wav_index)

        rows.append([
            condition_num, ml2_block, 1, 'kikuchi_decisiontiming_v1.m', info,
            FIX_WHITE_DEF, TARGET_DEF, f"snd('./wavs/{wav_fname}')",
        ])

with open(CONDITIONS_TXT, 'w', newline='') as f:
    f.write('\t'.join(fieldnames) + '\n')
    for row in rows:
        f.write('\t'.join(str(x) for x in row) + '\n')

print(f"Done. {len(rows)} training trials written ({TRIALS_PER_BLOCK}/block).")
print(f"Conditions file: {CONDITIONS_TXT}")
print(f"WAVs: {WAV_DIR}/ ({wav_index} files)")
