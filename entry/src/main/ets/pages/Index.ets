import { HomeTab } from './tabs/HomeTab';
import { HistoryTab } from './tabs/HistoryTab';
import { MineTab } from './tabs/MineTab';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { EarphoneSyncManager } from '../utils/EarphoneSyncManager';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  private controller: HdsTabsController = new HdsTabsController();
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  // 蓝牙校准保存后权限才就绪：数据版本变化时重试启动自动同步（内部幂等）
  @StorageProp('homeDataVersion') @Watch('ensureSyncStarted') homeDataVersion: number = 0;

  aboutToAppear(): void {
    this.ensureSyncStarted();
  }

  private ensureSyncStarted(): void {
    EarphoneSyncManager.getInstance().start();
  }

  build() {
    Column() {
      HdsTabs({ controller: this.controller, index: this.currentTab }) {
        TabContent() {
          HomeTab()
        }
          .tabBar(this.buildTabBar($r('app.media.ic_home'), $r('app.string.tab_home')))

        TabContent() {
          HistoryTab()
        }
          .tabBar(this.buildTabBar($r('app.media.ic_history'), $r('app.string.tab_history')))

        TabContent() {
          MineTab()
        }
          .tabBar(this.buildTabBar($r('app.media.ic_mine'), $r('app.string.tab_mine')))
      }
      .barPosition(BarPosition.End)
      .barOverlap(true)
      .vertical(false)
      .scrollable(true)
      .barFloatingStyle({
        barBottomMargin: 16 + this.navBarHeight,
        gradientMask: {
          maskColor: '#66F1F3F5',
          maskHeight: 92
        },
        adaptToHandedness: true,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .width('100%')
    .height('100%')
  }

  private buildTabBar(icon: Resource, label: ResourceStr): BottomTabBarStyle {
    return new BottomTabBarStyle(icon, label)
      .labelStyle({
        selectedColor: $r('app.color.brand'),
        unselectedColor: $r('app.color.text_tertiary')
      })
      .iconStyle({
        selectedColor: $r('app.color.brand'),
        unselectedColor: $r('app.color.icon_outline')
      });
  }
}
