import { getBladeSpec, BladeSpec, BLADE_CATALOG } from '../shared/BladeCatalog';
import {
  getMapConfig,
  MapConfig,
  resolveWallCollisions,
  bladeHitsWall,
  isInsideBush,
  findSafeSpawn,
  WORLD_W,
  WORLD_H,
} from '../shared/MapConfigs';
import {
  HitEvent,
  KillEvent,
  PowerUpEvent,
  PowerUpType,
  StateSnapshot,
  PlayerNetData,
  PowerUpNetData,
} from '../shared/NetworkTypes';

const BOT_NAMES = [
  'GölgeBıçak',
  'FırtınaTR',
  'EjderhaX',
  'TitanPro',
  'ViperTR',
  'AteşKuşu',
  'KayaCanavarı',
  'SiberNinja',
  'KurtReis',
  'Şimşek99',
  'HayaletBıçak',
  'KızılBüyücü'
];
const DEFAULT_BOT_COUNT = 3;

export interface ClientConnection {
  sessionId: string;
  send: (type: string, data: any) => void;
  sendRaw?: (payload: string) => void;
  isOpen: () => boolean;
}

export class EnginePlayer {
  id: string = '';
  name: string = '';
  x: number = 0;
  y: number = 0;
  vx: number = 0;
  vy: number = 0;
  facing: number = 0;
  radius: number = 25;
  hp: number = 130;
  maxHp: number = 130;
  speed: number = 245;
  kills: number = 0;
  isBot: boolean = false;
  bladeId: string = 'steel';
  dmgTimer: number = 0;
  shieldHits: number = 0;
  shieldTimer: number = 0;
  isHidden: boolean = false;
  inBush: boolean = false;
  flash: number = 0;

  blade = {
    state: 'orbit' as 'orbit' | 'out' | 'return',
    angle: 0,
    frozenAngle: 0,
    spin: 0,
    x: 0,
    y: 0,
    dirX: 1,
    dirY: 0,
    traveled: 0,
    rx: 48,
    ry: 48,
    orbitRadius: 48,
    orbitSpeed: 3.4,
    throwSpeed: 680,
    range: 290,
    damage: 38,
    speedMult: 1.0,
    bladeColor: '#e2e8f0',
    edgeColor: '#38bdf8',
    hitTargets: new Set<string>(),
  };

  inputDx: number = 0;
  inputDy: number = 0;
  aiTimer: number = 0.5;
  aiMoveX: number = 0;
  aiMoveY: number = 0;
}

export class EnginePowerUp {
  id: string = '';
  x: number = 0;
  y: number = 0;
  type: PowerUpType = 'DAMAGE';
  active: boolean = true;
  respawn: number = 0;
}

export class ArenaEngine {
  public mapConfig: MapConfig;
  public matchTime: number = 180;
  public targetBotCount: number = DEFAULT_BOT_COUNT;
  public players = new Map<string, EnginePlayer>();
  public powerUps: EnginePowerUp[] = [];
  public clients = new Map<string, ClientConnection>();

  private simTimer: any = null;

  constructor(mapId: string = 'temple') {
    this.mapConfig = getMapConfig(mapId);
    this.initPowerUps();
    this.startSimulation();
    this.reconcileBots();
  }

  private initPowerUps() {
    this.powerUps = [
      { id: 'pow_1', x: WORLD_W / 2, y: WORLD_H / 2, type: 'DAMAGE', active: true, respawn: 0 },
      { id: 'pow_2', x: WORLD_W / 2 - 190, y: WORLD_H / 2, type: 'HEAL', active: true, respawn: 0 },
      { id: 'pow_3', x: WORLD_W / 2 + 190, y: WORLD_H / 2, type: 'SHIELD', active: true, respawn: 0 },
    ];
  }

