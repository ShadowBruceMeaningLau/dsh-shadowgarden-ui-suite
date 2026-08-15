# DeepSeek Harness · Shadow Garden UI 套装（dsh 插件版）

为 [DeepSeek Harness (DSH)](https://github.com/deepseek-ai/DeepSeek-Harness) 定制的 Windows 前端套装：**Shadow 主题 + 看板抽屉 + 能量特效 + 任务完成通知**，全部通过一个 dsh 插件交付；另附自建「旗舰版」服务中心窗口与「极速版」入口。

## 安装（推荐：插件方式）

```sh
dsh plugin --profile web add github:ShadowBruceMeaningLau/dsh-shadowgarden-ui-suite
# 或发布到 npm 后：
dsh plugin --profile web add dsh-shadowgarden-ui-suite
```

重启 `dsh web`，Shadow 主题、右缘看板把手、星尘/能量框特效与任务完成通知**全部自动生效**——无需任何额外部署步骤，服务重启后亦自动恢复（资源由插件路由常驻提供）。

## 功能一览

### Shadow 主题（插件客户端自动注入）
- 深色 Shadow 配色、玻璃质感、星尘/流星、三重旋转能量框、全局边界灯、能量接缝
- 由 `lib/client.js` 注入 `shadow-theme.css` + `dsh-kanban.css`，宿主路由提供全部资源

### 看板（`web/kanban.html` + `web/dsh-kanban.js`）
- 右缘固定把手的多看板抽屉；任务完成右下角气泡通知（原生 Notification + `dshnotify://` 兜底）

### 旗舰版（可选，Windows 原生窗口，非插件）
- 源码 `src/dsh-hub.cs`，编译产物 `runtime/dsh-hub.exe`
- 标准 Windows 窗口：深色标题栏、原生吸附/Win+Z 分屏；DSH | 用量 | Chat 三标签 + `＋` 多开、拖动排序、多窗口独立、登录共享
- 桌面入口由 `scripts/create-shortcuts.ps1` 生成，协议：`dshhub://` / `dshchat://` / `dshusage://` / `dshnotify://`

### 极速版（可选）
- 纯本地 DSH 页面的 Edge 应用窗口入口（`--app=http://127.0.0.1:3080`）

## 目录结构

```
├── package.json        dsh 插件声明（dsh.bundle + dsh.client, platform: web）
├── cordis.patch.yml    挂载行（id: shadowgarden-ui）
├── lib/
│   ├── index.js        宿主半边：/shadow-* 与静态页资源路由
│   └── client.js       客户端半边：注入主题与看板层
├── web/                Shadow 主题、看板、分屏等静态资源
├── src/                旗舰版 C# 源码
├── scripts/            启动器 / 快捷方式 / 辅助补丁
├── assets/             图标
└── runtime/            编译产物与 WebView2 运行库（git 忽略）
```

## 从源码构建旗舰版（可选）

依赖 .NET Framework 4.x `csc.exe` 与 WebView2 运行库三件套（置于 `runtime\`）：

```bat
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe ^
  /out:runtime\dsh-hub.exe ^
  /r:runtime\Microsoft.Web.WebView2.Core.dll /r:runtime\Microsoft.Web.WebView2.WinForms.dll ^
  /r:System.dll /r:System.Core.dll /r:System.Drawing.dll ^
  /r:System.Windows.Forms.dll /r:Microsoft.VisualBasic.dll ^
  src\dsh-hub.cs
```

## 其他说明

- `scripts/patch-better-sidebar.ps1`：给第三方插件 dsh-better-sidebar 的资源管理器加自由切换路径能力（可选，与其本身无关）
- 标签：`dsh-plugin` · `deepseek-harness` · `theme` · `shadow`

## 许可证

MIT，见 [LICENSE](LICENSE)。WebView2 运行库版权归微软所有，仅作本地运行依赖，不入库。
