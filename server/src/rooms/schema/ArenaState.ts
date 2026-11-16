import { Schema, type, MapSchema, ArraySchema } from '@colyseus/schema';

export class BladeStateSchema extends Schema {
  @type('string') state: string = 'orbit'; // 'orbit' | 'out' | 'return'
  @type('number') angle: number = 0;
  @type('number') spin: number = 0;
  @type('number') x: number = 0;
  @type('number') y: number = 0;
  @type('number') dirX: number = 0;
  @type('number') dirY: number = 0;
  @type('number') traveled: number = 0;
  @type('number') frozenAngle: number = 0;
}

export class PlayerSchema extends Schema {
  @type('string') id: string = '';
  @type('string') name: string = '';
  @type('number') x: number = 0;
  @type('number') y: number = 0;
  @type('number') facing: number = 0;
  @type('number') radius: number = 24;
  @type('number') hp: number = 100;
  @type('number') maxHp: number = 100;
  @type('number') kills: number = 0;
  @type('boolean') isBot: boolean = false;
  @type('string') bladeId: string = 'steel';
  @type('number') dmgTimer: number = 0;
  @type('number') shieldTimer: number = 0;
  @type('boolean') isHidden: boolean = false;
  @type(BladeStateSchema) blade: BladeStateSchema = new BladeStateSchema();

  // Internal server properties (not synced over schema)
  inputDx: number = 0;
  inputDy: number = 0;
  speed: number = 270;
  flashTimer: number = 0;
  botMoveTimer: number = 0;
  botThrowCd: number = 0;
  botDirX: number = 0;
  botDirY: number = 0;
}

export class PowerUpSchema extends Schema {
  @type('string') id: string = '';
  @type('number') x: number = 0;
  @type('number') y: number = 0;
  @type('string') type: string = 'DAMAGE'; // 'DAMAGE' | 'HEAL' | 'SHIELD'
}

export class ArenaState extends Schema {
  @type('string') mapId: string = 'temple';
  @type('number') matchTime: number = 180; // 3 minute match
  @type({ map: PlayerSchema }) players = new MapSchema<PlayerSchema>();
  @type([PowerUpSchema]) powerUps = new ArraySchema<PowerUpSchema>();
}