  public registerClient(client: ClientConnection) {
    this.clients.set(client.sessionId, client);

    const player = new EnginePlayer();
    player.id = client.sessionId;
    player.name = 'SEN';
    player.bladeId = 'steel';
    player.isBot = false;
    player.radius = 25;
    player.hp = 130;
    player.maxHp = 130;
    player.speed = 245;

    const spec = getBladeSpec(player.bladeId);
    player.blade.rx = spec.rx;
    player.blade.ry = spec.ry;
    player.blade.orbitRadius = spec.orbitRadius;
    player.blade.orbitSpeed = spec.orbitSpeed;
    player.blade.throwSpeed = spec.throwSpeed;
    player.blade.range = spec.range;
    player.blade.damage = spec.damage;
    player.blade.speedMult = spec.speedMult;
    player.blade.bladeColor = spec.bladeColor;
    player.blade.edgeColor = spec.edgeColor;

    player.x = WORLD_W / 2;
    player.y = WORLD_H - 180;
    player.facing = -Math.PI / 2;

    player.blade.state = 'orbit';
    player.blade.angle = 0;
    player.blade.frozenAngle = 0;
    player.blade.spin = 0;
    player.blade.x = player.x + player.blade.orbitRadius * Math.cos(player.blade.angle);
    player.blade.y = player.y + player.blade.orbitRadius * Math.sin(player.blade.angle);

    this.players.set(client.sessionId, player);

    // Initial handshake packet
    client.send('init', {
      sessionId: client.sessionId,
      mapId: this.mapConfig.id,
      arenaSize: this.mapConfig.size,
    });

    this.reconcileBots();
  }

  public removeClient(sessionId: string) {
    this.clients.delete(sessionId);
    this.players.delete(sessionId);
    this.reconcileBots();
  }

  public handleMessage(sessionId: string, type: string, data: any) {
    const player = this.players.get(sessionId);
    if (!player) return;

    if (type === 'move') {
      const mag = Math.hypot(data?.dx || 0, data?.dy || 0);
      if (mag > 1) {
        player.inputDx = (data?.dx || 0) / mag;
        player.inputDy = (data?.dy || 0) / mag;
      } else {
        player.inputDx = data?.dx || 0;
        player.inputDy = data?.dy || 0;
      }
      if (mag > 0.05) {
        player.facing = Math.atan2(player.inputDy, player.inputDx);
      }
    } else if (type === 'throw') {
      this.throwBlade(player);
    } else if (type === 'join') {
      if (data?.name) player.name = data.name.trim();
      if (data?.botCount !== undefined) {
        const count = parseInt(data.botCount, 10);
        if (!isNaN(count)) {
          this.targetBotCount = Math.max(0, Math.min(10, count));
          this.reconcileBots();
        }
      }
      if (data?.bladeId) {
        player.bladeId = data.bladeId;
        const spec = getBladeSpec(data.bladeId);
        player.blade.rx = spec.rx;
        player.blade.ry = spec.ry;
        player.blade.orbitRadius = spec.orbitRadius;
        player.blade.orbitSpeed = spec.orbitSpeed;
        player.blade.throwSpeed = spec.throwSpeed;
        player.blade.range = spec.range;
        player.blade.damage = spec.damage;
        player.blade.speedMult = spec.speedMult;
        player.blade.bladeColor = spec.bladeColor;
        player.blade.edgeColor = spec.edgeColor;
        player.blade.x = player.x + spec.orbitRadius * Math.cos(player.blade.angle);
        player.blade.y = player.y + spec.orbitRadius * Math.sin(player.blade.angle);
      }
    } else if (type === 'tune') {
      if (data) {
        if (data.orbitSpeed) player.blade.orbitSpeed = data.orbitSpeed;
        if (data.throwSpeed) player.blade.throwSpeed = data.throwSpeed;
        if (data.range) player.blade.range = data.range;
      }
    } else if (type === 'ping') {
      const client = this.clients.get(sessionId);
      client?.send('pong', { clientTime: data?.t || 0, serverTime: Date.now() });
    }
  }

  public broadcast(type: string, data: any) {
    if (this.clients.size === 0) return;
    const payload = JSON.stringify({ type, data });
    this.clients.forEach((c) => {
      if (c.isOpen()) {
        if (c.sendRaw) {
          c.sendRaw(payload);
        } else {
          c.send(type, data);
        }
      }
    });
  }

  private startSimulation() {
    this.simTimer = setInterval(() => {
      this.update(1 / 30);
    }, 1000 / 30);
  }

  public stopSimulation() {
    if (this.simTimer) {
      clearInterval(this.simTimer);
      this.simTimer = null;
    }
  }

