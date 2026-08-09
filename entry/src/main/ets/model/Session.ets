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

  isActive(): boolean {
    return this.endTime === 0;
  }

  isCompleted(): boolean {
    return this.endTime > 0 && this.endBattery >= 0;
  }
}
