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

const INIT_MAX_ATTEMPTS: number = 3;
const INIT_RETRY_DELAY_MS: number = 300;

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
    let lastError: Error = new Error('unknown');
    for (let attempt: number = 1; attempt <= INIT_MAX_ATTEMPTS; attempt++) {
      try {
        const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
        this.store = store;
        await store.executeSql(SQL_CREATE_DEVICES);
        await store.executeSql(SQL_CREATE_SESSIONS);
        await store.executeSql(SQL_INDEX_SESSION_DEVICE);
        await store.executeSql(SQL_INDEX_SESSION_TIME);
        await this.migrate();
        hilog.info(DOMAIN, TAG, 'Database initialized');
        return;
      } catch (error) {
        this.store = null;
        lastError = error as Error;
        hilog.error(DOMAIN, TAG, 'Database init attempt %{public}d/%{public}d failed: %{public}s',
          attempt, INIT_MAX_ATTEMPTS, JSON.stringify(error));
        if (attempt < INIT_MAX_ATTEMPTS) {
          await Database.sleep(INIT_RETRY_DELAY_MS);
        }
      }
    }
    throw new Error('Database init failed after ' + INIT_MAX_ATTEMPTS + ' attempts: ' + JSON.stringify(lastError));
  }

  isReady(): boolean {
    return this.store !== null;
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout((): void => {
        resolve();
      }, ms);
    });
  }

  private async migrate(): Promise<void> {
    await this.ensureColumn('devices', 'battery_capacity', 'ALTER TABLE devices ADD COLUMN battery_capacity INTEGER DEFAULT 0');
    await this.ensureColumn('devices', 'range_rated', 'ALTER TABLE devices ADD COLUMN range_rated INTEGER DEFAULT 0');
    await this.ensureColumn('devices', 'stat_mode', "ALTER TABLE devices ADD COLUMN stat_mode TEXT DEFAULT ''");
    await this.ensureColumn('sessions', 'start_range', 'ALTER TABLE sessions ADD COLUMN start_range INTEGER DEFAULT -1');
    await this.ensureColumn('sessions', 'end_range', 'ALTER TABLE sessions ADD COLUMN end_range INTEGER DEFAULT -1');
  }

  private async ensureColumn(table: string, column: string, alterSql: string): Promise<void> {
    try {
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
        try {
          resultSet.close();
        } catch (e2) {
        }
      }
      if (!exists) {
        await store.executeSql(alterSql);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ensureColumn %{public}s failed: %{public}s', column, JSON.stringify(e));
      throw new Error('ensureColumn failed');
    }
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('Database not initialized. Call init() first.');
    }
    return this.store;
  }

  beginTransaction(): void {
    try {
      this.getStore().beginTransaction();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'beginTransaction failed: %{public}s', JSON.stringify(e));
      throw new Error('beginTransaction failed');
    }
  }

  commitTransaction(): void {
    try {
      this.getStore().commit();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'commitTransaction failed: %{public}s', JSON.stringify(e));
      throw new Error('commitTransaction failed');
    }
  }

  rollbackTransaction(): void {
    try {
      this.getStore().rollBack();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'rollbackTransaction failed: %{public}s', JSON.stringify(e));
      throw new Error('rollbackTransaction failed');
    }
  }
}
