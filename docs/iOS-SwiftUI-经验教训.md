# DeepMei iOS 开发经验教训

> 记录日期：2026-08-08
> 适用仓库：`/Users/shensunfeng/DeepMei`（iOS 版，Xcode 27 Beta / Swift 6）
> 背景：本次将 iOS 端与 Android 2.7.0 对齐，涉及签到、登录、作品网格、社员卡等大量 SwiftUI 改动。
> 阅读对象：后续接手 iOS 端的开发者。**先读「验证方法」一节，再改代码。**

---

## 1. 验证方法（最重要）

### 1.1 三条铁律

1. **GeometryReader 上报的 frame 正确 ≠ 最终渲染正确。**
   本次最大的坑：布局引擎确认每张卡片都是 147×110pt、间距 20pt，但用户看到的画面是“图片拼在一起”。
   原因是图片绘制区域（scaledToFill 溢出）超出了 layout bounds，把间隙盖住了。
   所以**必须检查最终渲染树 / 渲染像素**，不能只看 frame。

2. **外部像素扫描要基于“最终截图”动态定位，不能硬编码坐标。**
   布局常量一改（如去掉托盘、改间距），所有硬编码坐标全部失效，会得出假阳性/假阴性。

3. **先用最小可复现页截图，再进真机。**
   写一个临时根视图（直接 `MemberProfileCard` + 测试数据）跑模拟器截图，
   确认无误后再还原。测试代码必须完整还原，可用 `rg -n 'ProfileCardTest|MEASURE'` 检查残留。

### 1.2 推荐流程

```bash
# 1. 构建并安装到模拟器（用 Xcode Beta 的绝对路径）
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -quiet -project DeepMei.xcodeproj -scheme DeepMei \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /tmp/deepmei-sim CODE_SIGNING_ALLOWED=NO build

/Applications/Xcode-beta.app/Contents/Developer/usr/bin/simctl boot <UDID>
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/simctl install <UDID> /tmp/deepmei-sim/Build/Products/Debug-iphonesimulator/DeepMei.app
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/simctl launch <UDID> com.szzxshumei.DeepMei
sleep 10
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/simctl io <UDID> screenshot /tmp/shot.png
```

看设备列表：`simctl list devices available`。

### 1.3 让 App 自己上报 frame（os_log）

像素扫描不可靠时，让 SwiftUI 布局引擎自己上报：

```swift
import os

private func logMeasure(_ g: GeometryProxy, index: Int) {
    let frame = g.frame(in: .global)
    let logger = Logger(subsystem: "com.szzxshumei.DeepMei", category: "measure")
    logger.info("[MEASURE] card\(index) x=\(frame.minX) y=\(frame.minY) w=\(frame.width) h=\(frame.height)")
}

// 用法：挂在「固定尺寸 frame 之后」的 background GeometryReader 上
// 注意：不要用 print()，系统日志查不到；要用 Logger
```

读取日志：

```bash
simctl spawn <UDID> log show --info --debug --last 3m \
  --predicate 'category == "measure"' --style compact
```

`log show` 默认不带 `--info --debug` 是查不到 info 级日志的。

### 1.4 像素级检查间隙示例

扫描最终截图，统计“间隙区域内非背景像素占比”。背景判定：近均匀浅色
（`max(r,g,b) > 215 && max-min < 18`）。修复前超宽图会横向溢出、竖图会纵向溢出，
间隙区域会出现大量照片色；修复后应为 0%。

---

## 2. SwiftUI 布局三大坑

### 2.1 aspectRatio 在 ScrollView/VStack 里可能失效

**现象**：`MemberCardFace` 用 `.aspectRatio(85.6/53.98, contentMode: .fit)` 后，
模拟器实测卡面比例是 1.155 而不是 1.586——卡片被内容理想高度撑高。

**原因**：在 `ScrollView → VStack` 中，父级提案是“宽度确定、高度未指定”，
`aspectRatio` 会回落使用内容的理想高度（内部 `Spacer` 的理想尺寸被计入），
而不是按宽度推算高度。

