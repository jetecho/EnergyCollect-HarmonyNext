const KEY_HOME: string = 'homeDataVersion';
const KEY_HISTORY: string = 'historyDataVersion';
const KEY_MINE: string = 'mineDataVersion';

function bump(key: string): void {
  const v: number = AppStorage.get<number>(key) ?? 0;
  AppStorage.setOrCreate(key, v + 1);
}

/**
 * 按 Tab 定向的数据变更通知。
 * 取代单一 dataVersion 全局 bump：写操作只通知受影响的 Tab，
 * 避免任何一次小改动（如编辑备注）触发三个 Tab 全部重新查库。
 */
export class DataNotifier {
  static init(): void {
    AppStorage.setOrCreate(KEY_HOME, 0);
    AppStorage.setOrCreate(KEY_HISTORY, 0);
    AppStorage.setOrCreate(KEY_MINE, 0);
  }

  /** 首页（设备卡片、今日统计） */
  static notifyHome(): void {
    bump(KEY_HOME);
  }

  /** 历史页（图表、会话列表、统计） */
  static notifyHistory(): void {
    bump(KEY_HISTORY);
  }

  /** 我的页（设备管理列表、默认设备徽标） */
  static notifyMine(): void {
    bump(KEY_MINE);
  }

  /** 设备增删改/清空/导入等影响全部 Tab 的操作 */
  static notifyAll(): void {
    bump(KEY_HOME);
    bump(KEY_HISTORY);
    bump(KEY_MINE);
  }
}
