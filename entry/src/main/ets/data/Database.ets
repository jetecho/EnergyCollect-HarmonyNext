import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'EnergyCollect.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_DEVICES: string =
  'CREATE TABLE IF NOT EXISTS devices (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'name TEXT NOT NULL, ' +
  'icon TEXT NOT NULL, ' +
  'sort_order INTEGER DEFAULT 0, ' +
  'archived INTEGER DEFAULT 0, ' +
  'created_at INTEGER, ' +
  'battery_capacity INTEGER DEFAULT 0, ' +
  'range_rated INTEGER DEFAULT 0, ' +
  'stat_mode TEXT DEFAULT "")';

const SQL_CREATE_SESSIONS: string =
  'CREATE TABLE IF NOT EXISTS sessions (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'device_id INTEGER NOT NULL, ' +
  'type INTEGER NOT NULL, ' +
  'start_battery INTEGER NOT NULL, ' +
  'end_battery INTEGER, ' +
  'start_time INTEGER NOT NULL, ' +
  'end_time INTEGER, ' +
  'note TEXT, ' +
  'created_at INTEGER, ' +
  'start_range INTEGER DEFAULT -1, ' +
  'end_range INTEGER DEFAULT -1)';

const SQL_INDEX_SESSION_DEVICE: string =
  'CREATE INDEX IF NOT EXISTS idx_sessions_device ON sessions(device_id)';

const SQL_INDEX_SESSION_TIME: string =
  'CREATE INDEX IF NOT EXISTS idx_sessions_time ON sessions(start_time)';

export class Database {
  private static instance: Database | null = null;
  private store: relationalStore.RdbStore | null = null;

  private constructor() {
  }

  static getInstance(): Database {
    if (Database.instance === null) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.store !== null) {
      return;
    }
    try {
      this.store = await relationalStore.getRdbStore(context, STORE_CONFIG);
      await this.store.executeSql(SQL_CREATE_DEVICES);
      await this.store.executeSql(SQL_CREATE_SESSIONS);
      await this.store.executeSql(SQL_INDEX_SESSION_DEVICE);
      await this.store.executeSql(SQL_INDEX_SESSION_TIME);
      await this.migrate();
    } catch (error) {
      this.store = null;
      hilog.error(DOMAIN, TAG, 'Database init failed: %{public}s', JSON.stringify(error));
    }
  }

  private async migrate(): Promise<void> {
    await this.ensureColumn('devices', 'battery_capacity', 'ALTER TABLE devices ADD COLUMN battery_capacity INTEGER DEFAULT 0');
    await this.ensureColumn('devices', 'range_rated', 'ALTER TABLE devices ADD COLUMN range_rated INTEGER DEFAULT 0');
    await this.ensureColumn('devices', 'stat_mode', "ALTER TABLE devices ADD COLUMN stat_mode TEXT DEFAULT ''");
    await this.ensureColumn('sessions', 'start_range', 'ALTER TABLE sessions ADD COLUMN start_range INTEGER DEFAULT -1');
    await this.ensureColumn('sessions', 'end_range', 'ALTER TABLE sessions ADD COLUMN end_range INTEGER DEFAULT -1');
  }

  private async ensureColumn(table: string, column: string, alterSql: string): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const resultSet: relationalStore.ResultSet = await store.querySql(`PRAGMA table_info(${table})`);
    let exists: boolean = false;
    try {
      while (resultSet.goToNextRow()) {
        const name: string = resultSet.getString(resultSet.getColumnIndex('name'));
        if (name === column) {
          exists = true;
          break;
        }
      }
    } finally {
      resultSet.close();
    }
    if (!exists) {
      await store.executeSql(alterSql);
    }
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('Database not initialized. Call init() first.');
    }
    return this.store;
  }

  beginTransaction(): void {
    this.getStore().beginTransaction();
  }

  commitTransaction(): void {
    this.getStore().commit();
  }

  rollbackTransaction(): void {
    this.getStore().rollBack();
  }
}
