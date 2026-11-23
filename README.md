# OrbitBlade.io ⚔️

**Gerçek Zamanlı 2D Top-Down Multiplayer Arena Oyunu**
*Tek bir istemci kod tabanından **Web, Android ve iOS** üzerinde oynanabilir.*

---

## 🌟 Genel Bakış & Mimari

OrbitBlade.io iki birleşik projeden oluşur:

1. **`/server`** — Otoritatif Node.js + TypeScript + Colyseus gerçek zamanlı sunucu. 30 Hz tick hızında çalışır, delta sıkıştırma, Circle-vs-AABB fizik, stealth çalılar, power-up sistemi ve bot doldurma içerir.
2. **`/client`** — Flutter + Flame Game Engine ile çapraz platform istemci. Yatay ekranda çoklu dokunma sanal joystick, ayrı fırlatma butonu, özel kesikli yörünge kılavuzları, darbe efektleri, dükkan ilerlemesi ve overlay sistemi barındırır.

---

## 🗡️ Temel Savaş Mekanikleri

### 1. Yörünge Dönen Bıçak
Bıçak, oyuncunun etrafında dairesel bir yörüngede sürekli döner:

$$\text{bladeX} = \text{player.x} + r \cdot \cos(\theta)$$
$$\text{bladeY} = \text{player.y} + r \cdot \sin(\theta)$$

### 2. Manuel Fırlatma (Auto-Aim Yok)
- Arenaya dokunmak/tıklamak **bıçağı fırlatmaz**.
- Fırlatma yalnızca **FIRLAT** butonuyla (sağ alt) veya **`Space`** tuşuyla tetiklenir.
- Bıçak, tetiklendiği andaki tam açıdan (`frozenAngle`) düz çizgide ilerler.

### 3. Bumerang Dönüşü
Fırlatma anında yörünge açısı donar ve dönüş yuvası parlak bir işaretle gösterilir. Menzile ulaşınca, duvara ya da rakibe çarpınca bıçak bu yuvaya geri döner.

### 4. Darbe Efektleri
Vuruş anında hedef flaş, kısa süre hit-stop, kamera sarsıntısı, kıvılcım partikülleri ve yüzen hasar yazısı tetiklenir.

### 5. Stealth Çalılar
Çalı içindeyken ve bıçak yörüngedeyken oyuncu gizlenir (lokal oyuncuda yarı saydam, uzak oyunculara tamamen görünmez).

### 6. Merkezi Power-Up'lar
- 🔴 **2X GÜÇ** — Bıçak hasarını 7 saniye ikiye katlar.
- 🟢 **CAN** — Anında +45 HP.
- 🔵 **KALKAN** — 1 vuruşluk tam zırh.

---

## 📁 Proje Yapısı

```
/game
├── README.md
├── docker-compose.yml
│
├── server/
│   ├── package.json
│   ├── tsconfig.json
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── src/
│       ├── index.ts                  # Express + Colyseus + WS sunucu
│       ├── rooms/
│       │   ├── ArenaRoom.ts          # Otoritatif 30Hz simülasyon, bot AI
│       │   ├── ArenaEngine.ts        # Direkt WS motoru, fizik, çarpışma
│       │   └── schema/
│       │       └── ArenaState.ts     # Delta-sync Colyseus şeması
│       └── shared/
│           ├── BladeCatalog.ts       # Bıçak tanımları & istatistikleri
│           ├── MapConfigs.ts         # Tapınak, Labirent, Orman haritaları
│           └── NetworkTypes.ts       # Ağ paket arayüzleri
│
└── client/
    ├── pubspec.yaml
    ├── Dockerfile
    ├── lib/
    │   ├── main.dart                        # Yön, depolama, overlay yöneticisi
    │   ├── game/
    │   │   └── orbit_blade_game.dart        # FlameGame döngüsü, canvas render, kamera
    │   ├── models/
    │   │   ├── blade_catalog.dart           # İstatistik, fiyat, renk
    │   │   ├── map_config.dart              # Duvarlar, çalılar, çarpışma matematiği
    │   │   └── game_models.dart             # Oyuncu, power-up, partikül modelleri
    │   ├── network/
    │   │   └── network_service.dart         # WebSocket istemci + çevrimdışı mod
    │   ├── overlays/
    │   │   ├── hud_overlay.dart             # HP, buff, liderlik tablosu
    │   │   ├── virtual_joystick.dart        # Sol taraf sanal joystick
    │   │   ├── throw_button.dart            # FIRLAT aksiyon butonu
    │   │   ├── main_lobby_overlay.dart      # Lobi ekranı
    │   │   ├── map_modal_overlay.dart       # Harita seçici
    │   │   ├── shop_modal_overlay.dart      # Bıçak dükkanı
    │   │   ├── tuning_drawer_overlay.dart   # Canlı fizik ayar çekmecesi
    │   │   └── match_results_overlay.dart   # Maç sonuç ekranı
    │   └── services/
    │       └── storage_service.dart         # SharedPreferences kalıcı depolama
    └── web/
        └── index.html
```

