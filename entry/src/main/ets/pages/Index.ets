import { HomeTab } from './tabs/HomeTab';
import { HistoryTab } from './tabs/HistoryTab';
import { MineTab } from './tabs/MineTab';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  private controller: HdsTabsController = new HdsTabsController();

  build() {
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
    .scrollable(true)
    .animationDuration(300)
    .barFloatingStyle({
      barBottomMargin: 16,
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