**修复（[CheckIn/MemberCardFace.swift](../DeepMei/CheckIn/MemberCardFace.swift)）**：

```swift
GeometryReader { proxy in
    ZStack { /* 卡面内容 */ }
        .frame(width: proxy.size.width,
               height: proxy.size.width * (53.98 / 85.6))   // 显式锁死宽高
}
.aspectRatio(85.6 / 53.98, contentMode: .fit)               // 外层兜底
```

经验：**依赖比例时，显式 frame 优先，不要只靠 aspectRatio。**

### 2.2 scaledToFill 溢出 layout bounds，clipped 形同虚设

**现象**：作品网格每张卡 frame 都是 4:3、间距 20pt，但画面里图片“拼在一起”。

**原因**：

```swift
Image(uiImage:)
    .resizable()
    .aspectRatio(contentMode: .fill)          // 竖图会被放大到 147×261
    .frame(maxWidth: .infinity, maxHeight: .infinity)  // frame 跟随子视图尺寸
    .clipped()                               // 裁的是 147×261，等于没裁
```

且 `ImageWorkCard` 的 `.clipShape` 曾挂在固定 `frame(width:height:)` **之前**，
裁的是溢出后的错误 bounds。

**修复（[MyDigitalMedia/FeishuAsyncImage.swift](../DeepMei/MyDigitalMedia/FeishuAsyncImage.swift)）**：

```swift
Color.clear
    .overlay {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
    }
    .clipped()          // 以 layout bounds 为界裁切
```

作品卡同理（[MyDigitalMedia/MyRaspberryView.swift](../DeepMei/MyDigitalMedia/MyRaspberryView.swift)）：

```swift
FeishuAsyncImage(...)
    .frame(width: width, height: height)      // 1) 先固定尺寸
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))  // 2) 再裁切
```

经验：**固定尺寸 → 裁切 → 边框，顺序不能反。**

### 2.3 GeometryReader 放在 background/overlay 会把父视图撑大

**现象**：想用 `.background(GeometryReader { ... })` 测量容器宽度，
结果整个档案卡被撑到全屏宽（402pt），作品卡也跟着变宽。

**原因**：GeometryReader 的尺寸=提案尺寸；挂在 flexible 视图的 background/overlay 上时，
会反过来把父视图撑满提案。

**结论**：
- 不要在 flexible 视图的 background/overlay 里放 GeometryReader 做测量；
- 固定尺寸的 frame 之后可以安全挂（如 2.1、1.3）；
- 简单布局直接用布局常量计算（页面 16pt 边距、卡片 16pt 内边距等），不要过度测量。

---

## 3. 网格布局：不要 LazyVGrid 嵌滚动卡

**现象**：作品网格用 `LazyVGrid` 时，单元格互相遮挡。
Android 端注释早就写明“非 Lazy 实现，避免与外层 verticalScroll 冲突”。

**方案**：两两一行的显式 HStack（对齐 Android `ArtWorksGridSection`）：

```swift
let rows = stride(from: 0, to: works.count, by: 2).map { start in
    Array(works[start..<min(start + 2, works.count)])
}

VStack(spacing: gridSpacing) {
    ForEach(rows, id: \.self) { row in
        HStack(spacing: gridSpacing) {
            ForEach(row) { work in
                ImageWorkCard(work: work, width: cardWidth, height: cardHeight) { ... }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
```

设计要点（对齐 Android 且符合 HIG）：
- 每张卡 **4:3**、最大宽 240pt（`maxCardWidth`），单张作品同样受限并居中；
- 间距 20pt，卡片 1pt 分隔线边框、12pt 连续圆角；
- 去掉灰底托盘后更接近 Apple Photos，卡片边框承担层次；
- 不要用 `UIScreen` 之外的花哨测量；宽度按布局常量算：
  `min((screenWidth - 64 - gridSpacing) / 2, 240)`（64 = 页面边距 16×2 + 本节内边距 16×2）。

