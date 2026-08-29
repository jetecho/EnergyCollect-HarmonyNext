import { SessionType } from './SessionType';

export class Session {
  id: number = 0;
  deviceId: number = 0;
  type: SessionType = SessionType.USAGE;
  startBattery: number = 0;
  endBattery: number = -1;
  startTime: number = 0;
  endTime: number = 0;
  note: string = '';
  createdAt: number = 0;
  startRange: number = -1;
  endRange: number = -1;
  /** 会话来源：manual 手动 / auto_bt 蓝牙连接自动 / auto_charge 充电状态自动 */
  source: string = 'manual';

  isActive(): boolean {
    return this.endTime === 0;
  }

  isCompleted(): boolean {
    return this.endTime > 0 && this.endBattery >= 0;
  }
}
