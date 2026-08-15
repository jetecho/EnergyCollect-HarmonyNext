import { window } from '@kit.ArkUI';

export class Immersive {
  private static mainWindow: window.Window | null = null;

  static async setup(windowStage: window.WindowStage): Promise<window.Window> {
    try {
      const win: window.Window = await windowStage.getMainWindow();
      Immersive.mainWindow = win;
      await win.setWindowLayoutFullScreen(true);
      const uiCtx: UIContext = win.getUIContext();
      win.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('statusBarHeight', uiCtx.px2vp(data.area.topRect.height));
          AppStorage.setOrCreate('navBarHeight', uiCtx.px2vp(data.area.bottomRect.height));
        }
      });
      return win;
    } catch (e) {
      Immersive.mainWindow = null;
      throw new Error('Immersive setup failed');
    }
  }

  static getMainWindow(): window.Window | null {
    return Immersive.mainWindow;
  }

  static clear(): void {
    Immersive.mainWindow = null;
  }

  static async applyColorMode(colorMode: number, systemColorMode: number): Promise<void> {
    const win: window.Window | null = Immersive.mainWindow;
    if (win === null) {
      return;
    }
    await Immersive.applySystemBar(win, Immersive.isDarkMode(colorMode, systemColorMode));
  }

  static getStatusBarHeightVp(win: window.Window): number {
    try {
      const avoidArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      return win.getUIContext().px2vp(avoidArea.topRect.height);
    } catch (e) {
      return 0;
    }
  }

  static getNavBarHeightVp(win: window.Window): number {
    try {
      const avoidArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      return win.getUIContext().px2vp(avoidArea.bottomRect.height);
    } catch (e) {
      return 0;
    }
  }

  static async applySystemBar(win: window.Window, isDark: boolean): Promise<void> {
    const contentColor: string = isDark ? '#FFFFFF' : '#182431';
    const props: window.SystemBarProperties = {
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    };
    try {
      await win.setWindowSystemBarProperties(props);
    } catch (e) {
    }
  }

  static isDarkMode(colorMode: number, systemColorMode: number): boolean {
    if (colorMode === 1) {
      return true;
    }
    if (colorMode === 0) {
      return false;
    }
    return systemColorMode === 1;
  }
}
