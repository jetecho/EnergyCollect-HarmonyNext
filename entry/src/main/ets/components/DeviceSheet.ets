import { DEVICE_ICON_KEYS, iconToResource, iconToNameRes } from '../model/Device';

@Component
export struct DeviceSheet {
  @Prop sheetTitle: ResourceStr;
  @Prop initialName: string = '';
  @Prop initialIcon: string = 'other';
  @Prop canDelete: boolean = false;
  onSave: (name: string, icon: string) => void = () => {};
  onDelete: () => void = () => {};
  onClose: () => void = () => {};
  onInvalid: () => void = () => {};
  @State name: string = '';
  @State icon: string = 'other';

  aboutToAppear(): void {
    this.name = this.initialName;
    this.icon = this.initialIcon;
  }

  build() {
    Column({ space: 18 }) {
      Row() {
        Text(this.sheetTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('✕')
          .fontSize(20)
          .fontColor($r('app.color.text_tertiary'))
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text($r('app.string.device_name_label'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextInput({
          text: this.name,
          placeholder: $r('app.string.device_name_placeholder')
        })
          .fontSize(15)
          .height(48)
          .backgroundColor($r('app.color.bg_primary'))
          .borderRadius(12)
          .onChange((v: string) => {
            this.name = v;
          })
      }
      .width('100%')

      Column({ space: 10 }) {
        Text($r('app.string.device_icon_label'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Grid() {
          ForEach(DEVICE_ICON_KEYS, (key: string) => {
            GridItem() {
              this.IconTile(key)
            }
          }, (key: string) => key)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .width('100%')
        .height(170)
      }
      .width('100%')

      Blank()

      Row({ space: 12 }) {
        if (this.canDelete) {
          Button($r('app.string.action_delete'))
            .type(ButtonType.Normal)
            .borderRadius(12)
            .layoutWeight(1)
            .backgroundColor($r('app.color.danger_bg'))
            .fontColor($r('app.color.danger'))
            .onClick(() => {
              this.onDelete();
            })
        }
        Button($r('app.string.action_save'))
          .type(ButtonType.Normal)
          .borderRadius(12)
          .layoutWeight(1)
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.text_on_brand'))
          .onClick(() => {
            if (this.name.trim().length === 0) {
              this.onInvalid();
              return;
            }
            this.onSave(this.name.trim(), this.icon);
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor($r('app.color.bg_primary'))
  }

  @Builder
  IconTile(key: string) {
    Column({ space: 6 }) {
      Stack() {
        Text('')
          .width(48)
          .height(48)
          .backgroundColor(this.icon === key ? $r('app.color.brand_light') : $r('app.color.bg_card'))
          .borderRadius(24)
          .border({
            width: this.icon === key ? 2 : 0,
            color: $r('app.color.brand')
          })
        Image(iconToResource(key))
          .width(26)
          .height(26)
          .fillColor(this.icon === key ? $r('app.color.brand') : $r('app.color.text_secondary'))
      }
      .width(48)
      .height(48)
      Text(iconToNameRes(key))
        .fontSize(11)
        .fontColor(this.icon === key ? $r('app.color.brand') : $r('app.color.text_secondary'))
    }
    .width('100%')
    .onClick(() => {
      this.icon = key;
    })
  }
}
