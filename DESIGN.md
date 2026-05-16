# NotchBay — Design Specification

> Mac 刘海区域的「灵动岛」实时状态展示工具 / Dynamic Island-style Live Activities for Mac Notch

---

## 目录 / TOC

1. [项目愿景](#1-项目愿景)
2. [竞品分析精华](#2-竞品分析精华)
3. [功能架构](#3-功能架构)
4. [视觉设计系统](#4-视觉设计系统)
5. [交互设计规范](#5-交互设计规范)
6. [技术架构](#6-技术架构)
7. [模块设计](#7-模块设计)
8. [开发路线图](#8-开发路线图)

---

## 1. 项目愿景

### 定位

MacBook Pro 的刘海（Notch）从诞生起就是一个争议设计——它占据屏幕顶部中央位置却不提供任何功能。NotchBay 将这片"空白区域"变成一个**实时信息中枢**，类似 iPhone 灵动岛的 Live Activities，但针对桌面场景深度定制。

### 核心理念

- **Glanceable（一眼可知）**：信息在刘海区域以极简形态呈现，不需要打开任何窗口
- **Context-aware（场景感知）**：根据用户当前活动自动切换展示内容
- **Non-intrusive（无打扰）**：不弹窗、不打断，像呼吸一样自然存在
- **Expandable（可展开）**：点击展开为详细面板，提供交互能力

### 目标用户

- MacBook Pro（有刘海机型）用户
- 开发者（AI 编程助手会话监控）
- 重度 Mac 用户（需要实时系统状态）

---

## 2. 竞品分析精华

### 2.1 市场格局

| 项目 | Stars | 定位 | 技术栈 | 核心亮点 |
|------|-------|------|--------|----------|
| [Ping Island](https://github.com/erha19/ping-island) | 628 | AI 编程会话监控 | Swift 6.1, SwiftUI | 支持 12+ AI 客户端，灵动岛风格，审批/追问/窗口跳转 |
| [SuperIsland](https://github.com/shobhit99/SuperIsland) | 483 | 通用灵动岛 | Swift, SwiftUI, JS Ext | 10 个内置模块（电量/天气/日历/通知/NowPlaying 等），扩展系统 |
| [AgentNotch](https://github.com/AppGram/agentnotch) | 157 | AI 编程可见性 | Swift, SwiftUI | 实时显示 Claude/Codex 思考和工具调用 |
| [Aura](https://github.com/pronzzz/aura) | 3 | 上下文命令中心 | Swift, SwiftUI | 媒体控制 + 系统状态 + 本地 AI (Ollama)，插件系统 |

### 2.2 精华提炼

**从 Ping Island 学到：**
- 单一场景做到极致 > 大而全
- 灵动岛的「紧凑→展开」二级交互是最佳模式
- macOS 14+ 的 SwiftUI API 足以实现流畅动画
- 菜单栏 app + 刘海面板的混合架构

**从 SuperIsland 学到：**
- 模块化架构，每个功能独立成 Module
- JS 扩展系统降低插件开发门槛
- 权限管理（辅助功能/日历/定位）是必备流程
- 自动更新机制是桌面 app 的生命线

**从 AgentNotch 学到：**
- 实时文件系统监控的方案（轮询 vs FSEvents）
- 进度条和状态指示器的设计
- 多 AI 客户端同时监控的架构

**从 Aura 学到：**
- 本地 AI 集成（Ollama）是差异化方向
- 自动化流程（workflow）让工具有了"手"的能力
- 插件系统可以很低成本（YAML 配置 + 脚本）

### 2.3 市场机会

当前所有竞品的共同缺陷：
1. **缺乏统一设计语言**——各模块视觉风格不一致
2. **没有场景自动切换**——用户需要手动切换查看内容
3. **缺少 iPhone Live Activities 的实时推送机制**——状态更新依赖轮询
4. **交互局限于展开/折叠**——没有利用刘海区域的横向空间做滚动/切换

---

## 3. 功能架构

### 3.1 功能全景

```
NotchBay
├── 紧凑模式 (Compact) —— 刘海区域内单行展示
│   ├── 正在播放 (Now Playing)        —— 曲目标题 + 艺术家 + 波形动画
│   ├── 电池状态 (Battery)            —— 百分比 + 充电动画
│   ├── 天气 (Weather)                —— 温度 + 图标
│   ├── 日历 (Calendar)              —— 下一日程时间 + 标题
│   ├── AI 会话 (AI Session)          —— AI 图标 + 状态点 + 工具调用名
│   ├── 通知 (Notification)          —— 图标 + 标题（3s 自动消失）
│   └── 自定义 (Custom)              —— 用户定义的信息源
│
├── 展开模式 (Expanded) —— 点击刘海区域弹出
│   ├── 媒体控制 (Media Controls)     —— 专辑封面 + 进度条 + 上下首 + 音量
│   ├── 电池详情 (Battery Detail)     —— 电池健康 + 循环次数 + 功率
│   ├── 天气详情 (Weather Detail)     —— 逐小时 + 5 日预报
│   ├── 日历列表 (Calendar List)      —— 今日日程列表
│   ├── AI 会话详情 (AI Detail)       —— 实时日志 + 审批按钮 + 终端跳转
│   └── 通知中心 (Notification Center) —— 近期通知列表
│
└── 场景自动切换 (Smart Switch)
    ├── 播放音乐时 → 自动切到 Now Playing
    ├── AI 开始思考时 → 自动切到 AI Session
    ├── 电池低于 20% → 自动切到 Battery
    ├── 日历日程前 5 分钟 → 自动切到 Calendar
    └── 默认 → 用户设置的默认模块
```

### 3.2 功能优先级

| 优先级 | 功能 | 理由 |
|--------|------|------|
| P0 | 紧凑模式框架 + 窗口管理 | 地基 |
| P0 | Now Playing 模块 | 最高频使用场景 |
| P0 | 展开/折叠交互 | 核心交互模式 |
| P1 | AI 会话监控 | 差异化杀手功能 |
| P1 | 电池状态 | 简单但实用 |
| P1 | 智能场景切换 | 核心体验差异 |
| P2 | 天气模块 | 需要 API |
| P2 | 日历模块 | 需要权限 |
| P2 | 通知中心 | 需要权限 |
| P3 | 插件/扩展系统 | 生态建设 |
| P3 | 自定义模块 | 个性化 |

---

## 4. 视觉设计系统

> 基于 ui-ux-pro-max 设计系统 + Apple Human Interface Guidelines

### 4.1 设计风格：Dark Native + Bento + Motion-Driven

综合推荐：
- **主风格**：Dark Mode (OLED) — 适配 Mac 刘海区域的深色背景，与 macOS 系统 UI 融合
- **卡片布局**：Bento Box Grid — 非对称模块化卡片，Apple 风格
- **动画**：Motion-Driven — 流畅、有弹性的微动效，类似灵动岛的弹性动画

### 4.2 色彩系统

```
┌─────────────────────────────────────────────────────┐
│  NotchBay — Dark Native Color Palette               │
├──────────────┬──────────┬───────────────────────────┤
│  角色         │ Hex      │ 用途                      │
├──────────────┼──────────┼───────────────────────────┤
│  主背景       │ #0F172A  │ 展开面板背景              │
│  副背景       │ #1E293B  │ 卡片 / 按钮背景           │
│  主文字       │ #F8FAFC  │ 标题 / 重要文字           │
│  副文字       │ #94A3B8  │ 描述 / 次要信息           │
│  强调色-蓝    │ #3B82F6  │ 默认强调 / 信息           │
│  强调色-绿    │ #22C55E  │ 成功 / AI 运行中           │
│  强调色-橙    │ #F97316  │ 警告 / 电池低 / 审批等待   │
│  强调色-红    │ #EF4444  │ 错误 / 紧急               │
│  强调色-紫    │ #8B5CF6  │ AI 相关 / 特殊             │
│  边框         │ #334155  │ 分割线 / 边框              │
│  毛玻璃       │ 系统材质  │ 紧凑模式窗口背景          │
└──────────────┴──────────┴───────────────────────────┘
```

### 4.3 紧凑模式颜色映射

```
正在播放   →  #F8FAFC (白色波形)  + 毛玻璃暗底
电池正常   →  #22C55E (绿色)
电池低     →  #EF4444 (红色)
AI 思考中  →  #8B5CF6 (紫色脉冲)
AI 执行中  →  #22C55E (绿色)
AI 等待审批 → #F97316 (橙色呼吸)
日历即将   →  #3B82F6 (蓝色)
```

### 4.4 排版

macOS 原生字体系统（不引入自定义字体）：
- **展示文字**: SF Pro Display (系统自带)
- **正文/UI**: SF Pro Text (系统自带)
- **等宽**: SF Mono (系统自带)，用于 AI 日志显示

字号体系（紧凑模式）：
- 主信息：12pt (紧凑模式空间有限)
- 副信息：10pt
- 图标：SFSymbols，与文字同高

字号体系（展开模式）：
- 标题：17pt Semibold
- 正文：13pt Regular
- 标签：11pt Medium

### 4.5 图标

全部使用 **SF Symbols 6**（macOS 自带，无需额外资源）：
- `play.fill`, `pause.fill`, `forward.fill`, `backward.fill` — 媒体控制
- `battery.100percent`, `battery.25` — 电池状态
- `sun.max.fill`, `cloud.rain.fill` — 天气
- `calendar`, `clock` — 日历
- `brain.head.profile`, `sparkles` — AI 会话
- `bell.fill` — 通知
- `chevron.left`, `chevron.right` — 导航

### 4.6 视觉效果

| 效果 | 用途 | 参数 |
|------|------|------|
| 毛玻璃 (Material) | 紧凑模式窗口 | `.ultraThinMaterial` + 深色模式 |
| 弹性动画 (Spring) | 展开/折叠 | response: 0.5, dampingFraction: 0.7 |
| 脉冲动画 | AI 思考中 | opacity: 0.4 → 1.0, 1.5s easeInOut |
| 呼吸动画 | 等待审批 | scale: 1.0 → 1.05, 2s easeInOut |
| 颜色过渡 | 场景切换 | 300ms easeInOut |
| 阴影 | 展开面板 | 系统默认阴影，radius: 20 |

---

## 5. 交互设计规范

### 5.1 核心交互模型

```
          Compact View (刘海区域，~300x36pt)
          ┌─────────────────────────────────┐
  点击 →  │  🎵  Bohemian Rhapsody - Queen  │  ← 自动隐藏(3s)
          └─────────────────────────────────┘
                    │ 点击
                    ▼
          Expanded Panel (刘海下方弹出)
          ┌─────────────────────────────────┐
          │  ┌───────────────────────────┐  │
          │  │   专辑封面   曲目名称      │  │
          │  │   ==========进度条======   │  │
          │  │   ⏮   ⏯   ⏭     🔊     │  │
          │  └───────────────────────────┘  │
          │  ┌──────┐ ┌──────┐ ┌──────┐    │
          │  │ 电池  │ │ 天气  │ │ 日历  │   │  ← 快捷模块
          │  └──────┘ └──────┘ └──────┘    │
          └─────────────────────────────────┘
```

### 5.2 手势与交互

| 交互 | 动作 | 反馈 |
|------|------|------|
| 点击刘海区域 | 展开详细面板 | Spring 动画展开 |
| 再次点击 / 点击外部 | 折叠 | Spring 动画收起 |
| 左右滑动（紧凑模式） | 切换关注模块 | 横向滑动过渡 |
| 左右滑动（展开模式） | 切换详情页 | 分页过渡 |
| 长按 | 固定/取消固定当前模块 | Haptic 反馈 |
| 双指下滑 | 关闭临时通知 | 淡出 |

### 5.3 场景切换规则

```
优先级（从高到低）：
1. 系统通知（3s，之后恢复）
2. AI 等待审批（直到审批完成）
3. 电池 < 20%（直到充电）
4. 日历日程 < 5min（日程开始时恢复）
5. AI 正在运行（直到完成）
6. 正在播放音乐（直到暂停）
7. 默认显示（用户设置）
```

### 5.4 动画时长标准

```
┌──────────────────────────┬──────────┬──────────────┐
│  动效                     │  时长     │  缓动曲线     │
├──────────────────────────┼──────────┼──────────────┤
│  紧凑→展开                │  350ms   │ spring(0.5)  │
│  展开→紧凑                │  250ms   │ easeInOut    │
│  模块间切换               │  200ms   │ easeInOut    │
│  状态指示灯（脉冲）        │  1500ms  │ easeInOut ∞  │
│  文字滚动（长标题）        │  按需    │ linear       │
│  通知出现/消失            │  200ms   │ easeOut/In   │
│  hover 高亮               │  150ms   │ easeOut      │
└──────────────────────────┴──────────┴──────────────┘
```

### 5.5 无障碍

- 支持 `prefers-reduced-motion`：禁用弹性动画，使用瞬间切换
- 支持 VoiceOver：所有模块提供 accessibilityLabel
- 键盘导航：Tab 在模块间切换，Space/Enter 展开

---

## 6. 技术架构

### 6.1 技术选型

| 层面 | 选型 | 理由 |
|------|------|------|
| 语言 | Swift 6.1 | 最新、并发模型优秀 |
| UI 框架 | SwiftUI | 原生、动画流畅、与 macOS 深度集成 |
| 窗口类型 | Panel + MenuBarExtra | 不需要 Dock 图标，纯菜单栏 app |
| 最低系统 | macOS 14.0 (Sonoma) | 有刘海机型均在此版本以上 |
| 依赖管理 | Swift Package Manager | 原生、无额外工具 |
| 包大小 | < 5MB | 纯原生，无外部依赖 |

### 6.2 项目结构

```
NotchBay/
├── NotchBay.xcodeproj
├── Sources/
│   ├── App/
│   │   ├── NotchBayApp.swift          # @main 入口
│   │   ├── AppState.swift             # 全局状态
│   │   └── AppDelegate.swift          # 生命周期
│   │
│   ├── Core/
│   │   ├── IslandWindow.swift         # 刘海窗口管理
│   │   ├── IslandPosition.swift       # 刘海位置计算
│   │   ├── SceneDetector.swift        # 场景检测与切换
│   │   └── Permissions.swift          # 权限管理
│   │
│   ├── Modules/
│   │   ├── ModuleProtocol.swift       # 模块协议
│   │   ├── ModuleRegistry.swift       # 模块注册中心
│   │   ├── NowPlaying/
│   │   │   ├── NowPlayingModule.swift
│   │   │   ├── NowPlayingCompact.swift
│   │   │   └── NowPlayingExpanded.swift
│   │   ├── Battery/
│   │   │   ├── BatteryModule.swift
│   │   │   ├── BatteryCompact.swift
│   │   │   └── BatteryExpanded.swift
│   │   ├── AISession/
│   │   │   ├── AISessionModule.swift
│   │   │   ├── AISessionCompact.swift
│   │   │   ├── AISessionExpanded.swift
│   │   │   └── SessionTracker.swift   # 文件系统监控
│   │   ├── Weather/
│   │   │   ├── WeatherModule.swift
│   │   │   ├── WeatherCompact.swift
│   │   │   └── WeatherExpanded.swift
│   │   ├── Calendar/
│   │   │   ├── CalendarModule.swift
│   │   │   ├── CalendarCompact.swift
│   │   │   └── CalendarExpanded.swift
│   │   └── Notification/
│   │       ├── NotificationModule.swift
│   │       └── NotificationCompact.swift
│   │
│   ├── Views/
│   │   ├── CompactView.swift          # 紧凑模式容器
│   │   ├── ExpandedView.swift         # 展开模式容器
│   │   ├── Components/
│   │   │   ├── StatusIndicator.swift  # 状态指示灯
│   │   │   ├── MarqueeText.swift      # 滚动文字
│   │   │   ├── WaveformView.swift     # 音频波形
│   │   │   └── ProgressBar.swift      # 进度条
│   │   └── Settings/
│   │       ├── SettingsWindow.swift
│   │       ├── GeneralSettings.swift
│   │       ├── ModulesSettings.swift
│   │       └── AppearanceSettings.swift
│   │
│   ├── Services/
│   │   ├── MediaMonitor.swift         # NowPlaying 数据源
│   │   ├── BatteryMonitor.swift       # IOKit 电池数据
│   │   ├── WeatherService.swift       # 天气 API
│   │   ├── CalendarService.swift      # EventKit 集成
│   │   ├── AISessionMonitor.swift     # AI 会话监控
│   │   └── NotificationService.swift  # 系统通知桥接
│   │
│   └── Utilities/
│       ├── Extensions.swift
│       ├── Constants.swift
│       └── Logging.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── entitlements.plist
│
└── Tests/
    ├── UnitTests/
    └── UITests/
```

### 6.3 核心架构模式

**模块协议 (ModuleProtocol)**：

```swift
protocol IslandModule: Identifiable {
    var id: String { get }
    var name: String { get }
    var icon: String { get }          // SF Symbol name
    var priority: Int { get }         // 场景切换优先级
    
    func compactView() -> AnyView     // 紧凑模式视图
    func expandedView() -> AnyView    // 展开模式视图
    
    func isRelevant() -> Bool         // 当前是否应该主动展示
    func startMonitoring()            // 开始数据源监控
    func stopMonitoring()             // 停止数据源监控
}
```

**场景检测器 (SceneDetector)**：

```
用户活动变化 ──→ [优先级排序] ──→ [去抖动(500ms)] ──→ 切换活跃模块
                                                         │
                                      ┌──────────────────┘
                                      ▼
                                   IslandWindow.animate(transition)
```

**窗口管理 (IslandWindow)**：

```
NotchBay 使用 NSPanel 而非 NSWindow：
- floating: true —— 始终置顶
- hasShadow: false —— 紧凑模式无阴影
- becomesKeyOnlyIfNeeded: true —— 按需获取焦点
- level: .floating —— 浮动层级
- collectionBehavior: .canJoinAllSpaces —— 所有桌面空间可见

紧凑模式：贴合刘海下方，自动计算位置
展开模式：从刘海下方弹出，带动画位移
```

### 6.4 AISession 监控方案

借鉴 Ping Island 的技术方案：

```
监控方式：
├── 本地终端 (Terminal/Ghosty/iTerm2)
│   └── 轮询 ~/.claude/projects/*/ 目录下的 session 文件
│   └── 解析 JSONL 日志获取实时状态
├── 远程 SSH（Codex CLI）
│   └── 监听 SSH config 中标记的远程主机
│   └── 通过 SSH 执行 tail -f 获取远程日志
└── IDE 插件（Claude Code / Codex in VS Code / Cursor）
    └── 轮询 IDE 的 workspace 状态文件
    └── 或通过 IDE 插件提供的本地端口通信
```

---

## 7. 模块设计

### 7.1 Now Playing 模块

```
数据源：
├── MediaRemote.framework (私有框架，通过 MRMediaRemoteGetNowPlayingInfo)
├── 或通过 system_profiler SPMediaDataType
└── 或使用 AppleScript bridge (osascript)

紧凑模式显示：
┌──────────────────────────────────┐
│ 🎵  Bohemian Rhapsody — Queen   │  ← 长标题自动滚动
└──────────────────────────────────┘

展开模式显示：
┌──────────────────────────────────┐
│  ┌──────┐                        │
│  │ 专辑  │  Bohemian Rhapsody    │
│  │ 封面  │  Queen · A Night...   │
│  └──────┘                        │
│  ──────●────────────────────     │
│  1:23 ─────────────── 4:56      │
│  ⏮    ⏯    ⏭          🔊 80%  │
└──────────────────────────────────┘
```

### 7.2 Battery 模块

```
数据源：IOKit (IOPowerSources)

紧凑模式显示：
┌────────┐
│ 🔋 85% │  ← 绿色
└────────┘

电池 < 20%：
┌──────────┐
│ 🔋 15% ⚡│  ← 红色 + 闪电动画
└──────────┘

展开模式：
┌──────────────────────────────┐
│  电池健康: 95%               │
│  循环次数: 142               │
│  当前功率: 8.5W (放电中)     │
│  剩余时间: 约 2 小时 30 分钟 │
└──────────────────────────────┘
```

### 7.3 AI Session 模块

```
数据源：文件系统监控（见 6.4）

紧凑模式 — 思考中：
┌──────────────────────┐
│ 🧠● 思考中...         │  ← 紫色，点闪烁
└──────────────────────┘

紧凑模式 — 执行中：
┌──────────────────────────────────┐
│ 🧠● Claude → reading file.ts     │  ← 绿色，显示工具名
└──────────────────────────────────┘

紧凑模式 — 等待审批：
┌──────────────────────────────────────┐
│ 🧠● Claude 需要审批  [Y/n]           │  ← 橙色呼吸
└──────────────────────────────────────┘

展开模式：
┌──────────────────────────────────┐
│  Claude Code · session-abc123    │
│  ─────────────────────────────── │
│  状态: 正在执行工具调用           │
│  工具: Bash(npm run build)       │
│  耗时: 45.2s                     │
│  ─────────────────────────────── │
│  最近输出:                       │
│  > Building modules...           │
│  > Complete. 245 modules built.  │
│  ─────────────────────────────── │
│  [跳转到终端]  [审批]  [追问]    │
└──────────────────────────────────┘
```

### 7.4 天气模块

```
数据源：WeatherKit (Apple 原生，免费额度充足) 或 OpenWeatherMap

紧凑模式：
┌─────────────┐
│ ☀️ 26° 北京  │
└─────────────┘

展开模式：
┌──────────────────────────────┐
│  北京 · 晴                    │
│  26°C  |  湿度 45%  |  微风   │
│  ─────────────────────────── │
│  逐小时:                      │
│  14:00 ☀️ 27°  17:00 ⛅ 24°  │
│  15:00 ☀️ 27°  18:00 ⛅ 22°  │
│  16:00 ⛅ 26°   19:00 🌙 19°  │
│  ─────────────────────────── │
│  5日预报:                     │
│  周四 ☀️ 28°/20°              │
│  周五 ⛅ 25°/18°              │
│  周六 🌧 22°/16°              │
│  周日 ⛅ 24°/17°              │
│  周一 ☀️ 27°/19°              │
└──────────────────────────────┘
```

---

## 8. 开发路线图

### Phase 1: 原型验证 (MVP) — 2 周

- [ ] SwiftUI 项目骨架搭建
- [ ] 刘海位置检测 & 窗口定位
- [ ] 紧凑模式容器 + 展开/折叠动画
- [ ] Now Playing 模块（紧凑 + 展开）
- [ ] 验证窗口层级与多桌面兼容性

### Phase 2: 核心功能 — 2 周

- [ ] AI Session 监控模块
- [ ] Battery 模块
- [ ] 场景自动切换引擎
- [ ] 设置窗口
- [ ] 单元测试

### Phase 3: 扩展功能 — 2 周

- [ ] Weather 模块
- [ ] Calendar 模块
- [ ] Notification 中心
- [ ] 模块间的横向滑动切换
- [ ] 无障碍支持

### Phase 4: 打磨与发布 — 1 周

- [ ] 性能优化（减少轮询开销）
- [ ] 动画打磨
- [ ] 自动更新机制
- [ ] DMG 打包 + 公证
- [ ] 隐私政策 + 文档

---

## 附录

### A. 参考项目

| 项目 | 链接 |
|------|------|
| Ping Island | https://github.com/erha19/ping-island |
| SuperIsland | https://github.com/shobhit99/SuperIsland |
| AgentNotch | https://github.com/AppGram/agentnotch |
| Aura | https://github.com/pronzzz/aura |
| my-code-island | https://github.com/obrr-hhx/my-code-island |
| claude-visor | https://github.com/824zzy/claude-visor |
| Apple HIG | https://developer.apple.com/design/human-interface-guidelines/ |
| SF Symbols | https://developer.apple.com/sf-symbols/ |

### B. 设计决策记录

1. **为什么用 SwiftUI 而非 Electron/web 技术** — 刘海窗口需要精细的窗口层级控制和原生性能，Web 技术无法实现
2. **为什么不支持 macOS 13 及以下** — Ventura 无刘海机型不需要此工具，且 SwiftUI API 差异大
3. **为什么用 NSPanel 而非 NSWindow** — Panel 提供更好的浮动行为和焦点管理
4. **为什么菜单栏 app 而非 Dock app** — 避免占用 Dock 空间，菜单栏图标作为入口
5. **紧凑模式宽度限制 ~300pt** — 实测 MacBook Pro 14" 刘海两侧各约 150pt，总计约 300pt
