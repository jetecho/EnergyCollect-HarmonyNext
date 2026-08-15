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

  static durationMs(s: Session, now: number): number {
    const end: number = s.endTime > 0 ? s.endTime : now;
    return end - s.startTime;
  }

  static drainRatePerHour(s: Session): number {
    if (!s.isCompleted()) {
      return -1;
    }
    const durationMs: number = s.endTime - s.startTime;
    if (durationMs <= 0) {
      return -1;
    }
    const hours: number = durationMs / 3600000;
    return CalcUtil.consumption(s) / hours;
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

  static averageIdleRate(sessions: Session[]): number {
    let sum: number = 0;
    let count: number = 0;
    for (const s of sessions) {
      if (s.isCompleted() && s.type === SessionType.IDLE) {
        const rate: number = CalcUtil.drainRatePerHour(s);
        if (rate >= 0) {
          sum += rate;
          count++;
        }
      }
    }
    if (count === 0) {
      return -1;
    }
    return sum / count;
  }

  static averageIdleRateFromSessions(sessions: Session[]): number {
    const anchors: Session[] = [];
    for (const s of sessions) {
      if (s.isCompleted() && (s.type === SessionType.USAGE || s.type === SessionType.CHARGING)) {
        anchors.push(s);
      }
    }
    anchors.sort((a: Session, b: Session): number => a.startTime - b.startTime);
    let sum: number = 0;
    let count: number = 0;
    for (let i = 0; i < anchors.length - 1; i++) {
      const prev: Session = anchors[i];
      const next: Session = anchors[i + 1];
      const drain: number = prev.endBattery - next.startBattery;
      const idleMs: number = next.startTime - prev.endTime;
      if (drain > 0 && idleMs > 0) {
        const hours: number = idleMs / 3600000;
        sum += drain / hours;
        count++;
      }
    }
    if (count === 0) {
      return -1;
    }
    return sum / count;
  }

  static averageUsageRate(sessions: Session[]): number {
    let sum: number = 0;
    let count: number = 0;
    for (const s of sessions) {
      if (s.isCompleted() && s.type === SessionType.USAGE) {
        const rate: number = CalcUtil.drainRatePerHour(s);
        if (rate >= 0) {
          sum += rate;
          count++;
        }
      }
    }
    if (count === 0) {
      return -1;
    }
    return sum / count;
  }

  static countToday(sessions: Session[], startOfToday: number): number {
    let count: number = 0;
    for (const s of sessions) {
      if (s.startTime >= startOfToday) {
        count++;
      }
    }
    return count;
  }

  static drainToday(sessions: Session[], startOfToday: number): number {
    let total: number = 0;
    for (const s of sessions) {
      if (s.isCompleted() && s.endTime >= startOfToday && s.type === SessionType.USAGE) {
        total += CalcUtil.consumption(s);
      }
    }
    return total;
  }

  static chargeToday(sessions: Session[], startOfToday: number): number {
    let total: number = 0;
    for (const s of sessions) {
      if (s.isCompleted() && s.endTime >= startOfToday && s.type === SessionType.CHARGING) {
        total += s.endBattery - s.startBattery;
      }
    }
    return total;
  }

  static toChartPoints(sessions: Session[]): ChartPoint[] {
    const points: ChartPoint[] = [];
    const sorted: Session[] = sessions.slice().sort((a: Session, b: Session): number => a.startTime - b.startTime);
    for (const s of sorted) {
      points.push(new ChartPoint(s.startTime, s.startBattery, DateTimeUtilFmt(s.startTime)));
      if (s.isCompleted()) {
        points.push(new ChartPoint(s.endTime, s.endBattery, DateTimeUtilFmt(s.endTime)));
      }
    }
    return points;
  }
}

function DateTimeUtilFmt(t: number): string {
  const d: Date = new Date(t);
  const pad = (n: number): string => n < 10 ? '0' + n : '' + n;
  return pad(d.getMonth() + 1) + '/' + pad(d.getDate());
}
