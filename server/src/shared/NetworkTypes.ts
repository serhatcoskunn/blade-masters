export type BladeState = 'orbit' | 'out' | 'return';
export type PowerUpType = 'DAMAGE' | 'HEAL' | 'SHIELD';

export interface PlayerNetData {
  id: string;
  name: string;
  x: number;
  y: number;
  facing: number;
  radius: number;
  hp: number;
  maxHp: number;
  kills: number;
  isBot: boolean;
  bladeId: string;
  bladeState: BladeState;
  bladeAngle: number;
  bladeSpin: number;
  bladeX: number;
  bladeY: number;
  frozenAngle: number;
  dmgTimer: number;
  shieldTimer: number;
  isHidden: boolean;
}

export interface PowerUpNetData {
  id: string;
  x: number;
  y: number;
  type: PowerUpType;
}

export interface StateSnapshot {
  t: number; // server timestamp
  players: PlayerNetData[];
  powerUps: PowerUpNetData[];
  matchTime: number;
}

export interface ClientMoveMessage {
  dx: number;
  dy: number;
}

export interface ClientThrowMessage {
  // empty trigger
}

export interface ClientJoinMessage {
  name: string;
  bladeId: string;
  mapId: string;
}

export interface HitEvent {
  x: number;
  y: number;
  damage: number;
  targetId: string;
  attackerId: string;
  color: string;
}

export interface KillEvent {
  killerId: string;
  victimId: string;
  killerName: string;
  victimName: string;
  goldAwarded: number;
}

export interface PowerUpEvent {
  playerId: string;
  type: PowerUpType;
  x: number;
  y: number;
}
