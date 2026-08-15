import { window } from '@kit.ArkUI';

export class Immersive {
  static async setup(windowStage: window.WindowStage): Promise<window.Window> {
    const win: window.Window = await windowStage.getMainWindow();
    await win.setWindowLayoutFullScreen(true);
    return win;
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
