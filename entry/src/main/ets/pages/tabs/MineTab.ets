import { HdsNavigation } from '@kit.UIDesignKit';
import { DeviceSheet } from '../../components/DeviceSheet';
import { Device, iconToResource, iconToNameRes } from '../../model/Device';
import { DeviceRepository } from '../../data/repository/DeviceRepository';
import { SessionRepository } from '../../data/repository/SessionRepository';
import { PreferencesUtil } from '../../data/PreferencesUtil';
import { Immersive } from '../../utils/Immersive';
import { promptAction, window } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { picker, fileIo } from '@kit.CoreFileKit';

interface DeviceExportRow {
  name: string;
  icon: string;
}

@Component
export struct MineTab {
  @StorageProp('dataVersion') @Watch('reload') dataVersion: number = 0;
  @StorageProp('colorMode') @Watch('onColorModeChanged') colorMode: number = -1;
  @State devices: Device[] = [];
  @State showSheet: boolean = false;
  @State sheetTitle: ResourceStr = $r('app.string.dialog_new_device_title');
  @State sheetName: string = '';
  @State sheetIcon: string = 'other';
  @State sheetId: number = 0;
  @State sheetCanDelete: boolean = false;
  @State sheetCapacity: number = 0;
  @State sheetRange: number = 0;
  @State sheetStatMode: string = 'CLTC';
  @State sheetIsDefault: boolean = false;
  @StorageProp('defaultDeviceId') defaultDeviceId: number = -1;

