# OrbitBlade.io ⚔️
**Production-Ready Real-Time 2D Top-Down Multiplayer Arena Game**
*Playable across **Web, Android, and iOS** from a single client codebase.*

---

## 🌟 Overview & Architecture

OrbitBlade.io consists of two unified projects:
1. **/server**: Authoritative real-time Node.js + TypeScript + Colyseus multiplayer game server running at 30Hz tick rate with delta compression, Circle-vs-AABB physics, stealth bushes, power-up systems, and bot backfill.
2. **/client**: Cross-platform Flutter + Flame Game Engine client with responsive landscape multi-touch virtual joystick, separate linear throw action button, custom dashed orbital guides, impact juice, shop progression, and overlays.

---

## 🗡️ Core Combat Mechanics
1. **Oval Orbiting Blade**:
   - The blade rotates continuously around the player on an elliptical path:
     $$\text{bladeX} = \text{player.x} + rx \cdot \cos(\text{angle})$$
     $$\text{bladeY} = \text{player.y} + ry \cdot \sin(\text{angle})$$
   - A faint dashed oval guide is rendered around the player.
   - A dashed radial aim line extends outward from the blade's current angle.
2. **Strict Linear Alignment Firing (NO Auto-Aim)**:
   - Clicking/tapping the arena canvas **never throws the blade**.
   - Throwing is strictly triggered via the dedicated **FIRLAT / THROW** action button (bottom-right) or the **`Space` key**, allowing concurrent joystick/WASD movement.
   - The blade fires strictly in a straight line along the exact angle it was at when triggered (`frozenAngle`).
3. **Orbital Angle Freeze & Boomerang Return**:
   - The moment the blade is thrown, its orbital angle freezes in place and a glowing anchor dot marks the return slot on the player's moving ellipse.
   - When the blade reaches `range`, hits a wall, or hits an opponent, it homes back to the player's moving return slot.
   - As soon as the blade snaps back into the anchor slot, it resumes rotating seamlessly.
4. **Impact Juice**:
   - Hitting deals damage, triggers target hit-stop/flash, camera micro screen-shake, expanding shockwave rings, spark particles, and floating combat text.
5. **Stealth Bushes**:
   - When inside a bush and not throwing, the player is concealed (`opacity: 0.35` for local player, completely invisible to remote players over the network).
6. **Central Power-Ups**:
   - Spawns in the central arena altar:
     - 🔴 **2X DAMAGE**: Doubles blade damage for 8s.
     - 🟢 **HEAL**: +45 HP immediately.
     - 🔵 **SHIELD**: Complete invulnerability for 6s with a glowing barrier ring.

---

## 📁 Project Structure

```text
/game
├── server/
│   ├── package.json
│   ├── tsconfig.json
│   ├── Dockerfile             # Multi-stage production container
│   ├── docker-compose.yml     # Ready for Coolify / VPS deployment
│   └── src/
│       ├── index.ts           # Express + Colyseus WebSocket server
│       ├── rooms/
│       │   ├── ArenaRoom.ts   # Authoritative 30Hz simulation, collisions, bots
│       │   └── schema/
│       │       └── ArenaState.ts  # Delta-synced game state schema
│       └── shared/
│           ├── BladeCatalog.ts    # Blade definitions & stats
│           ├── MapConfigs.ts      # Temple Arena, Stone Labyrinth, Emerald Forest
│           └── NetworkTypes.ts    # Network packet interfaces
│
└── client/
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart                  # Orientation, storage init, overlay manager
    │   ├── game/
    │   │   └── orbit_blade_game.dart  # FlameGame engine loop, canvas rendering, camera
    │   ├── models/
    │   │   ├── blade_catalog.dart     # Stats, price, glow colors
    │   │   ├── map_config.dart        # Walls, bushes, collision math
    │   │   └── game_models.dart       # Player, power-up, and particle models
    │   ├── network/
    │   │   └── network_service.dart   # WebSocket client + seamless local practice fallback
    │   ├── overlays/
    │   │   ├── hud_overlay.dart            # HP, buffs, leaderboard, timer
    │   │   ├── virtual_joystick.dart       # Left-side multi-touch floating joystick
    │   │   ├── throw_button.dart           # Bottom-right FIRLAT action button
    │   │   ├── main_lobby_overlay.dart     # Nickname, map/blade select, play button
    │   │   ├── map_modal_overlay.dart      # Arena map selector
    │   │   ├── shop_modal_overlay.dart     # Blade shop & gold armory
    │   │   ├── tuning_drawer_overlay.dart  # Live mechanics slider drawer
    │   │   └── match_results_overlay.dart  # Victory screen & gold summary
    │   └── services/
    │       └── storage_service.dart   # SharedPreferences persistence
    └── web/
        └── index.html                 # Mobile-friendly web canvas configuration
```

---

## 🚀 How to Run & Test Locally

### 1. Run the Colyseus Server
```bash
cd server
npm install
npm run dev
```
*Server starts on `http://localhost:2567` and `ws://localhost:2567`.*

### 2. Run the Flutter Client

#### Web (Chrome):
```bash
cd client
flutter run -d chrome
```

#### Android Emulator or Device:
```bash
cd client
flutter run -d android
```

#### iOS Simulator (macOS):
```bash
cd client
flutter run -d ios
```

#### Desktop (macOS / Windows / Linux):
```bash
cd client
flutter run -d macos
```

*(Note: The client also includes an automatic offline practice mode fallback, allowing instant playability even if the server is starting or offline).*

---

## 🐳 Production Deployment (Coolify / VPS / Docker)

Deploy using Docker Compose:
```bash
cd server
docker compose up -d --build
```

The server includes:
- Production Node.js 22 Alpine image
- Health check at `http://localhost:2567/health`
- Traefik labels for automatic Let's Encrypt SSL (`wss://`) on Coolify