---

## ⚡ Performans Optimizasyonları (v1.1)

Uzun süre oynandığında donma/kasma sorunlarına yol açan temel performans problemleri tespit edilip düzeltildi:

| Sorun | Çözüm |
|---|---|
| **Her karede `TextPainter` + `GoogleFonts` oluşturma** | LRU önbellek sistemi ile `TextPainter` nesneleri yeniden kullanılıyor |
| **Her karede statik zemin çizimi (yüzlerce `drawRect`)** | `ui.Picture` ile önbelleğe alınıp tek çağrıyla çiziliyor |
| **Sınırsız partikül birikimi** | Maks 120 partikül + 24 yüzen metin sınırı eklendi |
| **Sınırsız bıçak izi (blade trail)** | Oyuncu başına maks 12 nokta sınırı getirildi |
| **Her karede yeni `_RenderItem` listesi** | Tek bir liste yeniden kullanılıyor (`_renderablePool`) |
| **Her sync'te liderlik tablosu güncellemesi** | Sadece veriler değiştiğinde `ValueNotifier` güncelleniyor |
| **`_brawlShadows()` her çağrıda yeni liste** | `static const` ile tek sefer oluşturulup paylaşılıyor |
| **`ValueNotifier` dispose edilmiyor** | `_GameScreenState.dispose()` içinde tüm notifier'lar temizleniyor |

---

## 🚀 Çalıştırma

### 1. Sunucu
```bash
cd server
npm install
npm run dev
```
*Sunucu `http://localhost:2567` ve `ws://localhost:2567` üzerinde başlar.*

### 2. İstemci

#### Web (Chrome):
```bash
cd client
flutter run -d chrome
```

#### Android:
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

> **Not:** İstemci, sunucu erişilemez olduğunda otomatik çevrimdışı pratik moduna geçer — sunucu olmadan da anında oynanabilir.

---

## 🐳 Production Deployment (Docker)

```bash
# Sadece sunucu
cd server
docker compose up -d --build

# Sunucu + İstemci (Web)
cd /game
docker compose up -d --build
```

Sunucu özellikleri:
- Node.js 22 Slim production imajı
- `http://localhost:2567/health` sağlık kontrolü
- Coolify/Traefik ile otomatik Let's Encrypt SSL (`wss://`)

---

## 🛠️ Teknoloji Yığını

| Katman | Teknoloji |
|---|---|
| İstemci Motoru | Flutter + Flame Game Engine |
| Sunucu Runtime | Node.js 22 + TypeScript |
| Gerçek Zamanlı | WebSocket (ws) + Colyseus |
| Fizik | Custom Circle-vs-AABB çarpışma |
| Kalıcı Veri | SharedPreferences (istemci) |
| Konteyner | Docker + Docker Compose |

---

## 📜 Lisans

Bu proje özel kullanım içindir.
