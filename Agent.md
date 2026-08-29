# Agent.md

面向 AI 编码助手的项目说明。改动代码前请先读本文件，再按需阅读 README.md 与相关源码。

## 项目概览

电量记录（EnergyCollect）——HarmonyOS ArkTS 电量记录应用（API 26，HarmonyOS 26.0.0）。支持多设备（电动车/新能源汽车/充电宝/手机/笔记本/其他）的使用、充电、闲置会话记录，含 mpchart 数据可视化、HDS 沉浸式 UI、JSON 导入导出备份。内置蓝牙自动会话引擎（对绑定设备：连接自动开使用会话、断开宽限后结束、充用互斥）与电量同步基础设施。

- 语言：ArkTS（声明式 UI，Stage 模型），仅 `entry` 一个模块，设备类型 `phone`
- 主要依赖：`@ohos/mpchart` 3.0.25；测试依赖：`@ohos/hypium`、`@ohos/hamock`
- 数据存储：`@kit.ArkData` relationalStore（关系型数据库）+ preferences（偏好）
- 构建系统：hvigor（`hvigorw`），SDK 26.0.0

## 常用命令

```bash
# 安装依赖（首次或 oh-package.json5 变更后）
ohpm install

# Debug 构建
hvigorw assembleHap -p buildMode=debug

# Release 构建（输出 entry/build/default/outputs/default/entry-default-signed.hap）
hvigorw assembleHap -p buildMode=release

# 运行到已连接设备/模拟器
hdc install entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b <bundleName>
```

> 构建产物、`oh_modules`、`build`、`.hvigor` 等目录已 gitignore，不要提交。
> `entry/build-profile.json5` 中 release 混淆（obfuscation）默认 **未启用**，发布前如需开启需另行配置。

## 目录结构

```
entry/src/main/ets/
├── entryability/EntryAbility.ets   # UIAbility 入口（沉浸式配置、主题、数据初始化、异常会话清理）
├── pages/
│   ├── Index.ets                   # 主页：HdsTabs 三 Tab 容器
│   └── tabs/
│       ├── HomeTab.ets             # 首页：多设备卡片列表（DeviceCard 内嵌）
│       ├── HistoryTab.ets          # 历史页：折线图 + 柱状图 + 会话列表 + 周期筛选
│       └── MineTab.ets             # 我的页：设备管理、设置、导入导出
├── components/
│   ├── BatteryInputDialog.ets      # 电量+续航输入弹窗（滑杆 + −/＋ 微调；结束蓝牙设备会话时默认预填同步电量）
│   ├── NoteEditDialog.ets          # 会话备注编辑弹窗
│   ├── DeviceDialog.ets            # 设备创建/编辑表单（含新能源字段）
│   ├── SessionItem.ets             # 历史会话条目（点击编辑备注）
│   ├── LineChart.ets               # mpchart 折线图封装
│   ├── SessionBarChart.ets         # mpchart 柱状图封装
│   └── StatCard.ets / EmptyState.ets
├── model/                          # Device / Session / SessionType / ChartPoint / ChartTooltip
├── data/
│   ├── Database.ets                # 建表 + 兼容迁移（ALTER TABLE）
│   ├── PreferencesUtil.ets         # 主题 / 默认设备等偏好
│   ├── DataNotifier.ets            # 跨 Tab 定向数据变更通知
│   └── repository/                 # DeviceRepository / SessionRepository
└── utils/
    ├── CalcUtil.ets                # 电量/续航/kWh 统计计算（纯函数，可单测）
    ├── DateTimeUtil.ets            # 时间格式化（毫秒精度）
    ├── BluetoothService.ets        # 蓝牙 API 封装（权限/开关/连接枚举/三路电量读取/事件订阅）
    ├── EarphoneSyncManager.ets     # 蓝牙自动会话引擎（对账式状态机，见下文）
    └── Immersive.ets               # 沉浸式窗口配置

entry/src/test/        # 本地单元测试（hypium，纯逻辑，无设备依赖）
entry/src/ohosTest/    # 仪器化测试（需要设备/模拟器）
entry/src/mock/        # hamock mock 配置
```

## 数据模型与业务规则（改动前必读）

