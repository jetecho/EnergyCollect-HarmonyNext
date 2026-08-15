@Component
export struct AppBar {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @Prop title: ResourceStr;
  @Prop bgTransparent: boolean = false;
  @Builder
  defaultRight() {
  }

  @BuilderParam rightAction: () => void = this.defaultRight;

  build() {
    Column() {
      Blank()
        .height(this.statusBarHeight)
        .width('100%')

      Row() {
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        this.rightAction()
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(this.bgTransparent ? Color.Transparent : $r('app.color.bg_top'))
  }
}
