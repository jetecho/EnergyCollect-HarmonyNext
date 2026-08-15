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

  static formatDuration(ms: number): string {
    if (ms <= 0) {
      return '0分';
    }
    const totalSec: number = Math.floor(ms / 1000);
    const hours: number = Math.floor(totalSec / 3600);
    const minutes: number = Math.floor((totalSec % 3600) / 60);
    const seconds: number = totalSec % 60;
    if (hours > 0) {
      return hours + '时' + minutes + '分';
    }
    if (minutes > 0) {
      return minutes + '分' + seconds + '秒';
    }
    return seconds + '秒';
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

  static startOfToday(): number {
    const d: Date = new Date();
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }
}
