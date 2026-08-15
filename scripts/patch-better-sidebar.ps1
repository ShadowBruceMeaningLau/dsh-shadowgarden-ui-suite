# patch-better-sidebar.ps1
# 给 dsh-better-sidebar 资源管理器打功能补丁（幂等，可重复执行）：
#   1) 宿主：fs.drives（枚举盘符/常用目录）+ fs.pick（原生文件夹选择器）
#   2) 宿主：放开 /sidebar/file 与 /sidebar/html 的会话目录越界拦截
#   3) 客户端：路径输入框 + ↑上级 + 🖥我的电脑菜单 + 📂选择文件夹 + 双击进入
# 插件升级（pnpm 重装）会覆盖补丁，升级后重跑本脚本即可恢复。
$ErrorActionPreference = 'Stop'
$profile = Join-Path $env:USERPROFILE ".dsh\profiles\web\node_modules\dsh-better-sidebar"
if (-not (Test-Path $profile)) { Write-Output "dsh-better-sidebar not installed"; exit 1 }
$idx = Join-Path $profile "lib\index.js"
$cli = Join-Path $profile "lib\client.js"

# ============ 宿主补丁 ============
$h = [System.IO.File]::ReadAllText($idx, [System.Text.Encoding]::UTF8)
$a1 = 'if (!isWithin(cwd, path)) throw new SidebarError("fs-error", "media path outside the session working directory", 403);'
$a2 = 'if (!isWithin(cwd, absolute)) throw new SidebarError("fs-error", "html path outside the session working directory", 403);'
$a3 = '"fs.tree": async (payload) => {'
if ($h.Contains($a1)) { $h = $h.Replace($a1, "") }
if ($h.Contains($a2)) { $h = $h.Replace($a2, "") }
if (-not $h.Contains('"fs.drives": async () => {')) {
    $snipHost = @'
		"fs.drives": async () => {
			const drives = [];
			for (let code = 65; code <= 90; code += 1) {
				const drive = String.fromCharCode(code) + ":\\";
				try {
					await stat(drive);
					drives.push(drive);
				} catch {}
			}
			return {
				drives,
				home: process.env.USERPROFILE ?? process.env.HOME ?? ""
			};
		},
		"fs.pick": async () => {
			const { mkdtempSync, writeFileSync, rmSync } = await import("node:fs");
			const { tmpdir } = await import("node:os");
			const { join: joinPath } = await import("node:path");
			const dir = mkdtempSync(joinPath(tmpdir(), "dshpick-"));
			const script = joinPath(dir, "pick.ps1");
			writeFileSync(script, [
				'Add-Type -AssemblyName System.Windows.Forms',
				'$d = New-Object System.Windows.Forms.FolderBrowserDialog',
				"$d.Description = 'Select folder'",
				'$owner = New-Object System.Windows.Forms.Form',
				'$owner.TopMost = $true',
				'$r = $d.ShowDialog($owner)',
				"if ($r -eq 'OK') { Write-Output $d.SelectedPath }"
			].join("\n"), "utf8");
			return await new Promise((resolvePick) => {
				const ps = spawn("powershell.exe", ["-NoProfile", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script], { stdio: ["ignore", "pipe", "ignore"], windowsHide: true });
				let out = "";
				ps.stdout.setEncoding("utf8");
				ps.stdout.on("data", (chunk) => { out += chunk; });
				ps.on("close", () => { try { rmSync(dir, { recursive: true, force: true }); } catch {} resolvePick(out.trim() === "" ? null : out.trim()); });
				ps.on("error", () => { try { rmSync(dir, { recursive: true, force: true }); } catch {} resolvePick(null); });
			});
		},
'@
    $i = $h.IndexOf($a3)
    if ($i -lt 0) { Write-Error "HOST anchor fs.tree missing" }
    $h = $h.Insert($i, $snipHost)
}
[System.IO.File]::WriteAllText($idx, $h, (New-Object System.Text.UTF8Encoding $false))

# ============ 客户端补丁 ============
$c = [System.IO.File]::ReadAllText($cli, [System.Text.Encoding]::UTF8)

