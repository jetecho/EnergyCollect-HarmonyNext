import { DEVICE_ICON_KEYS, iconToResource, iconToNameRes } from '../model/Device';

/**
 * 设备「新增 / 编辑」模态弹窗（@CustomDialog）。
 *
 * aboutToAppear() 在每次 controller.open() 时都会触发，因此从 @Prop 初值
 * 重新初始化内部表单态，可确保每次打开都重置，从而根治此前 bindSheet 方案
 * 中「关闭后残留上一次输入 / 状态错乱」的问题。
 */
@CustomDialog
export struct DeviceDialog {
  controller: CustomDialogController;
  sheetTitle: ResourceStr = $r('app.string.dialog_new_device_title');
  initialName: string = '';
  initialIcon: string = 'other';
  initialCapacity: number = 0;
  initialRange: number = 0;
  initialStatMode: string = 'CLTC';
  canDelete: boolean = false;
  isDefault: boolean = false;
  onSave: (name: string, icon: string, capacity: number, rangeRated: number, statMode: string) => void = () => {};
  onDelete: () => void = () => {};
  onSetDefault: () => void = () => {};
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
        Text($r('app.string.symbol_close'))
          .fontSize(20)
          .fontColor($r('app.color.text_tertiary'))
          .padding(4)
          .onClick(() => {
            this.controller.close();
          })
      }
      .width('100%')

      Scroll() {
        this.DialogContent()
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .scrollBar(BarState.Auto)

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
        if (this.canDelete && !this.isDefault) {
          Button($r('app.string.device_set_default'))
            .type(ButtonType.Normal)
            .borderRadius(12)
            .layoutWeight(1)
            .backgroundColor($r('app.color.brand_light'))
            .fontColor($r('app.color.brand'))
            .onClick(() => {
              this.onSetDefault();
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
    .padding(20)
    .backgroundColor($r('app.color.bg_primary'))
  }

  @Builder
  DialogContent() {
    Column({ space: 18 }) {
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
      }
      .width('100%')

      if (this.icon === 'nev') {
        this.NevFields()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
