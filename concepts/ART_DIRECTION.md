# Goofy Balls — Art direction

## Core look

Dark neon sports arena: near-black world, light-gray court floor, restrained glass boundaries, bright playable silhouettes.

## Palette

- Background: `#010310` / `#05091F`
- Floor: light gray `#C3C3C3`
- Blue player / court edge: electric cyan `#03B8FF`
- Red player / results accent: neon magenta `#FF05AD`
- Ball / score: warm neon yellow `#FFD20A`
- Secondary text: desaturated steel blue

## Materials

- Ball, players, net: bright albedo first; soft emission (`~0.5–0.85`), not eye-searing bloom.
- Walls and ceiling: transparent cyan glass, low opacity and weak emission.
- Floor: light gray `#C3C3C3`, low metallic; dark ground-shadow discs stay readable on it.
- Ground shadows: dark disc meshes pinned to the floor directly under ball/blobs (fade/shrink with height) for readability.
- Contact lighting: small colored OmniLights on ball/blobs (fill only; discs carry the shadow read).
- Background: soft drifting smoke layers behind the court (low alpha, cyan/magenta tint) plus light depth fog — atmosphere only, never competing with gameplay.
- Floating ash: sparse Upside-Down-style motes drifting through the court volume (tiny additive specs, cyan/magenta tint, turbulence) — eerie depth, never a snowstorm.
- Glow is restrained: thin halo, never a screen-wide wash.

## UI

- Near-black backgrounds.
- Cyan outlines for normal/focused controls; magenta for active/pressed accents.
- Keep text high contrast and phone-landscape readable.

## Must / never

- Gameplay elements must be the brightest objects.
- Glass boundaries must remain visible but subordinate.
- Never return to daylight sky, green hills, or brown court styling.
- Do not use bloom so strongly that ball/player silhouettes merge.