  private reconcileBots() {
    let humanCount = 0;
    const botKeys: string[] = [];

    this.players.forEach((p, key) => {
      if (p.isBot) botKeys.push(key);
      else humanCount++;
    });

    const neededBots = Math.max(0, this.targetBotCount);

    while (botKeys.length > neededBots) {
      const key = botKeys.pop();
      if (key) this.players.delete(key);
    }

    const botBlades = BLADE_CATALOG.map((b) => b.id);

    while (botKeys.length < neededBots) {
      const idx = botKeys.length;
      const botId = `bot_${idx}`;
      const botName = BOT_NAMES[idx % BOT_NAMES.length];

      const sp = findSafeSpawn(WORLD_W / 2, WORLD_H / 2);
      const bKey = botBlades[idx % botBlades.length];
      const spec = getBladeSpec(bKey);

      const bot = new EnginePlayer();
      bot.id = botId;
      bot.name = botName;
      bot.bladeId = bKey;
      bot.isBot = true;
      bot.radius = 25;
      bot.hp = 105;
      bot.maxHp = 105;
      bot.speed = 185;
      bot.kills = 0;
      bot.x = sp.x;
      bot.y = sp.y;
      bot.facing = 0;
      bot.aiTimer = 0.4 + Math.random() * 0.6;

      bot.blade.rx = spec.rx;
      bot.blade.ry = spec.ry;
      bot.blade.orbitRadius = spec.orbitRadius;
      bot.blade.orbitSpeed = spec.orbitSpeed;
      bot.blade.throwSpeed = spec.throwSpeed;
      bot.blade.range = spec.range;
      bot.blade.damage = spec.damage;
      bot.blade.speedMult = spec.speedMult;
      bot.blade.bladeColor = spec.bladeColor;
      bot.blade.edgeColor = spec.edgeColor;
      bot.blade.state = 'orbit';
      bot.blade.angle = Math.random() * Math.PI * 2;
      bot.blade.frozenAngle = 0;
      bot.blade.spin = bot.blade.angle;
      bot.blade.x = bot.x + bot.blade.orbitRadius * Math.cos(bot.blade.angle);
      bot.blade.y = bot.y + bot.blade.orbitRadius * Math.sin(bot.blade.angle);

      resolveWallCollisions(bot, this.mapConfig);

      this.players.set(botId, bot);
      botKeys.push(botId);
    }
  }

  private respawnPlayer(player: EnginePlayer) {
    if (player.isBot) {
      const human = Array.from(this.players.values()).find((p) => !p.isBot);
      const sp = findSafeSpawn(human ? human.x : WORLD_W / 2, human ? human.y : WORLD_H / 2);
      player.x = sp.x;
      player.y = sp.y;
    } else {
      const sp = findSafeSpawn(WORLD_W / 2, WORLD_H / 2);
      player.x = sp.x;
      player.y = sp.y;
      player.shieldHits = 1;
    }
    player.hp = player.maxHp;
    player.dmgTimer = 0;
    player.shieldTimer = 0;
    player.inputDx = 0;
    player.inputDy = 0;
    player.blade.state = 'orbit';
    resolveWallCollisions(player, this.mapConfig);
  }

  private throwBlade(player: EnginePlayer) {
    const b = player.blade;
    if (b.state !== 'orbit') return;

    b.state = 'out';
    b.frozenAngle = b.angle;
    b.dirX = Math.cos(b.frozenAngle);
    b.dirY = Math.sin(b.frozenAngle);
    b.x = player.x + b.dirX * b.orbitRadius;
    b.y = player.y + b.dirY * b.orbitRadius;
    b.traveled = b.orbitRadius;
    b.spin = b.frozenAngle;
    b.hitTargets.clear();
  }