---

## 4. 编译期问题（Xcode 27 Beta）

### 4.1 catch 参数与 @State 同名会触发编译器崩溃

```swift
// ❌ 编译器直接崩溃：隐式 catch 参数 error 与 @State var error 同名
catch { error = "..." }

// ✅
catch let caughtError { error = "登录失败：\(caughtError.localizedDescription)" }
```

### 4.2 MainActor.run 泛型推断

```swift
// ❌ 推断失败
if let member = await MainActor.run({ mapRecord(...) }) { ... }

// ✅ 显式 resultType
let mapped = await MainActor.run(resultType: RaspberryMember?.self) {
    mapRecord(...)
}
```

### 4.3 新文件没进 target

工程用 `PBXFileSystemSynchronizedRootGroup`（文件夹自动同步）。Xcode 开着时
直接往磁盘新增文件，可能不生效，报 `Cannot find 'XXX' in scope`。
**退出 Xcode 重新打开**即可；命令行 `xcodebuild` 每次重新扫描磁盘，可作为对照。

### 4.4 复杂表达式“无法在合理时间内完成类型检查”

把大表达式拆成局部变量/独立函数（如 1.3 的 `logMeasure`）。

---

## 5. 平台规范与产品决策

- **免费 Apple 开发者账号没有 NFC 能力**：iOS 不做 NFC 贴卡/全局亮卡，
  签到用扫码 + 手动输入；隐私政策、用户协议等文档不要写 NFC。
- **iPhone 没有抽屉范式**：不要照搬 Android 的 M3 Navigation Drawer。
  个人中心改为**第 5 个底部 Tab + Grouped List**（设置页样式），符合 HIG。
- **全屏横屏网页要有显式返回**：iOS 没有系统返回键；隐藏导航栏时
  左上角放悬浮返回按钮（适配安全区），保留边缘右滑。
- **品牌色**：AccentColor 浅色 `#942B38`、深色 `#FFB3B7`（树莓红，与 Android M3 同源）；
  社团 logo 用 `ClubLogo` 资源（来自 Android `club_logo.png`）。

---

## 6. 文档与资源同步

- 隐私政策/用户协议与 Android 对齐，但按平台删掉 NFC 描述；
  iOS 版还补了「登录信息」一节（登录记录、定位、未登录可用功能）。
- 开源许可**以实际拉取的仓库 LICENSE 为准**（swift-markdown-ui: MIT、
  NetworkImage: MIT、swift-cmark/cmark-gfm: BSD-2-Clause），不要凭印象写。
- 文库 markdown 与 Android assets 保持同步（章程第十版、各届报告）。

---

## 7. 环境与工具

- Xcode Beta 应放在 `/Applications/Xcode-beta.app`（不要在 Downloads），
  命令行用绝对路径调用；`xcode-select -s` 需要 sudo。
- 编译命令统一加 `-derivedDataPath` 和 `CODE_SIGNING_ALLOWED=NO`，
  避免污染默认 DerivedData。
- 模拟器测量用 `simctl`（boot / install / launch / io screenshot / spawn log show）。
- Swift 命令行小工具（AppKit + ImageRenderer / 像素扫描）可直接用
  `/usr/bin/swiftc -parse-as-library xxx.swift -o /tmp/xxx` 编译跑，但写 ~/.cache 需要权限。

---

## 8. 发布提醒

- 版本号 2.7.0（build 3）；TestFlight 邀请链接在 `AboutView.swift` 的
  `UpdateEntry.testFlightInviteURL` 配置，为空时回退 TestFlight 商店页。
- 发行前跑一遍：登录定位权限、扫码签到全流程、作品网格、深色模式。

---

## 9. Apple Watch（watchOS 10+ / WatchConnectivity）

> 本次补充：手表端三页（表情抽卡 / 社员卡 / 二维码）开发与同步排障。

### 9.1 HIG 要点

