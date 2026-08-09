import { DEVICE_ICON_KEYS, iconToResource, iconToNameRes } from '../model/Device';

@Component
export struct DeviceSheet {
  @Prop sheetTitle: ResourceStr;
  @Prop initialName: string = '';
  @Prop initialIcon: string = 'other';
  @Prop initialCapacity: number = 0;
  @Prop initialRange: number = 0;
  @Prop initialStatMode: string = 'CLTC';
  @Prop canDelete: boolean = false;
  onSave: (name: string, icon: string, capacity: number, rangeRated: number, statMode: string) => void = () => {};
  onDelete: () => void = () => {};
  onClose: () => void = () => {};
  onInvalid: () => void = () => {};
  @State name: string = '';
  @State icon: string = 'other';
  @State capacityText: string = '';
  @State rangeText: string = '';
  @State statMode: string = 'CLTC';

  aboutToAppear(): void {
    this.name = this.initialName;
    this.icon = this.initialIcon;
    this.capacityText = this.initialCapacity > 0 ? `${this.initialCapacity}` : '';
    this.rangeText = this.initialRange > 0 ? `${this.initialRange}` : '';
    this.statMode = this.initialStatMode.length > 0 ? this.initialStatMode : 'CLTC';
  }

  private parsePositive(text: string): number {
    const v: number = parseFloat(text);
    if (isNaN(v) || v < 0) {
      return 0;
    }
    return v;
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
        .height(210)
      }
      .width('100%')

      if (this.icon === 'nev') {
        this.NevFields()
      }

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
            this.onSave(this.name.trim(), this.icon, this.parsePositive(this.capacityText),
              this.parsePositive(this.rangeText), this.statMode);
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
  NevFields() {
    Column({ space: 12 }) {
      Column({ space: 8 }) {
        Text($r('app.string.device_capacity_label'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextInput({
          text: this.capacityText,
          placeholder: '60'
        })
          .fontSize(15)
          .height(48)
          .backgroundColor($r('app.color.bg_card'))
          .borderRadius(12)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.capacityText = v;
          })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text($r('app.string.device_range_label'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextInput({
          text: this.rangeText,
          placeholder: '500'
        })
          .fontSize(15)
          .height(48)
          .backgroundColor($r('app.color.bg_card'))
          .borderRadius(12)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.rangeText = v;
          })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text($r('app.string.device_stat_mode_label'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Row({ space: 10 }) {
          this.StatChip('CLTC', $r('app.string.stat_mode_cltc'))
          this.StatChip('WLTC', $r('app.string.stat_mode_wltc'))
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  StatChip(mode: string, label: ResourceStr) {
    Text(label)
      .fontSize(14)
      .fontColor(this.statMode === mode ? $r('app.color.text_on_brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.statMode === mode ? $r('app.color.brand') : $r('app.color.bg_card'))
      .borderRadius(12)
      .height(40)
      .padding({ left: 20, right: 20 })
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.statMode = mode;
      })
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
