# 电量记录（EnergyCollect）

一款 HarmonyOS ArkTS 电量记录应用，支持多设备的电量使用/充电/闲置会话记录，内置数据可视化图表与完整数据备份。采用 HDS 沉浸光感套件打造现代化 UI。

## 功能特性

### 设备管理
- 多设备记录（电动车、新能源汽车、充电宝、手机、耳机、笔记本、其他）
- 默认设备：可设置一个设备为默认，首页置顶 + 历史页默认显示，首个添加的设备自动成为默认
- 每设备独立卡片展示：设备名 + 当前电量 + 续航（新能源汽车）

### 会话记录
- **使用会话**：记录设备使用时的电量消耗
- **充电会话**：记录充电补充的电量（结束电量 ≥ 开始电量）
- **空闲耗电**：自动补录——开始使用会话时若电量低于上次结束电量，自动插入一条闲置耗电记录，保持电量链条连续
- 实时计时：进行中的会话显示已用时长
- 备注：每次会话可附加文字备注；历史页点击会话条目可随时编辑/清空备注
- 电量微调：弹窗中大数字两侧提供 − / + 按钮点击步进（电量 1%、续航 1km），避免滑杆难以精调

### 新能源汽车专属
- 设备创建时设置：电池容量(kWh)、标称续航(km)、续航标准(CLTC/WLTC)
- 会话输入电量% 时，续航(km)按比例**弱关联**自动跟随
- 历史页统计该类设备使用 **kWh**（电量% × 容量）而非百分比

### 数据可视化（@ohos/mpchart）
- **折线图**：电量趋势（纯线条 + 横线背景，无数据点，不可点击）
- **柱状图**：每次会话的耗电/充电（使用红、充电绿、空闲黄；背景仅横线，不可点击）
- x 轴采用真实时间戳：点距与时间间隔成正比，标签按时间格式化（当天显示时:分，跨天显示月/日）；柱宽按时间跨度自适应
- 支持左右拖拽浏览，禁用缩放与点击高亮

### 数据统计
- 首页卡片：今日会话数 / 今日补能 / 今日耗能
- 历史页：支持 **全部 / 本周 / 本月** 周期筛选，统计卡片与图表联动（新能源汽车用 kWh）

### 沉浸式 UI（HDS 套件）
- `HdsTabs` 悬浮胶囊底部导航 + 沉浸光感材质（毛玻璃）
- `HdsNavigation` 标题栏（已隐藏，采用纯沉浸式）
- 垂直线性渐变背景（顶部 #E8EEFE → 底部 #D8E3F7）
- expandSafeArea 让渐变延伸至状态栏
- 监听 avoidAreaChange 动态更新状态栏/导航栏高度，旋转等窗口变化自适应
- 深浅色模式自适应

### 数据备份
- **导出**：完整备份设备配置（含新能源字段）+ 全部会话记录（JSON）
- **导入**：从 JSON 恢复（校验备份版本；支持合并/替换两种方式），设备 id 自动映射，保持设备-会话关联；导入后自动修正默认设备

## 技术栈

| 类别 | 技术 |
|---|---|
| 框架 | HarmonyOS ArkTS（声明式 UI） |
| UI 套件 | `@kit.UIDesignKit`（HDS：HdsTabs / HdsNavigation） |
| 图表 | `@ohos/mpchart` 3.0.25（LineChart / BarChart） |
| 数据存储 | `@kit.ArkData` relationalStore（关系型数据库） |
| 偏好存储 | `@kit.ArkData` preferences |
| 文件选择 | `@kit.CoreFileKit`（picker / fileIo） |
| 文本解码 | `@kit.ArkTS`（util TextDecoder UTF-8） |
| 兼容 SDK | HarmonyOS 26.0.0（API 26） |

## 项目结构

