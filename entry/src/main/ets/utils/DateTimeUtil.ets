export class DateTimeUtil {
  static pad(n: number): string {
    return n < 10 ? '0' + n : '' + n;
  }

  static formatDateTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '--';
    }
    const d: Date = new Date(timestamp);
    return DateTimeUtil.pad(d.getMonth() + 1) + '-' + DateTimeUtil.pad(d.getDate()) + ' ' +
      DateTimeUtil.pad(d.getHours()) + ':' + DateTimeUtil.pad(d.getMinutes());
  }

  static pad3(n: number): string {
    if (n < 10) {
      return '00' + n;
    }
    if (n < 100) {
      return '0' + n;
    }
    return '' + n;
  }

  static formatDateTimeMs(timestamp: number): string {
    if (timestamp <= 0) {
      return '--';
    }
    const d: Date = new Date(timestamp);
    return DateTimeUtil.pad(d.getMonth() + 1) + '-' + DateTimeUtil.pad(d.getDate()) + ' ' +
      DateTimeUtil.pad(d.getHours()) + ':' + DateTimeUtil.pad(d.getMinutes()) + ':' +
      DateTimeUtil.pad(d.getSeconds()) + '.' + DateTimeUtil.pad3(d.getMilliseconds());
  }

  static formatDate(timestamp: number): string {
    if (timestamp <= 0) {
      return '--';
    }
    const d: Date = new Date(timestamp);
    return DateTimeUtil.pad(d.getMonth() + 1) + '-' + DateTimeUtil.pad(d.getDate());
  }

  static formatTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '--';
    }
    const d: Date = new Date(timestamp);
    return DateTimeUtil.pad(d.getHours()) + ':' + DateTimeUtil.pad(d.getMinutes());
  }

  static formatDuration(ms: number): ResourceStr {
    if (ms <= 0) {
      return $r('app.string.duration_format_s', 0);
    }
    const totalSec: number = Math.floor(ms / 1000);
    const hours: number = Math.floor(totalSec / 3600);
    const minutes: number = Math.floor((totalSec % 3600) / 60);
    const seconds: number = totalSec % 60;
    if (hours > 0) {
      return $r('app.string.duration_format_hm', hours, minutes);
    }
    if (minutes > 0) {
      return $r('app.string.duration_format_ms', minutes, seconds);
    }
    return $r('app.string.duration_format_s', seconds);
  }

  static formatClock(ms: number): string {
    if (ms < 0) {
      ms = 0;
    }
    const totalSec: number = Math.floor(ms / 1000);
    const hours: number = Math.floor(totalSec / 3600);
    const minutes: number = Math.floor((totalSec % 3600) / 60);
    const seconds: number = totalSec % 60;
    return DateTimeUtil.pad(hours) + ':' + DateTimeUtil.pad(minutes) + ':' + DateTimeUtil.pad(seconds);
  }

  static startOfToday(now: number = Date.now()): number {
    const d: Date = new Date(now);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  static startOfWeek(now: number = Date.now()): number {
    const d: Date = new Date(now);
    const day: number = d.getDay();
    const diff: number = day === 0 ? 6 : day - 1;
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() - diff);
    return d.getTime();
  }

  static startOfMonth(now: number = Date.now()): number {
    const d: Date = new Date(now);
    d.setDate(1);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  static formatAxisTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '';
    }
    const d: Date = new Date(timestamp);
    const now: Date = new Date();
    if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()) {
      return DateTimeUtil.pad(d.getHours()) + ':' + DateTimeUtil.pad(d.getMinutes());
    }
    return (d.getMonth() + 1) + '/' + d.getDate();
  }
}
