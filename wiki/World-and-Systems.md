# 🗺️ World & Systems

## Scene Structure

Key runtime pieces:

- `Main.tscn` for the game entry scene
- `Player.tscn` and `Player.gd` for player control
- `GameManager.gd` for match/game state flow
- `HUD.tscn` and `HUD.gd` for on-screen feedback
- `Scenes/` for weapons, bullets, enemies, pickups, and effects

## Combat Components

- **Weapons:** fire logic and damage pipeline
- **Projectiles:** travel + hit detection
- **Enemies:** target interaction and response
- **VFX:** muzzle + impact feedback

## Design Direction

Current direction is prototype-first:

- Keep systems readable and modular
- Prioritize game feel over feature volume
- Expand with waves, AI behavior, and score flow next

---

⬅️ Back to [Wiki Home](Home.md)

