import { relationalStore } from '@kit.ArkData';
import { Database } from '../Database';
import { Device } from '../../model/Device';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

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
      hilog.error(DOMAIN, TAG, 'listAll failed: %{public}s', JSON.stringify(e));
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
      hilog.error(DOMAIN, TAG, 'getById failed: %{public}s', JSON.stringify(e));
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
      hilog.error(DOMAIN, TAG, 'count failed: %{public}s', JSON.stringify(e));
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
      hilog.error(DOMAIN, TAG, 'insert device failed: %{public}s', JSON.stringify(e));
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
      hilog.error(DOMAIN, TAG, 'update device failed: %{public}s', JSON.stringify(e));
      throw new Error('update device failed');
    }
  }

  /** 蓝牙自动同步：仅刷新电量/充电状态/同步时间，不触碰名称与绑定关系 */
  async updateBtState(id: number, battery: number, leftBattery: number, rightBattery: number,
    boxBattery: number, charging: number): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const values: relationalStore.ValuesBucket = {
      'bt_battery': battery,
      'bt_left_battery': leftBattery,
      'bt_right_battery': rightBattery,
      'bt_box_battery': boxBattery,
      'bt_charging': charging,
      'bt_sync_at': Date.now()
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('devices');
    pred.equalTo('id', id);
    try {
      await store.update(values, pred);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'updateBtState failed: %{public}s', JSON.stringify(e));
      throw new Error('updateBtState failed');
    }
  }

  /** 蓝牙连接状态持久化（边沿判定的跨进程依据） */
  async updateBtConnState(id: number, connected: boolean): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const values: relationalStore.ValuesBucket = {
      'bt_conn_state': connected ? 1 : 0
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('devices');
    pred.equalTo('id', id);
    try {
      await store.update(values, pred);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'updateBtConnState failed: %{public}s', JSON.stringify(e));
      throw new Error('updateBtConnState failed');
    }
  }

  async delete(id: number): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    try {
      store.beginTransaction();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'beginTransaction failed: %{public}s', JSON.stringify(e));
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
      hilog.error(DOMAIN, TAG, 'delete device failed: %{public}s', JSON.stringify(e));
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
        const btIdIdx: number = resultSet.getColumnIndex('bt_device_id');
        d.btDeviceId = btIdIdx >= 0 ? resultSet.getString(btIdIdx) : '';
        const btNameIdx: number = resultSet.getColumnIndex('bt_name');
        d.btName = btNameIdx >= 0 ? resultSet.getString(btNameIdx) : '';
        const btBatIdx: number = resultSet.getColumnIndex('bt_battery');
        d.btBattery = btBatIdx >= 0 ? resultSet.getLong(btBatIdx) : -1;
        const btLeftIdx: number = resultSet.getColumnIndex('bt_left_battery');
        d.btLeftBattery = btLeftIdx >= 0 ? resultSet.getLong(btLeftIdx) : -1;
        const btRightIdx: number = resultSet.getColumnIndex('bt_right_battery');
        d.btRightBattery = btRightIdx >= 0 ? resultSet.getLong(btRightIdx) : -1;
        const btBoxIdx: number = resultSet.getColumnIndex('bt_box_battery');
        d.btBoxBattery = btBoxIdx >= 0 ? resultSet.getLong(btBoxIdx) : -1;
        const btChgIdx: number = resultSet.getColumnIndex('bt_charging');
        d.btCharging = btChgIdx >= 0 ? resultSet.getLong(btChgIdx) : -1;
        const btSyncIdx: number = resultSet.getColumnIndex('bt_sync_at');
        d.btSyncAt = btSyncIdx >= 0 ? resultSet.getLong(btSyncIdx) : 0;
        const btConnIdx: number = resultSet.getColumnIndex('bt_conn_state');
        d.btConnState = btConnIdx >= 0 ? resultSet.getLong(btConnIdx) : 0;
        list.push(d);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'mapDevices failed: %{public}s', JSON.stringify(e));
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