```
entry/src/main/ets/
├── entryability/          # UIAbility 入口（沉浸式配置、主题、数据初始化）
├── pages/
│   ├── Index.ets          # 主页（HdsTabs 三 Tab 容器）
│   └── tabs/
│       ├── HomeTab.ets    # 首页（多设备卡片 + DeviceCard 组件）
│       ├── HistoryTab.ets # 历史页（折线图 + 柱状图 + 会话列表）
│       └── MineTab.ets    # 我的页（设备管理 + 设置 + 导入导出）
├── components/
│   ├── DeviceCard (内嵌)  # 设备卡片（电量/续航/会话操作/计时）
│   ├── BatteryInputDialog # 电量+续航输入弹窗（含 ± 微调按钮）
│   ├── NoteEditDialog     # 会话备注编辑弹窗
│   ├── DeviceSheet        # 设备创建/编辑表单（含新能源字段）
│   ├── SessionItem        # 历史会话条目（毫秒时间/电量/备注，点击可编辑备注）
│   ├── LineChart (TrendChart)   # mpchart 折线图封装
│   ├── SessionBarChart    # mpchart 柱状图封装
│   ├── StatCard / EmptyState    # 通用组件
├── model/                 # 数据模型（Device / Session / SessionType / ChartPoint）
├── data/
│   ├── Database.ets       # 数据库 schema + 兼容迁移（ALTER TABLE）
│   ├── PreferencesUtil    # 偏好存储（主题/默认设备）
│   └── repository/        # DeviceRepository / SessionRepository
└── utils/
    ├── CalcUtil           # 电量/续航/kWh 统计计算
    ├── DateTimeUtil       # 时间格式化（含毫秒精度）
    └── Immersive          # 沉浸式窗口配置
```

## 数据模型

### Device（设备）
`id / name / icon / sortOrder / archived / createdAt / batteryCapacity / rangeRated / statMode`

### Session（会话）
`id / deviceId / type(USAGE=0/IDLE=1/CHARGING=2) / startBattery / endBattery / startTime / endTime / note / startRange / endRange`

### 数据库表
- `devices`：含电池容量/标称续航/统计模式（新能源汽车字段）
- `sessions`：含起止续航（新能源汽车字段）
- 启动时自动 ALTER TABLE 兼容旧库升级

## 构建与运行

### 环境要求
- DevEco Studio 6.0.2+
- HarmonyOS SDK 26.0.0（API 26）
- HarmonyOS 真机或模拟器

### 安装依赖
```bash
ohpm install
```

### 构建
- Debug：DevEco Studio 运行按钮，或 `hvigorw assembleHap -p buildMode=debug`
- Release：`hvigorw assembleHap -p buildMode=release`（输出 entry/build/default/outputs/default/entry-default-signed.hap）

### 运行
连接 HarmonyOS 设备/模拟器后，DevEco Studio 点击运行，或：
```bash
hdc install entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b <bundleName>
```

## 使用流程

1. **添加设备**：首页空状态或我的页 → 添加设备（选图标、填名称；新能源汽车填容量/续航/标准）
2. **记录会话**：设备卡片点「开始使用」或「开始充电」→ 弹窗输入当前电量（拖滑杆或用 − / + 微调，新能源汽车续航跟随）→ 进行中显示计时 → 点「结束会话」输入结束电量
3. **查看历史**：历史页查看折线趋势、柱状耗充、会话详情（毫秒时间/电量变化/备注）；点击会话条目可编辑备注
4. **数据备份**：我的页 → 导出数据（生成 JSON）→ 需要时导入数据恢复

## 备注

- 闲置掉电自动补录仅对「开始使用」触发（充电会话不触发）
- 启动时自动结束超过 12 小时未结束的异常「进行中」会话（保留电量、时长清零），防止应用被中断后会话永久显示进行中
- 「我的」页版本号从应用包动态读取，与 app.json5 保持一致
- 新能源汽车的 kWh 统计仅在历史页该设备选中时切换为绝对值单位
- 代码混淆（obfuscation）默认未启用，发布前如需请在 build-profile.json5 配置
