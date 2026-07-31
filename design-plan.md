# 家庭 Kiosk 实现计划

## 1. 项目范围

开发一个长期固定运行的家庭 Kiosk：

* Android：Flutter APK；
* 其他设备：Flutter Web；
* Windows、macOS、Linux 电脑运行 Desktop Daemon；
* 所有设备位于同一家庭局域网；
* Kiosk 永不退出，也不切换到其他应用；
* Android 与 Web 功能定位一致，底层实现按平台区分。

## 2. 核心功能

### Kiosk 客户端

* Material 3 / Material You 界面；
* 显示时间、日期、日程、任务和电脑通知；
* 应用内部调度并播放闹钟和提醒；
* 摄像头持续监控录像；
* 本地录像分片、容量限制和循环覆盖；
* 可选上传录像到 Google Drive、WebDAV、NAS 等目标；
* 上传中断不影响继续录像；
* 通过局域网发布实时视频流；
* 长期开启麦克风并接入语音模型；
* 通过按钮或语音控制其他电脑。

### Desktop Daemon

* 同步所在电脑的通知；
* 启动电脑上的预定义应用；
* 执行预定义快捷键；
* 控制音量、媒体和其他电脑功能；
* 上报电脑在线状态；
* 提供局域网 HTTP 和 WebSocket 接口；
* 提供实时视频接收页面。

## 3. 总体架构

```text
Android Kiosk ─┐
               ├── HTTP / WebSocket ── Desktop Daemon
Web Kiosk ─────┘

Kiosk ── WebRTC ── 电脑端视频接收页面

Kiosk ── 可选上传 ── Google Drive / WebDAV / NAS

Kiosk ── Google API ── Calendar / Tasks
Kiosk ── 外部 API ── 语音模型
```

不需要：

* 用户账号系统；
* 设备注册平台；
* 中心 Backend；
* 公网远程控制；
* Kiosk 本机应用启动；
* 系统级闹钟；
* 自行开发跨平台虚拟摄像头驱动。

## 4. 平台实现

### Flutter Web

* `getUserMedia`：摄像头和麦克风；
* `MediaRecorder`：录像分片；
* OPFS：录像文件；
* IndexedDB：录像与上传队列；
* WebRTC：实时视频；
* Web Audio：语音采集。

### Android

* Flutter：UI 和业务逻辑；
* CameraX：摄像头采集；
* Android 文件系统：录像缓存；
* SQLite：录像与上传队列；
* Android WebRTC：实时视频；
* AudioRecord：语音采集。

### 共享 Dart 代码

* UI；
* 闹钟和提醒调度；
* 日历与任务模型；
* 通知展示；
* 电脑控制协议；
* 录像状态；
* 上传状态；
* 语音工具调用。

## 5. 录像设计

```text
摄像头
  ↓
1～3 分钟录像分片
  ↓
本地文件
  ├── 本地回放
  ├── 容量限制
  ├── 循环覆盖
  └── 可选上传队列
```

原则：

* 录像始终先写入本地；
* 上传与录像完全分离；
* 上传失败不停止录像；
* 文件完整关闭后才进入上传队列；
* 上传成功后根据保留策略决定是否删除；
* 未启用上传时只进行本地循环录像。

摄像头只采集一次，再同时用于：

```text
摄像头
  ├── Kiosk 预览
  ├── 本地录像
  └── WebRTC 实时视频
```

## 6. 应用内闹钟

Android 和 Web 使用同一套 Dart 调度器：

* 保存未来提醒；
* 为最近的提醒建立计时器；
* 定期校准时间；
* 到时显示全屏提醒并播放声音；
* 支持关闭、完成和延迟；
* 可将 Google Calendar 和 Tasks 数据转换为应用内提醒。

不调用 Android AlarmManager 或其他系统闹钟功能。

## 7. 局域网电脑控制

Kiosk 直接连接各电脑上的 Daemon。

第一版手动配置：

```text
主电脑：192.168.1.10:43821
副电脑：192.168.1.20:43821
```

后续可增加 mDNS 自动发现。

命令使用白名单动作：

```text
launch_app
send_shortcut
set_volume
media_play_pause
lock_computer
open_url
```

Daemon 本地保存应用路径和快捷键配置。Kiosk 不发送任意 Shell 命令。

## 8. 实时视频与 Webcam 使用

Kiosk 使用 WebRTC 发布局域网实时视频：

```text
Kiosk 摄像头
    ↓ WebRTC
电脑端接收页面
```

电脑端接收页面可以：

* 在浏览器中预览；
* 被支持网页视频源的软件直接使用；
* 作为 OBS Browser Source；
* 通过 OBS Virtual Camera 暴露为系统摄像头。

推荐路径：

```text
Kiosk
  ↓ WebRTC
接收页面
  ↓
OBS Browser Source
  ↓
OBS Virtual Camera
  ↓
Zoom / Meet / Discord 等应用
```

OBS 只是利用其现成虚拟摄像头能力的便利方案，不是 Kiosk 的核心依赖。

## 9. Google 与语音功能

### Google

* Google Calendar：日程和带时间的事项；
* Google Tasks：待办事项；
* Google Drive：可选录像上传目标。

### 语音助手

* 麦克风长期采集；
* 本地 VAD 或唤醒词；
* 唤醒后将语音发送给模型；
* 支持设置闹钟、创建提醒、查询日程和控制电脑。

首版工具：

```text
create_alarm
snooze_alarm
create_reminder
list_today_events
launch_app_on_computer
send_computer_shortcut
start_video_stream
stop_video_stream
```

## 10. 开发顺序

### 阶段 1：基础 Kiosk

* Flutter Android 和 Web；
* Material 3；
* 时钟；
* 日程和任务；
* 应用内闹钟。

### 阶段 2：Desktop Daemon

* HTTP/WebSocket；
* 通知同步；
* 启动应用；
* 快捷键；
* 电脑状态。

### 阶段 3：监控录像

* Web MediaRecorder + OPFS；
* Android CameraX + 文件系统；
* 分片录像；
* 本地保留；
* 循环覆盖；
* 可选上传器。

### 阶段 4：实时视频

* WebRTC 发布；
* 电脑端接收页面；
* 与本地录像同时运行；
* 验证 OBS Browser Source 和 Virtual Camera。

### 阶段 5：Google 与语音

* Calendar；
* Tasks；
* 可选 Drive 上传；
* 麦克风采集；
* VAD 或唤醒词；
* 语音模型和工具调用。

### 阶段 6：长期稳定性

* 连续运行测试；
* 摄像头异常恢复；
* 存储写满处理；
* 上传重试；
* WebRTC 重连；
* 内存与温度监控；
* 屏幕防烧屏。

## 11. 第一版目标

第一版完成：

* Android 和 Web Kiosk；
* 时间、日程和应用内闹钟；
* 电脑通知同步；
* 电脑应用和快捷键控制；
* 本地监控录像；
* 本地循环缓存；
* WebRTC 实时视频；
* 电脑端接收页面；
* Google 日历和任务展示。

语音助手、多种上传目标和自动发现可在核心功能稳定后继续增加。

