"""
Generate 6 colourful, high-contrast Julia-set fractal images for use as
MonkeyLogic pic() TaskObjects in the fixation-training task.

Each image:
 - is rendered at 500x500 px (displayed at a fixed degrees-of-visual-angle
   size in the conditions file via pic(filename,Xdeg,Ydeg,Wpx,Hpx))
 - has a transparent background (RGBA) so it reads as a discrete blob/object
   on the grey MonkeyLogic background rather than a full-frame image
 - uses a distinct, saturated colour map so the six fractals are easily
   discriminable from one another and from the plain colour squares
"""
import numpy as np
from PIL import Image

W = H = 500
MAXITER = 60

# (c value for the Julia set, colormap anchor colour, output filename)
fractal_specs = [
    (complex(-0.70176, -0.3842), (255, 60, 60),  "fractal_red.png"),
    (complex(-0.4,     0.6),     (60, 140, 255), "fractal_blue.png"),
    (complex(0.285,    0.01),    (60, 220, 100), "fractal_green.png"),
    (complex(-0.8,     0.156),   (255, 190, 40), "fractal_amber.png"),
    (complex(-0.75,    0.11),    (200, 80, 255), "fractal_purple.png"),
    (complex(0.34,    -0.05),    (40, 220, 220), "fractal_teal.png"),
]

x = np.linspace(-1.4, 1.4, W)
y = np.linspace(-1.4, 1.4, H)
X, Y = np.meshgrid(x, y)

for c, colour, fname in fractal_specs:
    Z = X + 1j * Y
    iters = np.zeros(Z.shape, dtype=float)
    mask = np.ones(Z.shape, dtype=bool)
    for i in range(MAXITER):
        Z[mask] = Z[mask] ** 2 + c
        escaped = np.abs(Z) > 2
        newly = escaped & mask
        iters[newly] = i
        mask &= ~escaped
    iters[mask] = MAXITER

    norm = iters / MAXITER
    # smooth falloff shading toward the anchor colour, brightest near the
    # fractal boundary (where detail/edges are) for a punchy, high-contrast look
    shade = np.clip(1.2 - norm, 0, 1) ** 0.6

    r = (colour[0] * shade).astype(np.uint8)
    g = (colour[1] * shade).astype(np.uint8)
    b = (colour[2] * shade).astype(np.uint8)

    # alpha: fully opaque on the fractal body (non-escaped / early-escape
    # points), fading to transparent in the "background" (points that
    # escaped almost immediately, i.e. far outside the set)
    alpha = np.clip((iters / (MAXITER * 0.15)), 0, 1)
    alpha = (alpha * 255).astype(np.uint8)

    rgba = np.dstack([r, g, b, alpha])
    img = Image.fromarray(rgba, mode="RGBA")
    img.save(fname)
    print("wrote", fname)
