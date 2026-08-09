import { relationalStore } from '@kit.ArkData';
import { Database } from '../Database';
import { Session } from '../../model/Session';
import { SessionType } from '../../model/SessionType';

export class SessionRepository {
  private db: Database = Database.getInstance();

  async listFiltered(deviceId: number, typeFilter: number): Promise<Session[]> {
    const store: relationalStore.RdbStore = this.db.getStore();
    let sql: string = 'SELECT * FROM sessions WHERE 1 = 1';
    if (deviceId > 0) {
      sql += ' AND device_id = ' + deviceId;
    }
    if (typeFilter >= 0) {
      sql += ' AND type = ' + typeFilter;
    }
    sql += ' ORDER BY start_time DESC';
    const resultSet: relationalStore.ResultSet = await store.querySql(sql);
    return this.mapSessions(resultSet);
  }

  async getActive(deviceId: number): Promise<Session | null> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const sql: string =
      'SELECT * FROM sessions WHERE device_id = ' + deviceId +
      ' AND end_time IS NULL ORDER BY start_time DESC LIMIT 1';
    const resultSet: relationalStore.ResultSet = await store.querySql(sql);
    const list: Session[] = this.mapSessions(resultSet);
    if (list.length === 0) {
      return null;
    }
    return list[0];
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
    return await store.insert('sessions', values);
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
    return await store.insert('sessions', values);
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
    return await store.insert('sessions', values);
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
    await store.update(values, pred);
  }

  async delete(id: number): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
    pred.equalTo('id', id);
    await store.delete(pred);
  }

  async deleteAll(): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    await store.executeSql('DELETE FROM sessions');
    await store.executeSql('DELETE FROM devices');
  }

  private mapSessions(resultSet: relationalStore.ResultSet): Session[] {
    const list: Session[] = [];
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
    resultSet.close();
    return list;
  }
}
