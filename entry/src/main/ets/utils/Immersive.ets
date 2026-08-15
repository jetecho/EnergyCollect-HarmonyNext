import { window } from '@kit.ArkUI';

export class Immersive {
  private static mainWindow: window.Window | null = null;

  static async setup(windowStage: window.WindowStage): Promise<window.Window> {
    const win: window.Window = await windowStage.getMainWindow();
    Immersive.mainWindow = win;
    await win.setWindowLayoutFullScreen(true);
    win.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
      if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
        AppStorage.setOrCreate('statusBarHeight', px2vp(data.area.topRect.height));
        AppStorage.setOrCreate('navBarHeight', px2vp(data.area.bottomRect.height));
      }
    });
    return win;
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
    const avoidArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    return px2vp(avoidArea.topRect.height);
  }

  static getNavBarHeightVp(win: window.Window): number {
    const avoidArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    return px2vp(avoidArea.bottomRect.height);
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
