# Dharma Yoddha

Mahabharat-inspired 3D action adventure built in Godot 3 with a low-spec-first target.

The project is designed for older laptops, including Intel i3 systems with 4GB RAM. It uses GLES2, procedural low-poly props, simple materials, limited enemy counts, lightweight effects, and a compact 960x540 default render target.

## What Is Included

- Story mode with six missions: oath, supplies, raid, temple blessing, battlefield assault, and rival duel.
- Hero selection for Arjun, Krishna, Bhima, and Karna.
- Third-person movement, sprint, jump, dodge, block, melee combo attacks, bow/projectile combat, and a resolve special ability.
- NPC dialogue, mission tracker, interaction prompts, checkpoints, autosave, continue, pause menu, and manual save.
- Low-poly ancient Indian inspired camp, village, river, temple, forest edge, battlefield props, banners, torches, fog, sky, and day/night color shifts.
- Enemy soldiers with tactical chase, strafing, telegraphed attacks, health bars, and mission-aware defeat rewards.
- Procedural ambience and synthesized combat/music stingers without large audio assets.

## Controls

WASD moves, mouse looks, left mouse attacks, right mouse blocks, E interacts, Q uses resolve, Shift sprints, Space jumps, and Escape pauses.

## Running

Open `project.godot` in Godot 3 and run `Main.tscn`.

For quick validation from a terminal:

```bash
xvfb-run -a godot3 --path . --quit
```

## Performance Notes

- Renderer: GLES2.
- Default resolution: 960x540.
- Dynamic shadows are disabled by default; cinematic depth comes from fog, color grading, silhouettes, and simple emissive accents.
- Far clouds, grass, heavy particles, and dynamic torch lights are disabled on the default low-spec profile.
- Enemy population is capped and mission waves are small to avoid CPU spikes.
- Most world art is procedural primitive geometry, so there are no large texture loads.
