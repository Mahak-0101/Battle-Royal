# BATTLE ROYAL

<p align="center">
  <img alt="BattleRoyal Banner" src="https://capsule-render.vercel.app/api?type=waving&height=220&color=0:0b1020,30:12203f,65:1c3d2e,100:3f1d0f&text=BattleRoyal&fontAlignY=40&fontColor=f8fafc&desc=Fast-paced%20Godot%20Shooter%20Prototype&descAlignY=62&animation=fadeIn" />
</p>

<p align="center">
  <strong>Run fast. Aim clean. Survive longer.</strong>
</p>

<p align="center">
  <img alt="Engine" src="https://img.shields.io/badge/Engine-Godot-478cbf?style=for-the-badge&logo=godot-engine&logoColor=white"/>
  <img alt="Language" src="https://img.shields.io/badge/Language-GDScript-1e3a8a?style=for-the-badge"/>
  <img alt="Genre" src="https://img.shields.io/badge/Genre-Arena%20Shooter-0f766e?style=for-the-badge"/>
  <img alt="Status" src="https://img.shields.io/badge/Status-Prototype-f59e0b?style=for-the-badge"/>
</p>

<p align="center">
  <a href="#-overview">Overview</a> •
  <a href="#-highlights">Highlights</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-controls">Controls</a> •
  <a href="#-roadmap">Roadmap</a>
</p>

---

## Overview

BattleRoyal is a compact, combat-focused shooter prototype built in Godot.  
The project emphasizes gameplay feel first: responsive movement, satisfying gunplay, and clear combat feedback.

### Core Loop

```text
Spawn -> Move -> Aim -> Fire -> Hit Confirm -> Repeat
```

---

## Highlights

| System | What It Adds |
|---|---|
| Player Controller | Smooth movement + camera control |
| Weapon Pipeline | Pistol, bullet flow, muzzle/impact feedback |
| Enemy Interaction | Damageable target logic and combat response |
| HUD | Core game-state/player feedback |
| Pickups | Weapon pickup and equip flow |

---

## Project Layout

```text
BattleRoyal/
├── Main.tscn
├── Player.tscn / Player.gd
├── Camera.gd
├── HUD.tscn / HUD.gd
├── GameManager.gd
├── Scenes/
│   ├── Weapon.gd
│   ├── Pistol.tscn / Pistol.gd
│   ├── Bullet.tscn / Bullet.gd
│   ├── Enemy.tscn / Enemy.gd
│   ├── WeaponPickup.tscn / WeaponPickup.gd
│   ├── ImpactVFX.tscn / ImpactVFX.gd
│   └── MuzzleFlash.tscn
└── Assets/Characters/
```

---

## Quick Start

1. Install Godot (latest stable recommended).
2. Clone the repo:

```bash
git clone https://github.com/<your-username>/BattleRoyal.git
```

3. Open Godot and click Import.
4. Select the project folder and open project.godot.
5. Run Main.tscn.

---

## Controls

| Input | Action |
|---|---|
| W / A / S / D | Move |
| Mouse | Look |
| Left Click | Shoot |
| Shift | Run |

Note: Update this table if your Input Map changes.

---

## Tech Stack

- Engine: Godot
- Language: GDScript
- Architecture: Scene-based (.tscn + .gd)

---

## Roadmap

- Wave/round progression
- Smarter enemy behavior
- Stronger audio and hit feedback polish
- Pause/settings menu
- Score system + end game flow

---

## Contributing

Suggestions, fixes, and polish PRs are welcome.

For major changes, open an issue first so we can align direction.

---

## License

Choose a license before publishing (MIT is a common choice) and add a LICENSE file.

---

<p align="center">
  Built with focus, iteration, and late-night debugging.
</p>
