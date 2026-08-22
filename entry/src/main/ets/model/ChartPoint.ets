import { Session } from './Session';

export class ChartPoint {
  time: number = 0;
  value: number = 0;
  /** 点位归属的会话（起/止电量点归属同一会话），供图表点击回查备注；按引用归属可避免相邻会话时间戳相同的覆盖问题 */
  session: Session | null = null;

  constructor(time: number, value: number, session: Session | null = null) {
    this.time = time;
    this.value = value;
    this.session = session;
  }
}
