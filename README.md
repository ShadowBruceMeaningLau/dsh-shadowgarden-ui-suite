# DeepSeek Harness · Shadow 套装（旗舰版 + 极速版）

为 [DeepSeek Harness (DSH)](https://github.com/deepseek-ai/DeepSeek-Harness) 定制的 Windows 本地前端套装：自建「旗舰版」服务中心窗口、Edge 应用式「极速版」入口、右缘看板抽屉、任务完成通知，以及 Shadow 主题注入层（含服务重启自愈）。全部本地运行，不修改 DSH 源码。

## 功能一览

### 旗舰版（`runtime/dsh-hub.exe`，源码 `src/dsh-hub.cs`）
- 标准 Windows 窗口：原生标题栏（深色 Shadow 配色）、原生拖动/缩放/贴边吸附/Win+Z 分屏布局
- 标签体系：**DSH | 用量 | Chat** 固定三标签 + `＋` 无限多开（DSH/GitHub/Chat/自定义网址）
- 多开标签可**拖动排序**、右键/× 删除；固定标签不可动
- **多窗口**：双击桌面快捷方式即开新的完整独立窗口；DSH 按窗口隔离、登录全局共享
- F11 全屏 / Esc 退出；双击桌面入口必落 DSH 标签
- 协议路由：`dshhub://`（切窗口/开新窗）、`dshchat://`、`dshusage://`、`dshnotify://`

### 极速版
- 纯本地 DSH 页面，Edge 应用窗口方式（`--app=http://127.0.0.1:3080`），无任何组装

### 看板（`web/kanban.html` + 注入层）
- 右缘固定把手的多看板抽屉，窗口内建多列任务看板
- 任务完成右下角气泡通知（原生 Notification + `dshnotify://` 兜底）

### Shadow 主题（`web/` + `scripts/apply-shadow-theme.ps1`）
- 深色 Shadow 配色、玻璃质感、星尘/流星、旋转能量框、能量接缝
- **自愈**：DSH 服务重启会重置前端，旗舰版启动时/DSH 页面导航时自动检测并重新部署主题

## 目录结构

```
├── src/         旗舰版 C# 源码（dsh-hub.cs）
├── web/         Web 注入层与静态页面（主题、看板、分屏等）
├── scripts/     部署与启动脚本（主题部署、快捷方式、启动器）
├── assets/      图标
├── runtime/     编译产物与 WebView2 运行库（git 忽略，见构建说明）
└── DSH-Shadow主题包-v55.zip   一键打包（git 忽略）
```

## 快速开始（Windows）

1. 安装 [DeepSeek Harness](https://github.com/deepseek-ai/DeepSeek-Harness)（`dsh web` 可运行）、Edge、Node.js
2. 运行 `scripts\create-shortcuts.ps1` 生成桌面入口与协议注册（PowerShell 执行策略需放行）
3. 双击桌面「DeepSeek Harness 旗舰版」即可；服务未运行时会自动拉起
4. 换肤/更新主题：`scripts\apply-shadow-theme.ps1`（幂等，可重复执行；`restore-shadow-theme.ps1` 还原官方样式）

## 从源码构建旗舰版

依赖：.NET Framework 4.x 的 `csc.exe`，以及 WebView2 运行库三件套（`Microsoft.Web.WebView2.Core.dll` / `Microsoft.Web.WebView2.WinForms.dll` / `WebView2Loader.dll`，可从 Office Power Query 集成目录取得，置于 `runtime\`）：

```bat
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe ^
  /out:runtime\dsh-hub.exe ^
  /r:runtime\Microsoft.Web.WebView2.Core.dll /r:runtime\Microsoft.Web.WebView2.WinForms.dll ^
  /r:System.dll /r:System.Core.dll /r:System.Drawing.dll ^
  /r:System.Windows.Forms.dll /r:Microsoft.VisualBasic.dll ^
  src\dsh-hub.cs
```

## 协议

- `dshhub://<host>` → 旗舰版窗口（已运行则切标签，否则新开窗口）
- `dshchat://` / `dshusage://` → DeepSeek Chat / 用量页快捷方式
- `dshnotify://` → 任务完成气泡通知

## 许可证

MIT，见 [LICENSE](LICENSE)。本仓库不包含任何第三方源码拷贝；WebView2 运行库版权归微软所有，仅作本地运行依赖，不入库。
