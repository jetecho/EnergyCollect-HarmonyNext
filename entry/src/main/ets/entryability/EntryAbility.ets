import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Database } from '../data/Database';
import { PreferencesUtil } from '../data/PreferencesUtil';
import { SessionRepository, ORPHAN_SESSION_THRESHOLD_MS } from '../data/repository/SessionRepository';
import { DataNotifier } from '../data/DataNotifier';
import { Immersive } from '../utils/Immersive';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onWindowStageCreate');
    this.bootstrap(windowStage);
  }

  private async bootstrap(windowStage: window.WindowStage): Promise<void> {
    // 同步就绪全局状态默认值与通知键，页面首帧即可读取
    const systemColorMode: number = this.getSystemColorMode();
    AppStorage.setOrCreate('systemColorMode', systemColorMode);
    AppStorage.setOrCreate('colorMode', -1);
    AppStorage.setOrCreate('defaultDeviceId', -1);
    AppStorage.setOrCreate('recoveredSessions', 0);
    AppStorage.setOrCreate('dbInitFailed', false);
    AppStorage.setOrCreate('statusBarHeight', 0);
    AppStorage.setOrCreate('navBarHeight', 0);
    DataNotifier.init();

    // 偏好读取与沉浸式配置较快，保持在首帧前完成，避免主题/布局跳变
    let colorMode: number = -1;
    try {
      await PreferencesUtil.init(this.context);
      colorMode = await PreferencesUtil.getColorMode();
      const defaultDeviceId: number = await PreferencesUtil.getDefaultDeviceId();
      AppStorage.setOrCreate('colorMode', colorMode);
      AppStorage.setOrCreate('defaultDeviceId', defaultDeviceId > 0 ? defaultDeviceId : -1);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'preferences init failed: %{public}s', JSON.stringify(err));
    }
    this.applyColorMode(colorMode);

    try {
      const win: window.Window = await Immersive.setup(windowStage);
      const sbH: number = Immersive.getStatusBarHeightVp(win);
      const navH: number = Immersive.getNavBarHeightVp(win);
      AppStorage.setOrCreate('statusBarHeight', sbH);
      AppStorage.setOrCreate('navBarHeight', navH);
      const isDark: boolean = Immersive.isDarkMode(colorMode, systemColorMode);
      await Immersive.applySystemBar(win, isDark);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'immersive setup failed: %{public}s', JSON.stringify(err));
    }

    // 数据库初始化（失败重试最慢约 1s）移到页面加载之后，首帧不再被阻塞；
    // 库就绪前页面的首次查询会安全失败，就绪后通过 DataNotifier 统一刷新
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Succeeded in loading content.');
    });

    await this.initData();
  }

  private async initData(): Promise<void> {
    try {
      await Database.getInstance().init(this.context);
      AppStorage.setOrCreate('dbInitFailed', false);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Database init failed: %{public}s', JSON.stringify(err));
      AppStorage.setOrCreate('dbInitFailed', true);
      return;
    }
    try {
      const recovered: number = await new SessionRepository().recoverOrphanActiveSessions(ORPHAN_SESSION_THRESHOLD_MS);
      if (recovered > 0) {
        AppStorage.setOrCreate('recoveredSessions', recovered);
        hilog.info(DOMAIN, TAG, 'auto-closed %{public}d orphan active session(s)', recovered);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'orphan session recovery failed: %{public}s', JSON.stringify(err));
    }
    // 页面此时已在渲染，主动通知三个 Tab 加载首帧时未能获取的数据
    DataNotifier.notifyAll();
  }

  private getSystemColorMode(): number {
    try {
      const cfg: Configuration = this.context.config;
      if (cfg === undefined || cfg === null) {
        return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      }
      const cm: ConfigurationConstant.ColorMode | undefined = cfg.colorMode;
      if (cm === undefined) {
        return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      }
      return cm;
    } catch (e) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    }
  }

  private applyColorMode(colorMode: number): void {
    let mode: number;
    if (colorMode === 1) {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (colorMode === 0) {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    }
    try {
      this.context.getApplicationContext().setColorMode(mode);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onWindowStageDestroy');
    Immersive.clear();
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onBackground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onConfigurationUpdate');
    const cm: ConfigurationConstant.ColorMode | undefined = newConfig.colorMode;
    if (cm === undefined) {
      return;
    }
    const systemColorMode: number = cm;
    AppStorage.setOrCreate('systemColorMode', systemColorMode);
    const colorMode: number = AppStorage.get<number>('colorMode') ?? -1;
    Immersive.applyColorMode(colorMode, systemColorMode);
  }
}
