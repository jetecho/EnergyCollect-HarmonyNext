import { relationalStore } from '@kit.ArkData';
import { Database } from '../Database';
import { Session } from '../../model/Session';
import { SessionType } from '../../model/SessionType';

export class SessionRepository {
  private db: Database = Database.getInstance();

  async listFiltered(deviceId: number, typeFilter: number): Promise<Session[]> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
    if (deviceId > 0) {
      pred.equalTo('device_id', deviceId);
    }
    if (typeFilter >= 0) {
      pred.equalTo('type', typeFilter);
    }
    pred.orderByDesc('start_time');
    try {
      const resultSet: relationalStore.ResultSet = await store.query(pred);
      return this.mapSessions(resultSet);
    } catch (e) {
      throw new Error('listFiltered failed');
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
      throw new Error('startSession failed');
    }
  }

  async startUsageSession(deviceId: number, startBattery: number, note: string, startRange: number): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      store.beginTransaction();
    } catch (e) {
      throw new Error('beginTransaction failed');
    }
    try {
      const sessions: Session[] = await this.listFiltered(deviceId, -1);
      let lastCompleted: Session | null = null;
      for (const s of sessions) {
        if (s.isCompleted()) {
          lastCompleted = s;
          break;
        }
      }
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
      throw new Error('delete session failed');
    }
  }

  async deleteAll(): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      await store.executeSql('DELETE FROM sessions');
      await store.executeSql('DELETE FROM devices');
    } catch (e) {
      throw new Error('deleteAll failed');
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