- `SessionType` 枚举：`USAGE=0 / IDLE=1 / CHARGING=2`，数据库存数值，**不要改数字含义**
- `devices` 表：`id / name / icon / sortOrder / archived / createdAt / batteryCapacity / rangeRated / statMode`（后三者为新能源汽车字段）+ 蓝牙字段 `btDeviceId / btName / btBattery / btLeftBattery / btRightBattery / btBoxBattery / btCharging / btSyncAt / btConnState`
- `sessions` 表：`id / deviceId / type / startBattery / endBattery / startTime / endTime / note / startRange / endRange / source`（`source`：manual/auto_bt/auto_charge）
- 充电会话要求结束电量 ≥ 开始电量
- 闲置耗电（IDLE）自动补录：仅在「开始使用」时若当前电量低于上次结束电量触发；充电会话不触发
- 启动时自动结束超过 12 小时未结束的「进行中」会话（保留电量、时长清零）
- 默认设备：首个添加的设备自动成为默认；首页置顶 + 历史页默认显示
- 新能源汽车：历史页统计用 kWh（电量% × 容量）而非百分比；续航按比例弱关联跟随
- 数据库兼容：结构变更优先用启动时 `ALTER TABLE` 迁移，避免破坏旧库
- 图表 x 轴按序号均等间距（真实时间仅作轴标签）；`LineChart` 纯线条、`SessionBarChart` 柱色约定：使用红/充电绿/空闲黄；两者点击数据点经 `onTap` 上抛 `ChartTooltipData`，悬浮详情由 HistoryTab 统一渲染与隐藏
- 图表点位归属由 `ChartPoint.session` 引用携带（勿按时间戳反查会话，相邻会话衔接点时间戳相同）；图表色值硬编码在组件内、与 `color.json` 保持同步，调整色板需两处同步
- 跨 Tab 数据刷新走 `DataNotifier` 定向通知（notifyHome/notifyHistory/notifyMine/notifyAll），勿在页面间直接持有引用
- ForEach 键值必须包含条目渲染的全部易变内容——同键复用时 itemGenerator 不会重新执行，漏掉的字段在数据更新后会显示旧值；首页卡片另依赖 `@Observed` 的 `DeviceCardData` 原地赋值刷新
- 启动顺序：`loadContent` 先于数据库初始化（避免首帧阻塞）；库就绪后 EntryAbility.`initData` 用 `DataNotifier.notifyAll()` 触发各 Tab 首次加载

## 蓝牙自动会话引擎（EarphoneSyncManager）

- 设备类型只有 6 种（ev/nev/powerbank/phone/laptop/other），**没有耳机分类**；但数据库与引擎保留蓝牙基础设施（历史原因，静默待命）
- 引擎对 `btDeviceId` 非空的绑定设备工作：**事件（连接/电量/蓝牙开关变化）只作触发器，真相以重查 A2DP∪HFP 连接列表为准**，对账式状态机求差异后应用最小转换
- 连接边沿（断开→连接）：无活跃会话才自动开 USAGE（source=auto_bt），已有会话（含手动）一律忽略——幂等闸门防二次开始
- 断开边沿：有使用会话则 2 分钟宽限（`DISCONNECT_GRACE_MS`）后结束；宽限定时器**只在首次断开时挂一次，后续事件不得重置**（否则任何蓝牙事件都会无限顺延结算）；回前台/冷启动发现的后台断开走「立即结算」路径（`reconcile(immediateDisconnect=true)`）
- 启动基线对账（`reconcile(false,true)`）：启动时已连接 ≠ 刚刚连接，只落状态不开会话；库里有会话但设备已断开则立即收尾
- 充用互斥：充电状态 0→1 立即结束使用会话并开充电会话（auto_charge）；1→0 结束充电、若仍连接且无会话自动续用
- 电量同步：读到 -1（瞬态无效值，如重连瞬间）**一律跳过不写库**，防止覆盖上次有效电量
- 连接状态持久化在 `devices.bt_conn_state`（跨进程边沿判定依据）；`onForeground` 走 `reconcileOnForeground()` 结算后台冻结期间错过的变化
- 平台限制（须知）：应用退后台被冻结后收不到任何蓝牙事件，期间变化在回前台瞬间结算（时间=发现时刻）；API 26 起对端 MAC 虚拟化，绑定 ID 在卸载重装后可能失效
- 蓝牙权限 `ohos.permission.ACCESS_BLUETOOTH`：引擎启动只静默检查不弹窗（无权限即跳过），权限申请只发生在未来可能的用户主动流程里

## 编码约定

- ArkTS 严格模式（`caseSensitiveCheck: true`、`useNormalizedOHMUrl: true`）：大小写敏感，导入使用归一化 OHM URL（`@ohos/...`、`@kit/...`），**不要用相对路径导入 SDK 包**
- UI 文案放在 `resources`（`$string`/`$media`/`$color` 引用），不在代码中硬编码；带参数的文案用 `%1$d` 占位符并经 `$r('app.string.xxx', args)` 传参，勿在代码中拼接中文句子；应用语言为中文
- 业务计算放 `utils/CalcUtil` 等纯函数模块，便于 hypium 单测；数据库访问走 `data/repository` 层，页面不直接操作 relationalStore
- 新增测试写在 `entry/src/test/*.test.ets`（本地逻辑）或 `entry/src/ohosTest`（设备相关），用 hypium 的 `describe/it/expect`
- 修改 model/DB schema 时同步检查 `Database.ets` 迁移逻辑、导入导出 JSON 校验与 `README.md` 数据模型章节

## 常见坑

- 修改 `oh-package.json5` 后必须 `ohpm install`，否则编译报找不到模块
- 沉浸式 UI 依赖 `expandSafeArea` 与 `avoidAreaChange` 监听，改动窗口配置时注意状态栏/导航栏高度自适应（旋转等窗口变化）
- 勿提交构建产物、签名文件、`local.properties`（含本机 SDK 路径）
- **`build-profile.json5` 中的 `signingConfigs` 签名配置（调试或正式）绝对不允许提交**。当前该文件已被设置 `git update-index --skip-worktree`，本地签名改动对 git 隐形；若需改回跟踪状态先 `git update-index --no-skip-worktree build-profile.json5`。克隆新机器后需在 DevEco 里重新配置自动签名