  private update(dt: number) {
    if (this.matchTime > 0) {
      this.matchTime = Math.max(0, this.matchTime - dt);
    }

    // 1. Power-Ups
    this.powerUps.forEach((pow) => {
      if (!pow.active) {
        pow.respawn -= dt;
        if (pow.respawn <= 0) {
          pow.active = true;
          this.broadcast('powerup_spawn', { id: pow.id, x: pow.x, y: pow.y, type: pow.type });
        }
        return;
      }

      this.players.forEach((player) => {
        if (!pow.active) return;
        const dx = player.x - pow.x;
        const dy = player.y - pow.y;
        const pickupR = player.radius + 20;
        if (dx * dx + dy * dy <= pickupR * pickupR) {
          pow.active = false;
          pow.respawn = 9.0;

          if (pow.type === 'DAMAGE') player.dmgTimer = 7.0;
          else if (pow.type === 'HEAL') player.hp = Math.min(player.maxHp, player.hp + 45);
          else if (pow.type === 'SHIELD') player.shieldHits = 1;

          this.broadcast('powerup', {
            playerId: player.id,
            type: pow.type,
            x: pow.x,
            y: pow.y,
          } as PowerUpEvent);
        }
      });
    });

    // 2. Players & Bots (zero-allocation human lookup)
    let humanPlayer: EnginePlayer | undefined;
    for (const p of this.players.values()) {
      if (!p.isBot) {
        humanPlayer = p;
        break;
      }
    }

    this.players.forEach((player) => {
      if (player.dmgTimer > 0) player.dmgTimer = Math.max(0, player.dmgTimer - dt);
      if (player.flash > 0) player.flash = Math.max(0, player.flash - dt);

      let mx = 0;
      let my = 0;

      if (player.isBot) {
        if (humanPlayer) {
          this.updateBotAI(player, humanPlayer, dt);
        }
        mx = player.aiMoveX;
        my = player.aiMoveY;
      } else {
        mx = player.inputDx;
        my = player.inputDy;
      }

      const len = Math.hypot(mx, my);
      if (len > 0.01) {
        const norm = len > 1 ? 1 / len : 1;
        player.vx = mx * norm * player.speed;
        player.vy = my * norm * player.speed;
        player.facing = Math.atan2(player.vy, player.vx);
      } else {
        player.vx = 0;
        player.vy = 0;
      }

      player.x += player.vx * dt;
      player.y += player.vy * dt;
      resolveWallCollisions(player, this.mapConfig);

      player.inBush = isInsideBush(player.x, player.y, this.mapConfig);
      player.isHidden = player.inBush && player.blade.state === 'orbit';

      this.updateBladePhysics(player, dt);
    });

    // 3. Broadcast Snapshot
    this.broadcastStateSnapshot();
  }

  // Exact Enemy AI logic matching HTML prototype
  private updateBotAI(bot: EnginePlayer, player: EnginePlayer, dt: number) {
    bot.aiTimer -= dt;
    const canSeePlayer = !player.inBush || Math.hypot(player.x - bot.x, player.y - bot.y) < 110;
    const targetX = canSeePlayer ? player.x : WORLD_W / 2;
    const targetY = canSeePlayer ? player.y : WORLD_H / 2;

    if (bot.aiTimer <= 0) {
      bot.aiTimer = 0.35 + Math.random() * 0.45;
      const dx = targetX - bot.x;
      const dy = targetY - bot.y;
      const dist = Math.hypot(dx, dy) || 1;
      const strafe = (Math.random() - 0.5) * 1.3;
      const baseAngle = Math.atan2(dy, dx);

      if (dist > 230) {
        bot.aiMoveX = Math.cos(baseAngle + strafe * 0.4);
        bot.aiMoveY = Math.sin(baseAngle + strafe * 0.4);
      } else if (dist < 145) {
        bot.aiMoveX = -Math.cos(baseAngle) + Math.cos(baseAngle + Math.PI / 2) * strafe;
        bot.aiMoveY = -Math.sin(baseAngle) + Math.sin(baseAngle + Math.PI / 2) * strafe;
      } else {
        bot.aiMoveX = Math.cos(baseAngle + Math.PI / 2) * (strafe >= 0 ? 1 : -1);
        bot.aiMoveY = Math.sin(baseAngle + Math.PI / 2) * (strafe >= 0 ? 1 : -1);
      }
    }

    // Bots fire strictly when their orbiting blade aligns with target!
    if (bot.blade.state === 'orbit' && canSeePlayer) {
      const dx = player.x - bot.x;
      const dy = player.y - bot.y;
      const dist = Math.hypot(dx, dy);
      if (dist < 310) {
        const desiredAngle = Math.atan2(dy, dx);
        const diff = Math.abs(Math.atan2(Math.sin(bot.blade.angle - desiredAngle), Math.cos(bot.blade.angle - desiredAngle)));
        if (diff < 0.18) {
          this.throwBlade(bot);
        }
      }
    }
  }