# 1) api 接口
$b1 = 'fsTree: (scope, path, signal) => call("fs.tree", scopePayload(scope, { path }), signal),'
if (-not $c.Contains('fsDrives: (scope, signal) =>')) {
    $snipApi = @'
fsDrives: (scope, signal) => call("fs.drives", scopePayload(scope, {}), signal),
			fsPick: (scope, signal) => call("fs.pick", scopePayload(scope, {}), signal),
'@
    $i = $c.IndexOf($b1)
    if ($i -lt 0) { Write-Error "CLIENT api anchor missing" }
    $c = $c.Insert($i, $snipApi)
}

# 2) 状态 + 盘符加载
$b2 = 'const [rowMenu, setRowMenu] = (0, react.useState)(null);'
if (-not $c.Contains('const [rootPath, setRootPath] = (0, react.useState)(null);')) {
    $snipState = @'
const [rootPath, setRootPath] = (0, react.useState)(null);
			const [driveMenu, setDriveMenu] = (0, react.useState)(null);
			const [driveData, setDriveData] = (0, react.useState)({ drives: [], home: "" });
			(0, react.useEffect)(() => {
				api.fsDrives({ sessionId, cwd }).then((drivesInfo) => setDriveData(drivesInfo)).catch(() => {});
			}, [sessionId, cwd]);
'@
    $c = $c.Replace($b2, $b2 + "`r`n" + $snipState)
}

# 3) effect 根目录 + deps
$b3 = "(0, react.useEffect)(() => {`n`t`t`t`t" + 'const root = cwd;'
$r3 = "(0, react.useEffect)(() => {`n`t`t`t`t" + 'const root = rootPath ?? cwd;'
if ($c.Contains('const root = rootPath ?? cwd;')) {
    # already patched
} elseif ($c.Contains($b3)) { $c = $c.Replace($b3, $r3) } else { Write-Error "CLIENT effect root anchor missing" }
$b4 = "`t`t`t}, [`n`t`t`t`t" + 'cwd,'
$r4 = "`t`t`t}, [`n`t`t`t`t" + 'cwd,' + "`n`t`t`t`t" + 'rootPath,'
if ($c.Contains($b4)) { $c = $c.Replace($b4, $r4) } else { Write-Error "CLIENT deps anchor missing" }

# 4) render 根目录
$b5 = "`t`t`t" + 'const root = cwd;'
$r5 = "`t`t`t" + 'const root = rootPath ?? cwd;'
if ($c.Contains($b5)) { $c = $c.Replace($b5, $r5) } elseif (-not $c.Contains($r5)) { Write-Error "CLIENT render root anchor missing" }

# 5) 头部 span -> 📂 🖥 ↑ 按钮 + 路径输入框（动态提取 span 块，避免误匹配其他 span）
if (-not $c.Contains('"aria-label": "pick",')) {
    $ap = $c.IndexOf('children: root === void 0 ? t("noSession") : baseName')
    $start = $c.LastIndexOf('(0, react_jsx_runtime.jsx)("span", {', $ap)
    $end = $c.IndexOf('}),', $ap)
    if ($ap -lt 0 -or $start -lt 0 -or $end -lt 0) { Write-Error "CLIENT span anchors missing" }
    $oldSpan = $c.Substring($start, $end + 3 - $start)
    if (-not $oldSpan.Contains('explorerRoot')) { Write-Error "CLIENT span extraction mismatch" }
    $snipHeader = @'
/* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
						type: "button",
						className: sidebar_module_css_default.iconButton,
						"aria-label": "pick",
						title: "\u9009\u62e9\u6587\u4ef6\u5939\uff08\u6253\u5f00\u7cfb\u7edf\u6587\u4ef6\u5939\u9009\u62e9\u5668\uff09",
						onClick: () => {
							api.fsPick({ sessionId, cwd }).then((picked) => {
								if (picked) setRootPath(picked);
							}).catch(() => {});
						},
						children: "\ud83d\udcc2"
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
						type: "button",
						className: sidebar_module_css_default.iconButton,
						"aria-label": "computer",
						title: "\u6211\u7684\u7535\u8111\uff08\u5207\u6362\u76d8\u7b26/\u5e38\u7528\u76ee\u5f55\uff09",
						onClick: (event) => {
							setDriveMenu({ x: event.clientX, y: event.clientY });
						},
						children: "\ud83d\udda5"
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("button", {
						type: "button",
						className: sidebar_module_css_default.iconButton,
						"aria-label": "up",
						title: "\u4e0a\u7ea7\u76ee\u5f55",
						onClick: () => {
							const base = rootPath ?? cwd;
							const trimmed = base.replace(/[\\/]+$/, "");
							const at = Math.max(trimmed.lastIndexOf("/"), trimmed.lastIndexOf("\\"));
							if (at <= 0) {
								setRootPath(null);
								return;
							}
							const parent = trimmed.slice(0, at);
							setRootPath(/^[A-Za-z]:$/.test(parent) ? parent + "\\" : parent);
						},
						children: "\u2191"
					}), /* @__PURE__ */ (0, react_jsx_runtime.jsx)("input", {
						key: root === void 0 ? "none" : root,
						type: "text",
						spellCheck: false,
						className: sidebar_module_css_default.explorerRoot,
						defaultValue: root ?? "",
						style: { flex: 1, minWidth: 0 },
						title: root,
						placeholder: t("noSession"),
						onKeyDown: (event) => {
							if (event.key === "Enter") {
								const value = event.currentTarget.value.trim();
								setRootPath(value === "" ? null : value);
							}
						}
					}),
'@
    $c = $c.Remove($start, $oldSpan.Length).Insert($start, $snipHeader.TrimEnd())
}

