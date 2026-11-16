import type { WebSocket } from 'ws';
import {
  ArenaState,
  PlayerSchema,
  PowerUpSchema,
} from './schema/ArenaState';
import { getBladeSpec, BLADE_CATALOG } from '../shared/BladeCatalog';
import {
  getMapConfig,
  MapConfig,
  resolveWallCollisions,
  bladeHitsWall,
  isInsideBush,
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

export class GameClient {
  sessionId: string;
  ws: WebSocket;

  constructor(sessionId: string, ws: WebSocket) {
    this.sessionId = sessionId;
    this.ws = ws;
  }

  send(type: string, data: any) {
    if (this.ws.readyState === 1 /* OPEN */) {
      this.ws.send(JSON.stringify({ type, data }));
    }
  }
}

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

export class ArenaRoom {
  public state = new ArenaState();
  private clients = new Map<string, GameClient>();
  private mapConfig!: MapConfig;
  private powerSpawnTimer = 3.0;
  private nextPowerId = 1;
  private broadcastInterval = 0;
  private tickInterval: any;
  private targetBotCount: number = 3;

  constructor(options?: { mapId?: string }) {
    const mapId = options?.mapId || 'temple';
    this.mapConfig = getMapConfig(mapId);

    this.state.mapId = mapId;
    this.state.matchTime = 0;

    // 30Hz Simulation Tick Rate
    this.tickInterval = setInterval(() => {
      this.update(1 / 30);
    }, 1000 / 30);
  }

  public handleConnection(client: GameClient) {
    this.clients.set(client.sessionId, client);

    client.ws.on('message', (raw: any) => {
      try {
        const parsed = JSON.parse(raw.toString());
        const type = parsed.type;
        const data = parsed.data || {};

        if (type === 'join') {
          this.onJoin(client, data);
        } else if (type === 'move') {
          const player = this.state.players.get(client.sessionId);
          if (!player) return;
          const mag = Math.hypot(data.dx || 0, data.dy || 0);
          if (mag > 1) {
            player.inputDx = (data.dx || 0) / mag;
            player.inputDy = (data.dy || 0) / mag;
          } else {
            player.inputDx = data.dx || 0;
            player.inputDy = data.dy || 0;
          }
          if (mag > 0.05) {
            player.facing = Math.atan2(player.inputDy, player.inputDx);
          }
        } else if (type === 'throw') {
          const player = this.state.players.get(client.sessionId);
          if (!player) return;
          this.throwBlade(player);
        } else if (type === 'ping') {
          client.send('pong', { clientTime: data?.t || 0, serverTime: Date.now() });
        }
      } catch (err) {
        console.error('Error parsing client message:', err);
      }
    });

    client.ws.on('close', () => {
      this.onLeave(client);
    });

    client.ws.on('error', (err) => {
      console.warn(`Client ${client.sessionId} socket error:`, err);
    });
  }

  broadcast(type: string, data: any) {
    const payload = JSON.stringify({ type, data });
    for (const client of this.clients.values()) {
      if (client.ws.readyState === 1 /* OPEN */) {
        client.ws.send(payload);
      }
    }
  }

  private onJoin(client: GameClient, options: { name?: string; bladeId?: string; mapId?: string; botCount?: number | string }) {
    const name = (options?.name || 'Player_' + client.sessionId.substring(0, 4)).trim();
    const bladeId = options?.bladeId || 'steel';
    if (options?.botCount !== undefined) {
      const parsedCount = parseInt(String(options.botCount), 10);
      if (!isNaN(parsedCount)) {
        this.targetBotCount = Math.max(0, Math.min(10, parsedCount));
      }
    }

    const player = new PlayerSchema();
    player.id = client.sessionId;
    player.name = name;
    player.bladeId = bladeId;
    player.isBot = false;
    player.radius = 22;
    player.hp = 100;
    player.maxHp = 100;
    player.speed = 265;

    // Random safe spawn position
    this.respawnPlayer(player);

    const spec = getBladeSpec(bladeId);
    player.blade.state = 'orbit';
    player.blade.angle = Math.random() * Math.PI * 2;
    player.blade.spin = player.blade.angle;
    player.blade.x = player.x + spec.rx * Math.cos(player.blade.angle);
    player.blade.y = player.y + spec.ry * Math.sin(player.blade.angle);

    this.state.players.set(client.sessionId, player);

    // Welcome packet
    client.send('init', {
      sessionId: client.sessionId,
      mapId: this.state.mapId,
      arenaSize: this.mapConfig.size,
    });

    console.log(`[ArenaRoom] Player "${name}" (${client.sessionId}) joined. Total human clients: ${Array.from(this.state.players.values()).filter(p => !p.isBot).length}`);
    this.reconcileBots();
  }

  private onLeave(client: GameClient) {
    const p = this.state.players.get(client.sessionId);
    if (p) {
      console.log(`[ArenaRoom] Player "${p.name}" (${client.sessionId}) left.`);
      this.state.players.delete(client.sessionId);
    }
    this.clients.delete(client.sessionId);
    this.reconcileBots();
  }

  public dispose() {
    if (this.tickInterval) clearInterval(this.tickInterval);
  }

  // --- BOT MANAGEMENT ---
  private reconcileBots() {
    let humanCount = 0;
    const botKeys: string[] = [];

    this.state.players.forEach((p: PlayerSchema, key: string) => {
      if (p.isBot) botKeys.push(key);
      else humanCount++;
    });

    const neededBots = Math.max(0, this.targetBotCount);

    // Remove excess bots
    while (botKeys.length > neededBots) {
      const keyToRemove = botKeys.pop();
      if (keyToRemove) this.state.players.delete(keyToRemove);
    }

    // Add missing bots
    while (botKeys.length < neededBots) {
      const idx = botKeys.length;
      const botId = `bot_${idx}_${Date.now().toString(36)}`;
      const botName = BOT_NAMES[idx % BOT_NAMES.length];
      const botBlade = BLADE_CATALOG[idx % BLADE_CATALOG.length].id;

      const bot = new PlayerSchema();
      bot.id = botId;
      bot.name = botName;
      bot.bladeId = botBlade;
      bot.isBot = true;
      bot.radius = 22;
      bot.hp = 100;
      bot.maxHp = 100;
      bot.speed = 195;
      bot.kills = Math.floor(Math.random() * 2);

      this.respawnPlayer(bot);

      const spec = getBladeSpec(botBlade);
      bot.blade.state = 'orbit';
      bot.blade.angle = Math.random() * Math.PI * 2;
      bot.blade.spin = bot.blade.angle;
      bot.blade.x = bot.x + spec.rx * Math.cos(bot.blade.angle);
      bot.blade.y = bot.y + spec.ry * Math.sin(bot.blade.angle);

      bot.botMoveTimer = 1.0 + Math.random() * 2;
      bot.botThrowCd = 2.0 + Math.random() * 2;
      const angle = Math.random() * Math.PI * 2;
      bot.botDirX = Math.cos(angle);
      bot.botDirY = Math.sin(angle);

      this.state.players.set(botId, bot);
      botKeys.push(botId);
    }
  }

  private respawnPlayer(player: PlayerSchema) {
    const a = Math.random() * Math.PI * 2;
    const dist = 250 + Math.random() * 380;
    player.x = Math.cos(a) * dist;
    player.y = Math.sin(a) * dist;
    player.hp = player.maxHp;
    player.dmgTimer = 0;
    player.shieldTimer = 0;
    player.inputDx = 0;
    player.inputDy = 0;
    resolveWallCollisions(player, this.mapConfig);
  }

  private throwBlade(player: PlayerSchema) {
    const b = player.blade;
    if (b.state !== 'orbit') return;

    const spec = getBladeSpec(player.bladeId);
    b.state = 'out';
    b.traveled = 0;
    b.frozenAngle = b.angle;
    b.x = player.x + spec.rx * Math.cos(b.frozenAngle);
    b.y = player.y + spec.ry * Math.sin(b.frozenAngle);
    b.dirX = Math.cos(b.frozenAngle);
    b.dirY = Math.sin(b.frozenAngle);
  }

  // --- MAIN SIMULATION TICK ---
  private update(dt: number) {
    this.state.matchTime += dt;

    // 1. Power-Ups Spawning & Pickup
    this.powerSpawnTimer -= dt;
    if (this.powerSpawnTimer <= 0 && this.state.powerUps.length < 2) {
      const types: PowerUpType[] = ['DAMAGE', 'HEAL', 'SHIELD'];
      const p = new PowerUpSchema();
      p.id = `pow_${this.nextPowerId++}`;
      p.x = (Math.random() - 0.5) * 200;
      p.y = (Math.random() - 0.5) * 200;
      p.type = types[Math.floor(Math.random() * types.length)];
      this.state.powerUps.push(p);
      this.powerSpawnTimer = 7.5;

      this.broadcast('powerup_spawn', { id: p.id, x: p.x, y: p.y, type: p.type });
    }

    // Check power-up collection
    for (let i = this.state.powerUps.length - 1; i >= 0; i--) {
      const pow = this.state.powerUps[i];
      let collected = false;

      this.state.players.forEach((player: PlayerSchema) => {
        if (collected) return;
        const dist = Math.hypot(player.x - pow.x, player.y - pow.y);
        if (dist < player.radius + 18) {
          collected = true;
          if (pow.type === 'DAMAGE') player.dmgTimer = 8;
          else if (pow.type === 'HEAL') player.hp = Math.min(player.maxHp, player.hp + 45);
          else if (pow.type === 'SHIELD') player.shieldTimer = 6;

          const evt: PowerUpEvent = {
            playerId: player.id,
            type: pow.type as PowerUpType,
            x: pow.x,
            y: pow.y,
          };
          this.broadcast('powerup', evt);
        }
      });

      if (collected) {
        this.state.powerUps.splice(i, 1);
      }
    }

    // 2. Update Players & Bots
    this.state.players.forEach((player: PlayerSchema) => {
      if (player.dmgTimer > 0) player.dmgTimer = Math.max(0, player.dmgTimer - dt);
      if (player.shieldTimer > 0) player.shieldTimer = Math.max(0, player.shieldTimer - dt);

      // AI Bot Logic
      if (player.isBot) {
        this.updateBotAI(player, dt);
      }

      // Movement
      player.x += player.inputDx * player.speed * dt;
      player.y += player.inputDy * player.speed * dt;
      resolveWallCollisions(player, this.mapConfig);

      // Bush stealth status (player center inside bush AND blade is in orbit)
      player.isHidden = isInsideBush(player.x, player.y, this.mapConfig) && player.blade.state === 'orbit';

      // Blade Physics
      this.updateBladePhysics(player, dt);
    });

    // 3. High-Rate State Snapshot Broadcast (30Hz)
    this.broadcastInterval += dt;
    if (this.broadcastInterval >= 1 / 30) {
      this.broadcastInterval = 0;
      this.broadcastStateSnapshot();
    }
  }

  private updateBotAI(bot: PlayerSchema, dt: number) {
    bot.botMoveTimer -= dt;
    bot.botThrowCd -= dt;

    let nearestDist = 99999;
    let targetPlayer: PlayerSchema | null = null;

    this.state.players.forEach((other: PlayerSchema) => {
      if (other.id === bot.id) return;
      if (other.isHidden) return;
      const dist = Math.hypot(other.x - bot.x, other.y - bot.y);
      if (dist < nearestDist) {
        nearestDist = dist;
        targetPlayer = other;
      }
    });

    if (targetPlayer && nearestDist < 520) {
      const tp = targetPlayer as PlayerSchema;
      const dx = tp.x - bot.x;
      const dy = tp.y - bot.y;
      const d = nearestDist || 1;
      bot.inputDx = dx / d;
      bot.inputDy = dy / d;

      const spec = getBladeSpec(bot.bladeId);
      if (bot.botThrowCd <= 0 && nearestDist < spec.range * 0.95 && bot.blade.state === 'orbit') {
        const toTarget = Math.atan2(dy, dx);
        const diff = Math.abs(Math.atan2(Math.sin(bot.blade.angle - toTarget), Math.cos(bot.blade.angle - toTarget)));
        if (diff < 0.24) {
          this.throwBlade(bot);
          bot.botThrowCd = 2.4 + Math.random() * 1.5;
        }
      }
    } else {
      if (bot.botMoveTimer <= 0) {
        const a = Math.random() * Math.PI * 2;
        bot.botDirX = Math.cos(a);
        bot.botDirY = Math.sin(a);
        bot.botMoveTimer = 1.8 + Math.random() * 2.5;
      }
      bot.inputDx = bot.botDirX;
      bot.inputDy = bot.botDirY;
    }
  }

  private updateBladePhysics(player: PlayerSchema, dt: number) {
    const spec = getBladeSpec(player.bladeId);
    const b = player.blade;

    const anchorX = player.x + spec.rx * Math.cos(b.frozenAngle);
    const anchorY = player.y + spec.ry * Math.sin(b.frozenAngle);

    if (b.state === 'orbit') {
      b.angle = (b.angle + spec.orbitSpeed * dt) % (Math.PI * 2);
      b.spin = b.angle;
      b.x = player.x + spec.rx * Math.cos(b.angle);
      b.y = player.y + spec.ry * Math.sin(b.angle);
      b.frozenAngle = b.angle;
    } else if (b.state === 'out') {
      b.spin += 18 * dt;
      const step = spec.throwSpeed * dt;
      b.x += b.dirX * step;
      b.y += b.dirY * step;
      b.traveled += step;

      // 1. Check Wall Hit
      if (bladeHitsWall(b.x, b.y, this.mapConfig, 11)) {
        b.state = 'return';
        this.broadcast('hit', {
          x: b.x,
          y: b.y,
          damage: 0,
          targetId: 'wall',
          attackerId: player.id,
          color: '#94a3b8',
        } as HitEvent);
      }
      // 2. Check Range Exceeded
      else if (b.traveled >= spec.range) {
        b.state = 'return';
      }
      // 3. Check Opponent Hit
      else {
        this.state.players.forEach((target: PlayerSchema) => {
          if (target.id === player.id) return;
          if (b.state !== 'out') return;

          const dist = Math.hypot(b.x - target.x, b.y - target.y);
          if (dist < target.radius + 15) {
            b.state = 'return';

            if (target.shieldTimer > 0) {
              this.broadcast('hit', {
                x: target.x,
                y: target.y,
                damage: 0,
                targetId: target.id,
                attackerId: player.id,
                color: '#38bdf8',
              } as HitEvent);
            } else {
              const damage = spec.damage * (player.dmgTimer > 0 ? 2 : 1);
              target.hp = Math.max(0, target.hp - damage);

              const hitEvt: HitEvent = {
                x: target.x,
                y: target.y,
                damage,
                targetId: target.id,
                attackerId: player.id,
                color: spec.bladeColor,
              };
              this.broadcast('hit', hitEvt);

              if (target.hp <= 0) {
                player.kills++;
                const killEvt: KillEvent = {
                  killerId: player.id,
                  victimId: target.id,
                  killerName: player.name,
                  victimName: target.name,
                  goldAwarded: 50,
                };
                this.broadcast('kill', killEvt);

                // Respawn victim
                this.respawnPlayer(target);
              }
            }
          }
        });
      }
    } else if (b.state === 'return') {
      b.spin += 18 * dt;
      const dx = anchorX - b.x;
      const dy = anchorY - b.y;
      const dist = Math.hypot(dx, dy);
      const step = spec.throwSpeed * 1.25 * dt;

      if (dist <= step + 12) {
        b.x = anchorX;
        b.y = anchorY;
        b.angle = b.frozenAngle;
        b.state = 'orbit';
      } else {
        b.x += (dx / dist) * step;
        b.y += (dy / dist) * step;
      }
    }
  }

  private broadcastStateSnapshot() {
    const playersList: PlayerNetData[] = [];

    this.state.players.forEach((p: PlayerSchema) => {
      playersList.push({
        id: p.id,
        name: p.name,
        x: Math.round(p.x * 10) / 10,
        y: Math.round(p.y * 10) / 10,
        facing: Math.round((p.facing || 0) * 1000) / 1000,
        radius: p.radius,
        hp: p.hp,
        maxHp: p.maxHp,
        kills: p.kills,
        isBot: p.isBot,
        bladeId: p.bladeId,
        bladeState: p.blade.state as 'orbit' | 'out' | 'return',
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
    this.state.powerUps.forEach((pow: PowerUpSchema) => {
      powerUpsList.push({
        id: pow.id,
        x: Math.round(pow.x * 10) / 10,
        y: Math.round(pow.y * 10) / 10,
        type: pow.type as PowerUpType,
      });
    });

    const snapshot: StateSnapshot = {
      t: Date.now(),
      players: playersList,
      powerUps: powerUpsList,
      matchTime: Math.round(this.state.matchTime),
    };

    this.broadcast('sync', snapshot);
  }
}
