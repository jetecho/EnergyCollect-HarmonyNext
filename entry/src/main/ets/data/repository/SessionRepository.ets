import { relationalStore } from '@kit.ArkData';
import { Database } from '../Database';
import { Session } from '../../model/Session';
import { SessionType } from '../../model/SessionType';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

export const ORPHAN_SESSION_THRESHOLD_MS: number = 12 * 60 * 60 * 1000;

/** 单设备"今日"聚合统计（与 CalcUtil 语义一致：count 按 start_time，drain/charge 按 end_time） */
export interface TodayStats {
  count: number;
  drain: number;
  charge: number;
}

export class SessionRepository {
  private db: Database = Database.getInstance();

  async listFiltered(deviceId: number, typeFilter: number, startTimeMin?: number, limit?: number): Promise<Session[]> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
    if (deviceId > 0) {
      pred.equalTo('device_id', deviceId);
    }
    if (typeFilter >= 0) {
      pred.equalTo('type', typeFilter);
    }
    if (startTimeMin !== undefined && startTimeMin > 0) {
      pred.greaterThanOrEqualTo('start_time', startTimeMin);
    }
    if (limit !== undefined && limit > 0) {
      pred.limitAs(limit);
    }
    pred.orderByDesc('start_time');
    try {
      const resultSet: relationalStore.ResultSet = await store.query(pred);
      return this.mapSessions(resultSet);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'listFiltered failed: %{public}s', JSON.stringify(e));
      throw new Error('listFiltered failed');
    }
  }

  /** 进行中的会话（正常逻辑下每设备至多一条，取最新的） */
  async getActiveSession(deviceId: number): Promise<Session | null> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      const resultSet: relationalStore.ResultSet = await store.querySql(
        'SELECT * FROM sessions WHERE device_id = ? AND (end_time IS NULL OR end_time = 0) ' +
        'ORDER BY start_time DESC LIMIT 1', [deviceId]);
      const list: Session[] = this.mapSessions(resultSet);
      return list.length > 0 ? list[0] : null;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getActiveSession failed: %{public}s', JSON.stringify(e));
      throw new Error('getActiveSession failed');
    }
  }

  /** 最近一条已完成会话（决定设备当前电量/续航的基准） */
  async getLastCompleted(deviceId: number): Promise<Session | null> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      const resultSet: relationalStore.ResultSet = await store.querySql(
        'SELECT * FROM sessions WHERE device_id = ? AND end_time > 0 AND end_battery >= 0 ' +
        'ORDER BY start_time DESC LIMIT 1', [deviceId]);
      const list: Session[] = this.mapSessions(resultSet);
      return list.length > 0 ? list[0] : null;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getLastCompleted failed: %{public}s', JSON.stringify(e));
      throw new Error('getLastCompleted failed');
    }
  }

  /**
   * 单设备今日聚合统计，一条 SQL 完成：
   * - count：start_time 在今日起的会话数（含进行中）
   * - drain：type=USAGE 且已完成、end_time 在今日起的耗电合计
   * - charge：type=CHARGING 且已完成、end_time 在今日起的补能合计
   */
  async getTodayStats(deviceId: number, startOfToday: number): Promise<TodayStats> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const sql: string =
      'SELECT ' +
      'COALESCE(SUM(CASE WHEN start_time >= ? THEN 1 ELSE 0 END), 0) AS c, ' +
      'COALESCE(SUM(CASE WHEN type = 0 AND end_time > 0 AND end_battery >= 0 AND end_time >= ? ' +
      'THEN start_battery - end_battery ELSE 0 END), 0) AS drain, ' +
      'COALESCE(SUM(CASE WHEN type = 2 AND end_time > 0 AND end_battery >= 0 AND end_time >= ? ' +
      'THEN end_battery - start_battery ELSE 0 END), 0) AS charge ' +
      'FROM sessions WHERE device_id = ? AND (start_time >= ? OR end_time >= ?)';
    try {
      const resultSet: relationalStore.ResultSet = await store.querySql(sql,
        [startOfToday, startOfToday, startOfToday, deviceId, startOfToday, startOfToday]);
      const stats: TodayStats = { count: 0, drain: 0, charge: 0 };
      try {
        if (resultSet.goToFirstRow()) {
          stats.count = resultSet.getLong(resultSet.getColumnIndex('c'));
          stats.drain = resultSet.getLong(resultSet.getColumnIndex('drain'));
          stats.charge = resultSet.getLong(resultSet.getColumnIndex('charge'));
        }
      } finally {
        try {
          resultSet.close();
        } catch (e2) {
        }
      }
      return stats;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getTodayStats failed: %{public}s', JSON.stringify(e));
      throw new Error('getTodayStats failed');
    }
  }

  async startSession(deviceId: number, type: SessionType, startBattery: number, note: string, startRange?: number): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const now: number = Date.now();
    const values: relationalStore.ValuesBucket = {
      'device_id': deviceId,
      'type': type,
      'start_battery': startBattery,
      'start_time': now,
      'note': note,
      'created_at': now,
      'start_range': startRange ?? -1
    };
    try {
      return await store.insert('sessions', values);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'startSession failed: %{public}s', JSON.stringify(e));
      throw new Error('startSession failed');
    }
  }

  async startUsageSession(deviceId: number, startBattery: number, note: string, startRange: number): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      store.beginTransaction();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'beginTransaction failed: %{public}s', JSON.stringify(e));
      throw new Error('beginTransaction failed');
    }
    try {
      // 只需最近一条已完成会话做电量链条衔接，避免全量加载历史
      const lastCompleted: Session | null = await this.getLastCompleted(deviceId);
      if (lastCompleted !== null && startBattery < lastCompleted.endBattery) {
        await this.insertCompleted(
          deviceId, SessionType.IDLE,
          lastCompleted.endBattery, startBattery,
          lastCompleted.endTime, Date.now()
        );
      }
      const id: number = await this.startSession(deviceId, SessionType.USAGE, startBattery, note, startRange);
      store.commit();
      return id;
    } catch (e) {
      try {
        store.rollBack();
      } catch (e2) {
      }
      hilog.error(DOMAIN, TAG, 'startUsageSession failed: %{public}s', JSON.stringify(e));
      throw new Error('startUsageSession failed');
    }
  }

  async insertCompleted(deviceId: number, type: SessionType, startBattery: number, endBattery: number, startTime: number, endTime: number, startRange?: number, endRange?: number): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const values: relationalStore.ValuesBucket = {
      'device_id': deviceId,
      'type': type,
      'start_battery': startBattery,
      'end_battery': endBattery,
      'start_time': startTime,
      'end_time': endTime,
      'note': '',
      'created_at': Date.now(),
      'start_range': startRange ?? -1,
      'end_range': endRange ?? -1
    };
    try {
      return await store.insert('sessions', values);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'insertCompleted failed: %{public}s', JSON.stringify(e));
      throw new Error('insertCompleted failed');
    }
  }

  async importSession(deviceId: number, type: SessionType, startBattery: number, endBattery: number, startTime: number, endTime: number, note: string, startRange: number, endRange: number): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const values: relationalStore.ValuesBucket = {
      'device_id': deviceId,
      'type': type,
      'start_battery': startBattery,
      'end_battery': endBattery,
      'start_time': startTime,
      'end_time': endTime,
      'note': note,
      'created_at': Date.now(),
      'start_range': startRange,
      'end_range': endRange
    };
    try {
      return await store.insert('sessions', values);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'importSession failed: %{public}s', JSON.stringify(e));
      throw new Error('importSession failed');
    }
  }

  async endSession(id: number, endBattery: number, endRange?: number): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const now: number = Date.now();
    const values: relationalStore.ValuesBucket = {
      'end_battery': endBattery,
      'end_time': now,
      'end_range': endRange ?? -1
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
    pred.equalTo('id', id);
    try {
      await store.update(values, pred);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'endSession failed: %{public}s', JSON.stringify(e));
      throw new Error('endSession failed');
    }
  }

  async updateNote(id: number, note: string): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const values: relationalStore.ValuesBucket = {
      'note': note
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
    pred.equalTo('id', id);
    try {
      await store.update(values, pred);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'updateNote failed: %{public}s', JSON.stringify(e));
      throw new Error('updateNote failed');
    }
  }

  async delete(id: number): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
    pred.equalTo('id', id);
    try {
      await store.delete(pred);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'delete session failed: %{public}s', JSON.stringify(e));
      throw new Error('delete session failed');
    }
  }

  async deleteAll(): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      await store.executeSql('DELETE FROM sessions');
      await store.executeSql('DELETE FROM devices');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'deleteAll failed: %{public}s', JSON.stringify(e));
      throw new Error('deleteAll failed');
    }
  }

  /**
   * 兜底恢复异常中断的"进行中"会话（如进程被杀、崩溃）：
   * 超过 thresholdMs 仍未结束的会话，按"保留电量、时长清零"自动结束，
   * 使电量链条保持连续，避免会话永久显示进行中。
   * 返回自动结束的会话数量。
   */
  async recoverOrphanActiveSessions(thresholdMs: number): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const cutoff: number = Date.now() - thresholdMs;
    try {
      let count: number = 0;
      const countSet: relationalStore.ResultSet = await store.querySql(
        'SELECT COUNT(*) AS c FROM sessions WHERE (end_time IS NULL OR end_time = 0) AND start_time < ?',
        [cutoff]);
      try {
        if (countSet.goToFirstRow()) {
          count = countSet.getLong(countSet.getColumnIndex('c'));
        }
      } finally {
        try {
          countSet.close();
        } catch (e2) {
        }
      }
      if (count > 0) {
        await store.executeSql(
          'UPDATE sessions SET end_time = start_time, end_battery = start_battery, end_range = COALESCE(start_range, -1) ' +
          'WHERE (end_time IS NULL OR end_time = 0) AND start_time < ?',
          [cutoff]);
      }
      return count;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'recoverOrphanActiveSessions failed: %{public}s', JSON.stringify(e));
      throw new Error('recoverOrphanActiveSessions failed');
    }
  }

  private mapSessions(resultSet: relationalStore.ResultSet): Session[] {
    const list: Session[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const s: Session = new Session();
        s.id = resultSet.getLong(resultSet.getColumnIndex('id'));
        s.deviceId = resultSet.getLong(resultSet.getColumnIndex('device_id'));
        const typeVal: number = resultSet.getLong(resultSet.getColumnIndex('type'));
        if (typeVal === 0) {
          s.type = SessionType.USAGE;
        } else if (typeVal === 2) {
          s.type = SessionType.CHARGING;
        } else {
          s.type = SessionType.IDLE;
        }
        s.startBattery = resultSet.getLong(resultSet.getColumnIndex('start_battery'));
        s.endBattery = resultSet.getLong(resultSet.getColumnIndex('end_battery'));
        s.startTime = resultSet.getLong(resultSet.getColumnIndex('start_time'));
        s.endTime = resultSet.getLong(resultSet.getColumnIndex('end_time'));
        s.note = resultSet.getString(resultSet.getColumnIndex('note'));
        s.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
        const srIdx: number = resultSet.getColumnIndex('start_range');
        s.startRange = srIdx >= 0 ? resultSet.getLong(srIdx) : -1;
        const erIdx: number = resultSet.getColumnIndex('end_range');
        s.endRange = erIdx >= 0 ? resultSet.getLong(erIdx) : -1;
        list.push(s);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'mapSessions failed: %{public}s', JSON.stringify(e));
      throw new Error('mapSessions failed');
    } finally {
      try {
        resultSet.close();
      } catch (e2) {
      }
    }
    return list;
  }
}
