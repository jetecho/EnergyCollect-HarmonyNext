import { describe, it, expect } from '@ohos/hypium';
import { CalcUtil } from '../../../main/ets/utils/CalcUtil';
import { DateTimeUtil } from '../../../main/ets/utils/DateTimeUtil';
import { Session } from '../../../main/ets/model/Session';
import { SessionType } from '../../../main/ets/model/SessionType';
import { ChartPoint } from '../../../main/ets/model/ChartPoint';

/** 以本地时区构造时间戳（month 为 1 基），保证断言与时区无关 */
function at(year: number, month: number, day: number, hour: number, minute: number, second: number): number {
  return new Date(year, month - 1, day, hour, minute, second).getTime();
}

function mkSession(type: SessionType, startBattery: number, endBattery: number,
  startTime: number, endTime: number): Session {
  const s: Session = new Session();
  s.type = type;
  s.startBattery = startBattery;
  s.endBattery = endBattery;
  s.startTime = startTime;
  s.endTime = endTime;
  return s;
}

export default function localUnitTest() {
  describe('SessionModelTest', () => {
    it('isActiveWhenEndTimeZero', 0, () => {
      const s: Session = mkSession(SessionType.USAGE, 80, -1, 1000, 0);
      expect(s.isActive()).assertTrue();
      expect(s.isCompleted()).assertFalse();
    });

    it('isCompletedNeedsEndTimeAndBattery', 0, () => {
      const s: Session = mkSession(SessionType.USAGE, 80, 50, 1000, 2000);
      expect(s.isActive()).assertFalse();
      expect(s.isCompleted()).assertTrue();
      // 有结束时间但电量未记录（-1）不算已完成
      const noBattery: Session = mkSession(SessionType.USAGE, 80, -1, 1000, 2000);
      expect(noBattery.isCompleted()).assertFalse();
    });
  });

  describe('CalcUtilTest', () => {
    it('consumptionCompletedOnly', 0, () => {
      expect(CalcUtil.consumption(mkSession(SessionType.USAGE, 80, 50, 1, 2))).assertEqual(30);
      expect(CalcUtil.consumption(mkSession(SessionType.USAGE, 80, -1, 1, 0))).assertEqual(0);
    });

    it('totalDrainCountsUsageOnly', 0, () => {
      const list: Session[] = [
        mkSession(SessionType.USAGE, 80, 50, 1, 2),
        mkSession(SessionType.USAGE, 60, 20, 3, 4),
        mkSession(SessionType.CHARGING, 20, 90, 5, 6),
        mkSession(SessionType.IDLE, 90, 80, 7, 8),
        mkSession(SessionType.USAGE, 40, 10, 9, 0)
      ];
      expect(CalcUtil.totalDrain(list)).assertEqual(70);
    });

    it('totalChargeSumsCompletedCharging', 0, () => {
      const list: Session[] = [
        mkSession(SessionType.CHARGING, 20, 90, 1, 2),
        mkSession(SessionType.CHARGING, 30, 35, 3, 4),
        mkSession(SessionType.CHARGING, 50, 60, 5, 0),
        mkSession(SessionType.USAGE, 90, 40, 6, 7)
      ];
      expect(CalcUtil.totalCharge(list)).assertEqual(75);
    });

    it('toChartPointsSortedWithSessionOwner', 0, () => {
      const a: Session = mkSession(SessionType.USAGE, 80, 50, at(2026, 8, 22, 9, 0, 0), at(2026, 8, 22, 10, 0, 0));
      const b: Session = mkSession(SessionType.USAGE, 60, -1, at(2026, 8, 22, 8, 0, 0), 0);
      const points: ChartPoint[] = CalcUtil.toChartPoints([a, b]);
      expect(points.length).assertEqual(3);
      // 输入乱序，输出按开始时间升序：b.start、a.start、a.end
      expect(points[0].time === b.startTime && points[0].value === 60).assertTrue();
      expect(points[1].time === a.startTime && points[1].value === 80).assertTrue();
      expect(points[2].time === a.endTime && points[2].value === 50).assertTrue();
      // 每个点位携带归属会话：相邻会话衔接点（前一结束 = 后一开始）不再因时间戳相同互相覆盖
      expect(points[0].session === b).assertTrue();
      expect(points[1].session === a).assertTrue();
      expect(points[2].session === a).assertTrue();
    });

    it('toKwh', 0, () => {
      expect(CalcUtil.toKwh(30, 60)).assertEqual(18);
      expect(CalcUtil.toKwh(75, 70)).assertEqual(52.5);
      expect(CalcUtil.toKwh(30, 0)).assertEqual(0);
      expect(CalcUtil.toKwh(30, -5)).assertEqual(0);
    });
  });

  describe('DateTimeUtilTest', () => {
    it('padAndPad3', 0, () => {
      expect(DateTimeUtil.pad(3)).assertEqual('03');
      expect(DateTimeUtil.pad(15)).assertEqual('15');
      expect(DateTimeUtil.pad3(3)).assertEqual('003');
      expect(DateTimeUtil.pad3(45)).assertEqual('045');
      expect(DateTimeUtil.pad3(678)).assertEqual('678');
    });

    it('formatDateTime', 0, () => {
      expect(DateTimeUtil.formatDateTime(0)).assertEqual('--');
      expect(DateTimeUtil.formatDateTime(at(2026, 8, 22, 9, 5, 0))).assertEqual('08-22 09:05');
    });

    it('formatDateTimeMs', 0, () => {
      const d: Date = new Date(2026, 7, 22, 9, 5, 3);
      d.setMilliseconds(7);
      expect(DateTimeUtil.formatDateTimeMs(d.getTime())).assertEqual('08-22 09:05:03.007');
    });

    it('formatDateAndTime', 0, () => {
      expect(DateTimeUtil.formatDate(at(2026, 8, 22, 9, 5, 0))).assertEqual('08-22');
      expect(DateTimeUtil.formatTime(at(2026, 8, 22, 9, 5, 0))).assertEqual('09:05');
    });

    it('formatClock', 0, () => {
      expect(DateTimeUtil.formatClock(0)).assertEqual('00:00:00');
      expect(DateTimeUtil.formatClock(-5)).assertEqual('00:00:00');
      expect(DateTimeUtil.formatClock(3661000)).assertEqual('01:01:01');
    });

    it('startOfToday', 0, () => {
      expect(DateTimeUtil.startOfToday(at(2026, 8, 22, 15, 30, 12))).assertEqual(at(2026, 8, 22, 0, 0, 0));
    });

    it('startOfWeekMondayBased', 0, () => {
      // 2026-08-22 为周六、08-23 为周日，均应归到周一 08-17 零点
      expect(DateTimeUtil.startOfWeek(at(2026, 8, 22, 10, 0, 0))).assertEqual(at(2026, 8, 17, 0, 0, 0));
      expect(DateTimeUtil.startOfWeek(at(2026, 8, 23, 10, 0, 0))).assertEqual(at(2026, 8, 17, 0, 0, 0));
      // 周一零点归当天
      expect(DateTimeUtil.startOfWeek(at(2026, 8, 17, 0, 0, 0))).assertEqual(at(2026, 8, 17, 0, 0, 0));
      // 跨月周：08-01（周六）应归到 07-27（周一）
      expect(DateTimeUtil.startOfWeek(at(2026, 8, 1, 12, 0, 0))).assertEqual(at(2026, 7, 27, 0, 0, 0));
    });

    it('startOfMonth', 0, () => {
      expect(DateTimeUtil.startOfMonth(at(2026, 8, 22, 15, 0, 0))).assertEqual(at(2026, 8, 1, 0, 0, 0));
      expect(DateTimeUtil.startOfMonth(at(2026, 8, 31, 23, 59, 59))).assertEqual(at(2026, 8, 1, 0, 0, 0));
    });
  });
}
