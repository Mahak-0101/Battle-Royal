# ⚔️ BattleRoyal

<p align="center">
  <b>A fast-paced 3D shooter prototype built with Godot.</b><br/>
  <i>Run. Aim. Survive. Repeat.</i>
</p>

<p align="center">
  <img alt="Engine" src="https://img.shields.io/badge/Engine-Godot-478cbf?style=for-the-badge&logo=godot-engine&logoColor=white"/>
  <img alt="Language" src="https://img.shields.io/badge/Language-GDScript-2f4f7f?style=for-the-badge"/>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-PC-1f2937?style=for-the-badge"/>
  <img alt="Status" src="https://img.shields.io/badge/Status-Prototype-f59e0b?style=for-the-badge"/>
</p>

---

## 🎮 Overview

**BattleRoyal** is a third-person/first-person style shooter prototype where the player can move, shoot, and engage enemies in a compact combat loop.

Current focus:
- Responsive player movement
- Weapon shooting flow
- Enemy interaction
- Basic combat feedback (VFX/HUD)

---

## ✨ Features

- Player controller with movement and camera handling
- Weapon system with pistol logic
- Bullet and impact VFX pipeline
- Enemy scene with damage interaction
- HUD scene for gameplay feedback
- Weapon pickup system

---

## 🗂️ Project Structure

```text
BattleRoyal/
├── Main.tscn
├── Player.tscn
├── Player.gd
├── Camera.gd
├── HUD.tscn
├── HUD.gd
├── GameManager.gd
├── Scenes/
│   ├── Weapon.gd
│   ├── Pistol.tscn
│   ├── Pistol.gd
│   ├── Bullet.tscn
│   ├── Bullet.gd
│   ├── Enemy.tscn
│   ├── Enemy.gd
│   ├── WeaponPickup.tscn
│   ├── WeaponPickup.gd
│   ├── ImpactVFX.tscn
│   ├── ImpactVFX.gd
│   └── MuzzleFlash.tscn
└── Assets/
    └── Characters/
```

---

## 🚀 Getting Started

1. Install **Godot** (recommended: latest stable version).
2. Clone this repository:

```bash
git clone https://github.com/<your-username>/BattleRoyal.git
```

3. Open Godot and choose **Import**.
4. Select the project folder and open `project.godot`.
5. Run `Main.tscn`.

---

## 🎯 Controls

> Update these if your input map is different.

- `W / A / S / D` → Move
- `Mouse` → Look
- `Left Click` → Shoot
- `Shift` → Run

---

## 🧩 Tech Stack

- **Engine:** Godot
- **Language:** GDScript
- **Format:** Scene-based architecture (`.tscn` + `.gd`)

---

## 📌 Roadmap

- Add round/wave progression
- Improve enemy AI behavior
- Add audio and hit feedback polish
- Add pause/settings menu
- Add score + end-game flow

---

## 🤝 Contributing

Pull requests are welcome for improvements, bug fixes, and gameplay polish.

If you plan big changes, please open an issue first to discuss direction.

---

## 📜 License

Choose a license before publishing (e.g., MIT) and place it in a `LICENSE` file.

---

<p align="center">
  Built with focus and late-night debugging ☕
</p>
