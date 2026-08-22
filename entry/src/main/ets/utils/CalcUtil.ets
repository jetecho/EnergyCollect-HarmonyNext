import { Session } from '../model/Session';
import { SessionType } from '../model/SessionType';
import { ChartPoint } from '../model/ChartPoint';

export class CalcUtil {
  static consumption(s: Session): number {
    if (!s.isCompleted()) {
      return 0;
    }
    return s.startBattery - s.endBattery;
  }

  static totalDrain(sessions: Session[]): number {
    let total: number = 0;
    for (const s of sessions) {
      if (s.isCompleted() && s.type === SessionType.USAGE) {
        total += CalcUtil.consumption(s);
      }
    }
    return total;
  }

  static totalCharge(sessions: Session[]): number {
    let total: number = 0;
    for (const s of sessions) {
      if (s.isCompleted() && s.type === SessionType.CHARGING) {
        total += s.endBattery - s.startBattery;
      }
    }
    return total;
  }

  static toChartPoints(sessions: Session[]): ChartPoint[] {
    const points: ChartPoint[] = [];
    const sorted: Session[] = sessions.slice().sort((a: Session, b: Session): number => a.startTime - b.startTime);
    for (const s of sorted) {
      points.push(new ChartPoint(s.startTime, s.startBattery, s));
      if (s.isCompleted()) {
        points.push(new ChartPoint(s.endTime, s.endBattery, s));
      }
    }
    return points;
  }

  /** 电量百分比合计换算为 kWh（capacityKwh 为电池容量，非正容量返回 0） */
  static toKwh(batteryPercent: number, capacityKwh: number): number {
    if (capacityKwh <= 0) {
      return 0;
    }
    return batteryPercent * capacityKwh / 100;
  }
}
