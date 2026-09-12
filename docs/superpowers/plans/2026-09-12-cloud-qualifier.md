# Cloud Qualifier Implementation Plan

> Execute inline in this new, empty project, following executing-plans. The user approved implementation and narrowed scope to the first round.

**Goal:** Deliver a polished playable single-player 3D first-round race.

**Architecture:** Godot scene-driven world with a shared CharacterBody3D controller for player and bots. Blender-generated reusable models; separate race rules, course, camera and UI.

**Tech Stack:** Godot 4 stable, typed GDScript, Blender 4.4 Python.

**Spec:** docs/superpowers/specs/2026-09-12-cloud-qualifier-design.md

## Global Constraints
- Only first round; 1 player + 31 bots; first 24 qualify; 150-second limit.
- Desktop keyboard/mouse, Chinese UI, all gameplay assets local.
- Target 60fps at 1440x900 on the current M4 Pro; measure, do not infer from build success.

## Tasks
- [ ] 1. Add rule regression tests in tests/test_rules.gd. Confirm missing implementation fails. Implement scripts/race_rules.gd and verify countdown, duplicate finishes, cutoff, timeout and restart.
- [ ] 2. Create art/build_assets.py, assets/models/racer.glb and rounded reusable meshes. Keep editable art/cloud_racer.blend. Inspect model and materials in a real rendered view.
- [ ] 3. Build scripts/course.gd and scripts/racer.gd with checkpoints, collision-based motors, jump buffer, coyote time, rolling and AI routes. Add integration script that loads actual world and exercises movement, jump, cooldown, falls and completion.
- [ ] 4. Build scripts/game.gd and scripts/hud.gd for title, countdown, race, pause, result and retry. Add sound feedback and camera smoothing. Verify full first-round flow.
- [ ] 5. Import and run native Godot. Inspect screenshots, run automated playthrough, record frame metrics, fix observed defects. Create README with controls, launch command and evidence boundaries.

## Verification commands
```
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_rules.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_world.gd
./play.command
```