# 6) 我的电脑菜单（插在右键菜单之前）
$b7 = '(0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.Menu, {'
if (-not $c.Contains('open: driveMenu !== null,')) {
    $i = $c.IndexOf($b7)
    if ($i -lt 0) { Write-Error "CLIENT menu anchor missing" }
    $snipMenu = @'
/* @__PURE__ */ (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.Menu, {
					open: driveMenu !== null,
					onClose: () => {
						setDriveMenu(null);
					},
					items: [
						...driveData.drives.map((drive) => ({ id: "d:" + drive, label: drive })),
						...(driveData.home !== "" ? [
							{ id: "h:desktop", label: "\u684c\u9762" },
							{ id: "h:documents", label: "\u6587\u6863" },
							{ id: "h:downloads", label: "\u4e0b\u8f7d" }
						] : [])
					],
					onSelect: (id) => {
						setDriveMenu(null);
						if (id.startsWith("d:")) {
							setRootPath(id.slice(2));
							return;
						}
						if (id === "h:desktop") setRootPath(driveData.home + "\\Desktop");
						else if (id === "h:documents") setRootPath(driveData.home + "\\Documents");
						else if (id === "h:downloads") setRootPath(driveData.home + "\\Downloads");
					},
					portal: true,
					align: "start",
					getAnchorRect: () => driveMenu === null ? null : new DOMRect(driveMenu.x, driveMenu.y, 0, 0),
					anchor: /* @__PURE__ */ (0, react_jsx_runtime.jsx)("span", {})
				}), 
'@
    $c = $c.Insert($i, $snipMenu)
}

# 7) 双击目录进入
$b8 = "`t`t`t`t`t`t`t" + 'onClick: () => {' + "`n`t`t`t`t`t`t`t`t" + 'onToggle(entry.path);' + "`n`t`t`t`t`t`t`t" + '},' + "`n`t`t`t`t`t`t`t" + 'onKeyDown: (event) => {'
$r8 = "`t`t`t`t`t`t`t" + 'onClick: () => {' + "`n`t`t`t`t`t`t`t`t" + 'onToggle(entry.path);' + "`n`t`t`t`t`t`t`t" + '},' + "`n`t`t`t`t`t`t`t" + 'onDoubleClick: () => {' + "`n`t`t`t`t`t`t`t`t" + 'setRootPath(entry.path);' + "`n`t`t`t`t`t`t`t" + '},' + "`n`t`t`t`t`t`t`t" + 'onKeyDown: (event) => {'
if ($c.Contains($b8)) { $c = $c.Replace($b8, $r8) } elseif (-not $c.Contains('onDoubleClick: () => {')) { Write-Error "CLIENT dblclick anchor missing" }

[System.IO.File]::WriteAllText($cli, $c, (New-Object System.Text.UTF8Encoding $false))

# ============ 语法校验 ============
$node = "node"
$ok = $true
& $node --check $idx 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Output "HOST syntax FAILED"; $ok = $false }
& $node --check $cli 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Output "CLIENT syntax FAILED"; $ok = $false }
if (-not $ok) { exit 1 }
Write-Output "better-sidebar patched OK (host + client). Restart dsh web, then hard-refresh the page."