  private deviceRepo: DeviceRepository = new DeviceRepository();
  private sessionRepo: SessionRepository = new SessionRepository();
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.loadData();
  }

  private async loadData(): Promise<void> {
    this.devices = await this.deviceRepo.listAll(true);
  }

  private bump(): void {
    const v: number = AppStorage.get<number>('dataVersion') ?? 0;
    AppStorage.setOrCreate('dataVersion', v + 1);
  }

  onColorModeChanged(): void {
  }

  private openAddSheet(): void {
    this.sheetId = 0;
    this.sheetName = '';
    this.sheetIcon = 'other';
    this.sheetCapacity = 0;
    this.sheetRange = 0;
    this.sheetStatMode = 'CLTC';
    this.sheetIsDefault = false;
    this.sheetTitle = $r('app.string.dialog_new_device_title');
    this.sheetCanDelete = false;
    this.showSheet = true;
  }

  private openEditSheet(d: Device): void {
    this.sheetId = d.id;
    this.sheetName = d.name;
    this.sheetIcon = d.icon;
    this.sheetCapacity = d.batteryCapacity;
    this.sheetRange = d.rangeRated;
    this.sheetStatMode = d.statMode.length > 0 ? d.statMode : 'CLTC';
    this.sheetIsDefault = d.id === this.defaultDeviceId;
    this.sheetTitle = $r('app.string.dialog_edit_device_title');
    this.sheetCanDelete = true;
    this.showSheet = true;
  }

  private async onSaveDevice(name: string, icon: string, capacity: number, rangeRated: number, statMode: string): Promise<void> {
    if (this.sheetId === 0) {
      const id: number = await this.deviceRepo.insert(name, icon, capacity, rangeRated, statMode);
      const cur: number = AppStorage.get<number>('currentDeviceId') ?? -1;
      if (cur <= 0) {
        AppStorage.setOrCreate('currentDeviceId', id);
        PreferencesUtil.setCurrentDeviceId(id);
      }
    } else {
      await this.deviceRepo.update(this.sheetId, name, icon, capacity, rangeRated, statMode);
    }
    this.showSheet = false;
    this.bump();
  }

  private async onSetDefaultDevice(): Promise<void> {
    if (this.sheetId <= 0) {
      return;
    }
    AppStorage.setOrCreate('defaultDeviceId', this.sheetId);
    await PreferencesUtil.setDefaultDeviceId(this.sheetId);
    this.showSheet = false;
    this.bump();
  }

  private async onDeleteDevice(): Promise<void> {
    if (this.sheetId <= 0) {
      return;
    }
    const deleteId: number = this.sheetId;
    this.showSheet = false;
    await this.deviceRepo.delete(deleteId);
    const cur: number = AppStorage.get<number>('currentDeviceId') ?? -1;
    if (cur === deleteId) {
      const remaining: Device[] = await this.deviceRepo.listAll(false);
      const next: number = remaining.length > 0 ? remaining[0].id : -1;
      AppStorage.setOrCreate('currentDeviceId', next);
      PreferencesUtil.setCurrentDeviceId(next);
    }
    this.bump();
  }

  private async applyColorMode(mode: number): Promise<void> {
    AppStorage.setOrCreate('colorMode', mode);
    await PreferencesUtil.setColorMode(mode);
    const ctx: Context = getContext(this);
    let constMode: number;
    if (mode === 1) {
      constMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (mode === 0) {
      constMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else {
      constMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    }
    try {
      ctx.getApplicationContext().setColorMode(constMode);
    } catch (e) {
    }
    try {
      const win: window.Window = await window.getLastWindow(ctx);
      const sysMode: number = AppStorage.get<number>('systemColorMode') ?? 0;
      await Immersive.applySystemBar(win, Immersive.isDarkMode(mode, sysMode));
    } catch (e) {
    }
  }

  private colorModeLabel(): ResourceStr {
    if (this.colorMode === 1) {
      return $r('app.string.mine_color_mode_dark');
    }
    if (this.colorMode === 0) {
      return $r('app.string.mine_color_mode_light');
    }
    return $r('app.string.mine_color_mode_auto');
  }

  private buildColorModeMenu(): MenuElement[] {
    return [
      {
        value: $r('app.string.mine_color_mode_auto'),
        action: (): void => {
          this.applyColorMode(-1);
        }
      },
      {
        value: $r('app.string.mine_color_mode_light'),
        action: (): void => {
          this.applyColorMode(0);
        }
      },
      {
        value: $r('app.string.mine_color_mode_dark'),
        action: (): void => {
          this.applyColorMode(1);
        }
      }
    ];
  }

  private async exportData(): Promise<void> {
    try {
      const devices: Device[] = await this.deviceRepo.listAll(true);
      const rows: DeviceExportRow[] = [];
      for (const d of devices) {
        const row: DeviceExportRow = { name: d.name, icon: d.icon };
        rows.push(row);
      }
      const payload: Record<string, Object> = {
        'app': 'EnergyCollect',
        'version': 1,
        'exportedAt': Date.now(),
        'deviceCount': devices.length,
        'devices': rows
      };
      const json: string = JSON.stringify(payload);
      const saveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [`energy_export_${Date.now()}.json`];
      const savePicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      const uris: string[] = await savePicker.save(saveOptions);
      if (uris === undefined || uris === null || uris.length === 0) {
        return;
      }
      const file: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(file.fd, json);
      fileIo.closeSync(file);
      promptAction.showToast({ message: $r('app.string.toast_export_success') });
    } catch (e) {
      promptAction.showToast({ message: $r('app.string.toast_export_fail') });
    }
  }

  private importData(): void {
    promptAction.showToast({ message: $r('app.string.toast_import_fail') });
  }

  private confirmClear(): void {
    promptAction.showDialog({
      title: $r('app.string.dialog_clear_title'),
      message: $r('app.string.dialog_clear_desc'),
      buttons: [
        { text: $r('app.string.action_cancel'), color: $r('app.color.text_secondary') },
        { text: $r('app.string.action_confirm'), color: $r('app.color.danger') }
      ]
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1) {
        this.doClear();
      }
    });
  }

  private async doClear(): Promise<void> {
    await this.sessionRepo.deleteAll();
    AppStorage.setOrCreate('currentDeviceId', -1);
    PreferencesUtil.setCurrentDeviceId(-1);
    this.bump();
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: 16 }) {
          this.DevicesSection()
          this.SettingsSection()
          this.AboutItem()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 96 + this.navBarHeight })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .hideTitleBar(true)
    .padding({ top: this.statusBarHeight })
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.bg_gradient_start'), 0.0], [$r('app.color.bg_gradient_end'), 1.0]]
    })
    .bindSheet($$this.showSheet, this.SheetBuilder(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      backgroundColor: $r('app.color.bg_primary')
    })
  }

  @Builder
  SheetBuilder() {
    DeviceSheet({
      sheetTitle: this.sheetTitle,
      initialName: this.sheetName,
      initialIcon: this.sheetIcon,
      initialCapacity: this.sheetCapacity,
      initialRange: this.sheetRange,
      initialStatMode: this.sheetStatMode,
      canDelete: this.sheetCanDelete,
      isDefault: this.sheetIsDefault,
      onSave: (name: string, icon: string, capacity: number, rangeRated: number, statMode: string): void => {
        this.onSaveDevice(name, icon, capacity, rangeRated, statMode);
      },
      onDelete: (): void => {
        this.confirmDeleteDevice();
      },
      onSetDefault: (): void => {
        this.onSetDefaultDevice();
      },
      onClose: (): void => {
        this.showSheet = false;
      },
      onInvalid: (): void => {
        promptAction.showToast({ message: $r('app.string.toast_name_empty') });
      }
    })
  }

  private confirmDeleteDevice(): void {
    promptAction.showDialog({
      title: $r('app.string.dialog_delete_device_title'),
      message: $r('app.string.dialog_delete_device_desc'),
      buttons: [
        { text: $r('app.string.action_cancel'), color: $r('app.color.text_secondary') },
        { text: $r('app.string.action_delete'), color: $r('app.color.danger') }
      ]
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1) {
        this.onDeleteDevice();
      }
    });
  }

  @Builder
  DevicesSection() {
    Column({ space: 10 }) {
      Text($r('app.string.mine_section_devices'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      if (this.devices.length === 0) {
        Row() {
          Text($r('app.string.home_no_device_title'))
            .fontSize(14)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(14)
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 10 }) {
          ForEach(this.devices, (d: Device) => {
            this.DeviceRow(d)
          }, (d: Device) => `m${d.id}`)
        }
        .width('100%')
      }

      this.AddDeviceButton()
    }
    .width('100%')
  }

  @Builder
  DeviceRow(d: Device) {
    Row({ space: 12 }) {
      Stack() {
        Text('')
          .width(40)
          .height(40)
          .backgroundColor($r('app.color.brand_light'))
          .borderRadius(20)
        Image(iconToResource(d.icon))
          .width(22)
          .height(22)
          .fillColor($r('app.color.brand'))
      }
      .width(40)
      .height(40)

      Text(d.name)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (d.id === this.defaultDeviceId) {
        Text($r('app.string.device_default_badge'))
          .fontSize(11)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_light'))
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ right: 8 })
      }

      Text(iconToNameRes(d.icon))
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(14)
    .onClick(() => {
      this.openEditSheet(d);
    })
  }

  @Builder
  AddDeviceButton() {
    Row({ space: 8 }) {
      Text('+')
        .fontSize(18)
        .fontColor($r('app.color.brand'))
      Text($r('app.string.mine_add_device'))
        .fontSize(14)
        .fontColor($r('app.color.brand'))
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(14)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.openAddSheet();
    })
  }

  @Builder
  SettingsSection() {
    Column({ space: 10 }) {
      Text($r('app.string.mine_section_settings'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Column() {
        this.SettingItem($r('app.string.mine_export'), false, () => {
          this.exportData();
        })
        this.DividerLine()
        this.SettingItem($r('app.string.mine_import'), false, () => {
          this.importData();
        })
        this.DividerLine()
        Row() {
          Text($r('app.string.mine_color_mode'))
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(this.colorModeLabel())
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
          Text('›')
            .fontSize(18)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ left: 6 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .bindMenu(this.buildColorModeMenu())
        this.DividerLine()
        this.SettingItem($r('app.string.mine_clear_data'), true, () => {
          this.confirmClear();
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.bg_card'))
      .borderRadius(14)
    }
    .width('100%')
  }

  @Builder
  SettingItem(label: ResourceStr, danger: boolean, tap: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(danger ? $r('app.color.danger') : $r('app.color.text_primary'))
      Blank()
      Text('›')
        .fontSize(18)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      tap();
    })
  }

  @Builder
  DividerLine() {
    Divider()
      .color($r('app.color.divider'))
      .strokeWidth(0.5)
      .margin({ left: 16, right: 16 })
  }

  @Builder
  AboutItem() {
    Column() {
      Row() {
        Text($r('app.string.mine_about'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(`v1.0.0`)
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    }
    .width('100%')
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(14)
  }
}
