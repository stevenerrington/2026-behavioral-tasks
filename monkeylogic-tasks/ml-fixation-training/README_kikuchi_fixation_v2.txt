KIKUCHI FIXATION v2 - what's new and how to run it
====================================================

Background: there's no off-the-shelf "moving spot fixation trainer" pipeline
for MonkeyLogic - labs build this from the standard TaskObject/conditions-file
system. The convention for decoupling reward from a fixed screen location is
to randomise the target's position ACROSS TRIALS (via the conditions file),
not to animate it continuously within one trial - continuous in-trial motion
is a smooth-pursuit task, a different (harder) skill, and would need ML2's
Scene Framework/adapters rather than plain TaskObjects. This build uses the
trial-to-trial approach, per your earlier answer.

Files
-----
kikuchi_fixation_v2.m                  - timing script (discrete trial)
kikuchi_fixation_v2_conditions.txt     - conditions file, 12 conditions
fractal_red/blue/green/amber/purple/teal.png - 6 generated fractal images
make_fractals.py                       - script that generated the PNGs (re-run/tweak if you want different fractals)

What changed vs. v1 (kikuchi_fixation_v1.m)
--------------------------------------------
1. Position: the target now appears at one of 9 grid points (centre + 8
   points at ~8 deg eccentricity) instead of always at (0,0). Position is
   set entirely by the conditions file - the script itself has no position
   logic. Edit the x,y values in the .txt file to change the grid/eccentricity.
2. Stimuli: 12 target options cycle through the grid - the original 6
   coloured squares plus 6 new fractal images. Fractals are commonly used in
   NHP work as high-contrast, non-representational reward cues.
3. Structure: v1 ran as one continuous loop for up to an hour. v2 is a short
   discrete trial (capped at 8 s of cumulative reward, 30 s hard backstop)
   that ends and hands control back to MonkeyLogic, which then draws the
   next condition - this is what makes the target actually relocate.
4. Added a brief 3-blink attention flash before each acquisition attempt,
   since the target may now appear off-centre and needs to catch peripheral
   attention the way a centred square didn't have to.
5. trialerror is always set to 0 (correct) - trials are never scored or
   auto-repeated on failure. This is intentional at the naive-animal stage.

Required MonkeyLogic menu settings
-----------------------------------
On the Task submenu, Blocks pane: set the block's trial order to "Random"
(with "no immediate repeat" if available) and set it to run for many trials
/ indefinitely. Without this, ML may run conditions in a fixed 1-12 order,
which is far less effective at breaking the location-reward association than
true randomisation.

Tuning
------
- fractal size: conditions file currently requests 100x100 px for each
  fractal (pic(...,100,100)). Adjust to match your rig's pixels-per-degree
  so the fractals are a comparable visual size to the 1 deg squares.
- eccentricity: change the 8 / 5.7 values in the conditions file (5.7 ~=
  8/sqrt(2), used for the diagonal points so all 8 outer points are
  equidistant from centre).
- fix_window, acquire_time, reward_dur, max_hold_dur: same meaning as in v1,
  edit at the top of kikuchi_fixation_v2.m.

Suggested shaping progression once this is working
----------------------------------------------------
1. Start at small eccentricity (e.g. 3-4 deg) with a large fix_window, so
   the animal can't fail to find the target.
2. Once reliably fixating off-centre targets, widen the eccentricity range
   and/or shrink fix_window.
3. Once fixation is robust across positions, this task graduates into the
   more standard "acquire -> hold -> reward" trial template most other
   MonkeyLogic tasks use, without further shaping-specific machinery.
