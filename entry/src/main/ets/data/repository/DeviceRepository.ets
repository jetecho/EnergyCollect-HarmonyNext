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
    const resultSet: relationalStore.ResultSet = await store.querySql(sql);
    return this.mapDevices(resultSet);
  }

  async getById(id: number): Promise<Device | null> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const resultSet: relationalStore.ResultSet =
      await store.querySql('SELECT * FROM devices WHERE id = ' + id);
    const list: Device[] = this.mapDevices(resultSet);
    if (list.length === 0) {
      return null;
    }
    return list[0];
  }

  async count(): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const resultSet: relationalStore.ResultSet =
      await store.querySql('SELECT COUNT(*) AS c FROM devices WHERE archived = 0');
    let count: number = 0;
    if (resultSet.goToFirstRow()) {
      count = resultSet.getLong(resultSet.getColumnIndex('c'));
    }
    resultSet.close();
    return count;
  }

  async insert(name: string, icon: string): Promise<number> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const createdAt: number = Date.now();
    const values: relationalStore.ValuesBucket = {
      'name': name,
      'icon': icon,
      'sort_order': 0,
      'archived': 0,
      'created_at': createdAt
    };
    return await store.insert('devices', values);
  }

  async update(id: number, name: string, icon: string): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const values: relationalStore.ValuesBucket = {
      'name': name,
      'icon': icon
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('devices');
    pred.equalTo('id', id);
    await store.update(values, pred);
  }

  async delete(id: number): Promise<void> {
    const store: relationalStore.RdbStore = this.db.getStore();
    const predSession: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('sessions');
    predSession.equalTo('device_id', id);
    await store.delete(predSession);
    const predDevice: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('devices');
    predDevice.equalTo('id', id);
    await store.delete(predDevice);
  }

  private mapDevices(resultSet: relationalStore.ResultSet): Device[] {
    const list: Device[] = [];
    while (resultSet.goToNextRow()) {
      const d: Device = new Device();
      d.id = resultSet.getLong(resultSet.getColumnIndex('id'));
      d.name = resultSet.getString(resultSet.getColumnIndex('name'));
      d.icon = resultSet.getString(resultSet.getColumnIndex('icon'));
      d.sortOrder = resultSet.getLong(resultSet.getColumnIndex('sort_order'));
      d.archived = resultSet.getLong(resultSet.getColumnIndex('archived')) !== 0;
      d.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
      list.push(d);
    }
    resultSet.close();
    return list;
  }
}
