import { HdsNavigation } from '@kit.UIDesignKit';
import { DeviceSheet } from '../../components/DeviceSheet';
import { Device, iconToResource, iconToNameRes } from '../../model/Device';
import { Session } from '../../model/Session';
import { SessionType } from '../../model/SessionType';
import { DeviceRepository } from '../../data/repository/DeviceRepository';
import { SessionRepository } from '../../data/repository/SessionRepository';
import { PreferencesUtil } from '../../data/PreferencesUtil';
import { Immersive } from '../../utils/Immersive';
import { promptAction, window } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { picker, fileIo } from '@kit.CoreFileKit';
import util from '@ohos.util';

interface DeviceExportRow {
  name: string;
  icon: string;
}

interface ExportDeviceV2 {
  name: string;
  icon: string;
  capacity: number;
  rangeRated: number;
  statMode: string;
}

interface ExportSessionV2 {
  deviceIndex: number;
  type: number;
  startBattery: number;
  endBattery: number;
  startTime: number;
  endTime: number;
  note: string;
  startRange: number;
  endRange: number;
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
      const deviceRows: ExportDeviceV2[] = [];
      const idToIndex: Map<number, number> = new Map<number, number>();
      for (let i = 0; i < devices.length; i++) {
        const d: Device = devices[i];
        idToIndex.set(d.id, i);
        const row: ExportDeviceV2 = {
          name: d.name, icon: d.icon,
          capacity: d.batteryCapacity, rangeRated: d.rangeRated, statMode: d.statMode
        };
        deviceRows.push(row);
      }
      const sessions: Session[] = await this.sessionRepo.listFiltered(0, -1);
      const sessionRows: ExportSessionV2[] = [];
      for (const s of sessions) {
        const idx: number | undefined = idToIndex.get(s.deviceId);
        if (idx !== undefined) {
          sessionRows.push({
            deviceIndex: idx, type: s.type, startBattery: s.startBattery, endBattery: s.endBattery,
            startTime: s.startTime, endTime: s.endTime, note: s.note,
            startRange: s.startRange, endRange: s.endRange
          });
        }
      }
      const payload: Record<string, Object> = {
        'app': 'EnergyCollect',
        'version': 2,
        'exportedAt': Date.now(),
        'devices': deviceRows,
        'sessions': sessionRows
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

  private async importData(): Promise<void> {
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      const selectPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      const uris: string[] = await selectPicker.select(options);
      if (uris === undefined || uris === null || uris.length === 0) {
        return;
      }
      const file: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      const stat: fileIo.Stat = fileIo.statSync(file.fd);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = decoder.decodeWithStream(new Uint8Array(buf));
      const parsed: Object = JSON.parse(text);
      const obj: Record<string, Object> = parsed as Record<string, Object>;
      const appField: Object | undefined = obj['app'];
      if (appField === undefined || typeof appField !== 'string' || appField !== 'EnergyCollect') {
        promptAction.showToast({ message: $r('app.string.toast_import_fail') });
        return;
      }
      const devField: Object | undefined = obj['devices'];
      if (devField === undefined || !(devField instanceof Array)) {
        promptAction.showToast({ message: $r('app.string.toast_import_fail') });
        return;
      }
      const devArr: Object[] = devField as Object[];
      const indexToNewId: Map<number, number> = new Map<number, number>();
      let devCount: number = 0;
      for (let i = 0; i < devArr.length; i++) {
        const row: Record<string, Object> = devArr[i] as Record<string, Object>;
        const nameField: Object | undefined = row['name'];
        const iconField: Object | undefined = row['icon'];
        if (nameField !== undefined && typeof nameField === 'string' && nameField.length > 0 &&
          iconField !== undefined && typeof iconField === 'string') {
          const newId: number = await this.deviceRepo.insert(
            nameField, iconField,
            this.readNumber(row['capacity']),
            this.readNumber(row['rangeRated']),
            this.readString(row['statMode'])
          );
          indexToNewId.set(i, newId);
          devCount++;
        }
      }
      let sessCount: number = 0;
      const sessField: Object | undefined = obj['sessions'];
      if (sessField !== undefined && sessField instanceof Array) {
        const sessArr: Object[] = sessField as Object[];
        for (const item of sessArr) {
          const row: Record<string, Object> = item as Record<string, Object>;
          const idx: number = this.readNumber(row['deviceIndex']);
          const newDeviceId: number | undefined = indexToNewId.get(idx);
          if (newDeviceId === undefined) {
            continue;
          }
          const typeNum: number = this.readNumber(row['type']);
          const type: SessionType = typeNum === 2 ? SessionType.CHARGING : (typeNum === 1 ? SessionType.IDLE : SessionType.USAGE);
          await this.sessionRepo.importSession(
            newDeviceId, type,
            this.readNumber(row['startBattery']),
            this.readNumber(row['endBattery']),
            this.readNumber(row['startTime']),
            this.readNumber(row['endTime']),
            this.readString(row['note']),
            this.readNumber(row['startRange']),
            this.readNumber(row['endRange'])
          );
          sessCount++;
        }
      }
      if (devCount > 0 || sessCount > 0) {
        this.bump();
        promptAction.showToast({ message: $r('app.string.toast_import_success') });
      } else {
        promptAction.showToast({ message: $r('app.string.toast_import_fail') });
      }
    } catch (e) {
      promptAction.showToast({ message: $r('app.string.toast_import_fail') });
    }
  }

  private readNumber(field: Object | undefined): number {
    if (field !== undefined && typeof field === 'number') {
      return field;
    }
    return 0;
  }

  private readString(field: Object | undefined): string {
    if (field !== undefined && typeof field === 'string') {
      return field;
    }
    return '';
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
