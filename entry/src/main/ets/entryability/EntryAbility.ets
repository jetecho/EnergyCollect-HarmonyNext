import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Database } from '../data/Database';
import { PreferencesUtil } from '../data/PreferencesUtil';
import { Immersive } from '../utils/Immersive';

const DOMAIN: number = 0x0000;
const TAG: string = 'EnergyCollect';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

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
    try {
      await Database.getInstance().init(this.context);
      await PreferencesUtil.init(this.context);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err));
    }

    const colorMode: number = await PreferencesUtil.getColorMode();
    const currentDeviceId: number = await PreferencesUtil.getCurrentDeviceId();
    const defaultDeviceId: number = await PreferencesUtil.getDefaultDeviceId();
    const systemColorMode: number = this.getSystemColorMode();

    AppStorage.setOrCreate('colorMode', colorMode);
    AppStorage.setOrCreate('currentDeviceId', currentDeviceId > 0 ? currentDeviceId : -1);
    AppStorage.setOrCreate('defaultDeviceId', defaultDeviceId > 0 ? defaultDeviceId : -1);
    AppStorage.setOrCreate('dataVersion', 0);
    AppStorage.setOrCreate('systemColorMode', systemColorMode);

    this.applyColorMode(colorMode);

    try {
      const win: window.Window = await Immersive.setup(windowStage);
      this.mainWindow = win;
      const sbH: number = Immersive.getStatusBarHeightVp(win);
      const navH: number = Immersive.getNavBarHeightVp(win);
      AppStorage.setOrCreate('statusBarHeight', sbH);
      AppStorage.setOrCreate('navBarHeight', navH);
      const isDark: boolean = Immersive.isDarkMode(colorMode, systemColorMode);
      await Immersive.applySystemBar(win, isDark);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'immersive setup failed: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Succeeded in loading content.');
    });
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

  async applyColorModeFromOutside(colorMode: number): Promise<void> {
    this.applyColorMode(colorMode);
    if (this.mainWindow !== null) {
      const systemColorMode: number = this.getSystemColorMode();
      const isDark: boolean = Immersive.isDarkMode(colorMode, systemColorMode);
      await Immersive.applySystemBar(this.mainWindow, isDark);
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onWindowStageDestroy');
    this.mainWindow = null;
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
    if (this.mainWindow !== null) {
      const isDark: boolean = Immersive.isDarkMode(colorMode, systemColorMode);
      Immersive.applySystemBar(this.mainWindow, isDark);
    }
  }
}
