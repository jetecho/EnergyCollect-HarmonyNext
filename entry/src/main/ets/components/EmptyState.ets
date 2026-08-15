@Component
export struct EmptyState {
  @Prop icon: ResourceStr = $r('app.media.ic_history');
  @Prop title: ResourceStr;
  @Prop desc: ResourceStr = '';
  @Builder
  defaultAction() {
  }

  @BuilderParam action: () => void = this.defaultAction;

  build() {
    Column({ space: 12 }) {
      Image(this.icon)
        .width(56)
        .height(56)
        .fillColor($r('app.color.icon_outline'))
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      if (this.desc !== '') {
        Text(this.desc)
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24 })
      }
      this.action()
    }
    .width('100%')
    .padding({ top: 56, bottom: 56 })
    .alignItems(HorizontalAlign.Center)
  }
}
