import { relationalStore } from '@kit.ArkData';
import { Database } from '../Database';
import { Device } from '../../model/Device';

export class DeviceRepository {
  private db: Database = Database.getInstance();

  async listAll(includeArchived: boolean): Promise<Device[]> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const sql: string = includeArchived
      ? 'SELECT * FROM devices ORDER BY archived ASC, sort_order ASC, created_at ASC'
      : 'SELECT * FROM devices WHERE archived = 0 ORDER BY sort_order ASC, created_at ASC';
    try {
      const resultSet: relationalStore.ResultSet = await store.querySql(sql);
      return this.mapDevices(resultSet);
    } catch (e) {
      throw new Error('listAll failed');
    }
  }

  async getById(id: number): Promise<Device | null> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('devices');
      pred.equalTo('id', id);
      const resultSet: relationalStore.ResultSet = await store.query(pred);
      const list: Device[] = this.mapDevices(resultSet);
      if (list.length === 0) {
        return null;
      }
      return list[0];
    } catch (e) {
      throw new Error('getById failed');
    }
  }

  async count(): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      const resultSet: relationalStore.ResultSet =
        await store.querySql('SELECT COUNT(*) AS c FROM devices WHERE archived = 0');
      let count: number = 0;
      try {
        if (resultSet.goToFirstRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('c'));
        }
      } finally {
        try {
          resultSet.close();
        } catch (e2) {
        }
      }
      return count;
    } catch (e) {
      throw new Error('count failed');
    }
  }

  async insert(name: string, icon: string, capacity?: number, rangeRated?: number, statMode?: string): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const createdAt: number = Date.now();
    const values: relationalStore.ValuesBucket = {
      'name': name,
      'icon': icon,
      'sort_order': 0,
      'archived': 0,
      'created_at': createdAt,
      'battery_capacity': capacity ?? 0,
      'range_rated': rangeRated ?? 0,
      'stat_mode': statMode ?? ''
    };
    try {
      return await store.insert('devices', values);
    } catch (e) {
      throw new Error('insert device failed');
    }
  }

  async update(id: number, name: string, icon: string, capacity?: number, rangeRated?: number, statMode?: string): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const values: relationalStore.ValuesBucket = {
      'name': name,
      'icon': icon,
      'battery_capacity': capacity ?? 0,
      'range_rated': rangeRated ?? 0,
      'stat_mode': statMode ?? ''
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('devices');
    pred.equalTo('id', id);
    try {
      await store.update(values, pred);
    } catch (e) {
      throw new Error('update device failed');
    }
  }

  async delete(id: number): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      store.beginTransaction();
    } catch (e) {
      throw new Error('beginTransaction failed');
    }
    try {
      const predSession: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
      predSession.equalTo('device_id', id);
      await store.delete(predSession);
      const predDevice: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('devices');
      predDevice.equalTo('id', id);
      await store.delete(predDevice);
      store.commit();
    } catch (e) {
      try {
        store.rollBack();
      } catch (e2) {
      }
      throw new Error('delete device failed');
    }
  }

  private mapDevices(resultSet: relationalStore.ResultSet): Device[] {
    const list: Device[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const d: Device = new Device();
        d.id = resultSet.getLong(resultSet.getColumnIndex('id'));
        d.name = resultSet.getString(resultSet.getColumnIndex('name'));
        d.icon = resultSet.getString(resultSet.getColumnIndex('icon'));
        d.sortOrder = resultSet.getLong(resultSet.getColumnIndex('sort_order'));
        d.archived = resultSet.getLong(resultSet.getColumnIndex('archived')) !== 0;
        d.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
        const capIdx: number = resultSet.getColumnIndex('battery_capacity');
        d.batteryCapacity = capIdx >= 0 ? resultSet.getLong(capIdx) : 0;
        const rangeIdx: number = resultSet.getColumnIndex('range_rated');
        d.rangeRated = rangeIdx >= 0 ? resultSet.getLong(rangeIdx) : 0;
        const modeIdx: number = resultSet.getColumnIndex('stat_mode');
        d.statMode = modeIdx >= 0 ? resultSet.getString(modeIdx) : '';
        list.push(d);
      }
    } catch (e) {
      throw new Error('mapDevices failed');
    } finally {
      try {
        resultSet.close();
      } catch (e2) {
      }
    }
    return list;
  }
}