  private updateBladePhysics(player: EnginePlayer, dt: number) {
    const bb = player.blade;
    const speed = (player.isBot ? 560 : bb.throwSpeed) * bb.speedMult;

    if (bb.state === 'orbit') {
      bb.angle = (bb.angle + bb.orbitSpeed * dt) % (Math.PI * 2);
      bb.spin = bb.angle;
      bb.x = player.x + bb.orbitRadius * Math.cos(bb.angle);
      bb.y = player.y + bb.orbitRadius * Math.sin(bb.angle);
    } else if (bb.state === 'out') {
      bb.spin += 18 * dt;
      const step = speed * dt;
      bb.x += bb.dirX * step;
      bb.y += bb.dirY * step;
      bb.traveled += step;

      if (bladeHitsWall(bb.x, bb.y, this.mapConfig, 12) || bb.traveled >= bb.range) {
        bb.state = 'return';
        this.broadcast('hit', {
          x: bb.x,
          y: bb.y,
          damage: 0,
          targetId: 'wall',
          attackerId: player.id,
          color: '#cbd5e1',
        } as HitEvent);
      } else {
        this.players.forEach((target) => {
          if (target.id === player.id || target.hp <= 0 || bb.hitTargets.has(target.id)) return;
          if (bb.state !== 'out') return;

          const dx = bb.x - target.x;
          const dy = bb.y - target.y;
          const hitR = target.radius + 18;
          if (dx * dx + dy * dy <= hitR * hitR) {
            bb.hitTargets.add(target.id);

            if (target.shieldHits > 0) {
              target.shieldHits -= 1;
              target.flash = 0.16;
              this.broadcast('hit', {
                x: target.x,
                y: target.y,
                damage: 0,
                targetId: target.id,
                attackerId: player.id,
                color: '#38bdf8',
              } as HitEvent);
            } else {
              const mult = player.dmgTimer > 0 ? 1.65 : 1.0;
              const damage = Math.round(bb.damage * mult);
              target.hp = Math.max(0, target.hp - damage);
              target.flash = 0.16;

              this.broadcast('hit', {
                x: target.x,
                y: target.y,
                damage,
                targetId: target.id,
                attackerId: player.id,
                color: bb.bladeColor,
              } as HitEvent);

              if (target.hp <= 0) {
                player.kills++;
                this.broadcast('kill', {
                  killerId: player.id,
                  victimId: target.id,
                  killerName: player.name,
                  victimName: target.name,
                  goldAwarded: 35,
                } as KillEvent);

                this.respawnPlayer(target);
              }
            }
          }
        });
      }
    } else if (bb.state === 'return') {
      bb.spin += 18 * dt;
      const slotX = player.x + bb.orbitRadius * Math.cos(bb.frozenAngle);
      const slotY = player.y + bb.orbitRadius * Math.sin(bb.frozenAngle);
      const dx = slotX - bb.x;
      const dy = slotY - bb.y;
      const dist = Math.hypot(dx, dy);
      const returnStep = speed * 1.18 * dt;

      if (dist <= returnStep + 10) {
        bb.x = slotX;
        bb.y = slotY;
        bb.angle = bb.frozenAngle;
        bb.state = 'orbit';
        bb.hitTargets.clear();
      } else {
        bb.x += (dx / dist) * returnStep;
        bb.y += (dy / dist) * returnStep;
      }
    }
  }

  private broadcastStateSnapshot() {
    if (this.clients.size === 0) return;
    const playersList: PlayerNetData[] = [];

    this.players.forEach((p) => {
      playersList.push({
        id: p.id,
        name: p.name,
        x: Math.round(p.x * 10) / 10,
        y: Math.round(p.y * 10) / 10,
        facing: Math.round(p.facing * 1000) / 1000,
        radius: p.radius,
        hp: p.hp,
        maxHp: p.maxHp,
        kills: p.kills,
        isBot: p.isBot,
        bladeId: p.bladeId,
        bladeState: p.blade.state,
        bladeAngle: Math.round(p.blade.angle * 1000) / 1000,
        bladeSpin: Math.round(p.blade.spin * 1000) / 1000,
        bladeX: Math.round(p.blade.x * 10) / 10,
        bladeY: Math.round(p.blade.y * 10) / 10,
        frozenAngle: Math.round(p.blade.frozenAngle * 1000) / 1000,
        dmgTimer: Math.round(p.dmgTimer * 10) / 10,
        shieldTimer: Math.round(p.shieldTimer * 10) / 10,
        isHidden: p.isHidden,
      });
    });

    const powerUpsList: PowerUpNetData[] = [];
    this.powerUps.forEach((pow) => {
      if (!pow.active) return;
      powerUpsList.push({
        id: pow.id,
        x: Math.round(pow.x * 10) / 10,
        y: Math.round(pow.y * 10) / 10,
        type: pow.type,
      });
    });

    const snapshot: StateSnapshot = {
      t: Date.now(),
      players: playersList,
      powerUps: powerUpsList,
      matchTime: Math.round(this.matchTime),
    };

    this.broadcast('sync', snapshot);
  }
}