- watchOS 10+ 顶层页面切换用 `.tabViewStyle(.verticalPage)`（表冠纵向翻页），
  不要用横向 `.page`。横向滑动没被禁止，但只适合内容本身横向的场景；
  官方 Digital Crown 章节明确要求“纵向分页标签”。
- 字体用系统样式（`.caption2` / `.footnote`），不要 `.system(size: 9)`：
  9pt 低于 watchOS 最小可读尺寸，且不跟随 Dynamic Type。
- Always On 隐私：`@Environment(\.isLuminanceReduced)` 在垂腕变暗时为 `true`，
  用它隐藏姓名 / ID / 二维码等个人信息。
- 整屏手势要补 `.accessibilityAddTraits(.isButton)` + `.accessibilityAction`，
  否则 VoiceOver 无法激活。

### 9.2 `UIGraphicsImageRenderer` 默认 3x 渲染：7009 的元凶

`UIGraphicsImageRenderer(size:)` 默认按屏幕 scale（iPhone 3x）输出，
“160pt”实际生成 480×480 像素，体积膨胀约 9 倍，头像 + 二维码轻松超过
`sendMessage` 上限（WCErrorCodePayloadTooLarge = 7009）。

```swift
let format = UIGraphicsImageRendererFormat()
format.scale = 1
let renderer = UIGraphicsImageRenderer(size: target, format: format)
```

修复后头像约 2KB、二维码约 3KB，任何通道都不会超限。

### 9.3 WatchConnectivity 通道选择

| 通道 | 特点 |
| --- | --- |
| `updateApplicationContext` | 系统只保留最新一份，手表启动可读；重装手表 App 后清空 |
| `transferUserInfo` | 排队投递，对方 App 未运行时下次启动补投 |
| `transferFile` | 图片/大文件专用，无小 payload 限制，排队投递 |
| `sendMessage` | 实时，要求对方 App 可达；超限报 7009，不可达报 7007 |

经验：

- 图片数据不要只依赖一条通道。体积修好后让 `sendMessage` 直接带完整数据
  （几 KB），context / userInfo / transferFile 作兜底。
- 手表端要把最近一次登录态存 UserDefaults（含头像/二维码），
  重装后第一次仍需手机同步一次。
- 文字更新或旧 context 可能不带图，合入时必须保留本地已有的
  `avatarData` / `qrCodeData`；只有 `memberCode` / `idCode` 变化（换社员）才清空。
- 收到文件可能先于文字信息到达：按 memberCode 暂存，等文字到了再合并。

### 9.4 典型排障

症状：只重启手表 App → 有文字、没头像/二维码；重新进入手机 App → 全有。

原因：手机 App 在后台仍会发消息，但旧实现把实时消息做成“纯文字”，图片只走
context / userInfo；这两条在特定设备/模拟器环境没送达，于是只剩文字。

解法：把图片放回那条已被证明能通的 `sendMessage` 通道（体积修好后完全可行），
其他通道保留作兜底，不要再“绕路”。

日志识别：

- `WCErrorCodeNotReachable`（7007）＝对方 App 不可达；
- `WCErrorCodePayloadTooLarge`（7009）＝payload 超限；
- `Application context data is nil`＝手表端没有 context，只能靠本地缓存或推送。

### 9.5 小坑

- SwiftUI `View` 是 struct，`Task` 里不能写 `[weak self]`；用 `@State` 持有
  Task 句柄，循环里靠 `Task.isCancelled` + 状态变量退出。
- 卡片里的 `AsyncImage` / `UIImage(data:)` 会在父视图每次重绘时重新加载/解码，
  导致头像闪烁。抽成独立子视图 + `@State` 缓存 + `.task(id:)`，
  动画只作用在变化的那行文字（`.contentTransition(.opacity)` + `.animation(value:)`）。
- 长按抽卡：`Task` 循环按递减间隔切换，最快 0.05s 封顶；
  震动只保留“触发”和“松手出结果”两次，快速滚动阶段不震。
