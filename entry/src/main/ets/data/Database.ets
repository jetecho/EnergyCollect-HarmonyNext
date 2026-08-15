import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

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
  'created_at INTEGER)';

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
  'created_at INTEGER)';

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
    this.store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await this.store.executeSql(SQL_CREATE_DEVICES);
    await this.store.executeSql(SQL_CREATE_SESSIONS);
    await this.store.executeSql(SQL_INDEX_SESSION_DEVICE);
    await this.store.executeSql(SQL_INDEX_SESSION_TIME);
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('Database not initialized. Call init() first.');
    }
    return this.store;
  }
}
