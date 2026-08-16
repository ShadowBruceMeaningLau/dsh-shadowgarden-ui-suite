using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using Microsoft.VisualBasic;

public class HubTab
{
    public string Name;
    public string Url;
    public WebView2 View;
    public Panel Wrap;
    public Button Btn;
    public bool Closable;
}

public class HubForm : Form
{
    private List<HubTab> tabs = new List<HubTab>();
    private Panel content;
    private FlowLayoutPanel tabBar;
    private Button addBtn;
    private ContextMenuStrip addMenu;
    private int active = 0;
    private int startTab = 0;
    private int ghSeq = 0;
    private int chatSeq = 0;
    private int dshSeq = 0;
    private int multiSeq = 0;
    private int winSeq = 1;
    private string pendingSwitch = null;
    private CoreWebView2Environment env;
    private CoreWebView2Environment dshEnv;
    private ContextMenuStrip tabMenu;
    private Panel addrBar;
    private TextBox addrBox;
    private Button addrGo;
    private bool dragActive = false;
    private bool dragMoved = false;
    private int dragIdx = -1;
    private Point dragStart;
    private bool fullscreen = false;
    private Rectangle prevFsBounds;
    private bool prevWasMaximized = false;

    private static readonly Color C_BG = Color.FromArgb(11, 11, 20);
    private static readonly Color C_CONTENT = Color.FromArgb(7, 7, 13);
    private static readonly Color C_TAB_ACTIVE = Color.FromArgb(34, 29, 58);
    private static readonly Color C_CLOSE_HOVER = Color.FromArgb(64, 20, 42);
    private static readonly Color C_TEXT_ACTIVE = Color.FromArgb(196, 181, 253);
    private static readonly Color C_TEXT = Color.FromArgb(154, 154, 184);

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    /* 深色标题栏：沉浸式暗色 + Win11 自定义标题栏颜色（Shadow 配色） */
    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        try
        {
            int dark = 1;
            DwmSetWindowAttribute(Handle, 20 /*DWMWA_USE_IMMERSIVE_DARK_MODE*/, ref dark, 4);
            int caption = 0x00140B0B; // COLORREF(BGR) of RGB(11,11,20)
            DwmSetWindowAttribute(Handle, 35 /*DWMWA_CAPTION_COLOR (Win11)*/, ref caption, 4);
            int text = 0x00FDB5C4;    // COLORREF(BGR) of RGB(196,181,253)
            DwmSetWindowAttribute(Handle, 36 /*DWMWA_TEXT_COLOR (Win11)*/, ref text, 4);
        }
        catch { }
    }

    /* 标准 Windows 窗口：拖动/缩放/吸附/最大化全部由系统原生提供 */

    public HubForm(string initialHost, int seq)
    {
        winSeq = seq;
        Text = "DeepSeek Harness · 旗舰版";
        BackColor = C_BG;
        Size = new Size(1280, 820);
        MinimumSize = new Size(820, 520);
        StartPosition = FormStartPosition.CenterScreen;
        try
        {
            string ico = Path.Combine(Application.StartupPath, "..", "assets", "deepseek.ico");
            if (!File.Exists(ico)) ico = Path.Combine(Application.StartupPath, "deepseek.ico");
            if (File.Exists(ico)) Icon = new Icon(ico);
        }
        catch { }

        tabBar = new FlowLayoutPanel();
        tabBar.Dock = DockStyle.Top;
        tabBar.BackColor = C_BG;
        tabBar.Padding = new Padding(6, 6, 6, 2);
        tabBar.WrapContents = true;
        tabBar.AutoSize = true;
        tabBar.AutoSizeMode = AutoSizeMode.GrowAndShrink;

        content = new Panel();
        content.Dock = DockStyle.Fill;
        content.BackColor = C_CONTENT;

        /* 地址栏：每个标签可输入任意网址跳转；DSH/用量/Chat 三个固定标签保留 */
        addrBar = new Panel();
        addrBar.Dock = DockStyle.Top;
        addrBar.Height = 32;
        addrBar.BackColor = C_BG;
        addrBar.Padding = new Padding(6, 4, 6, 4);

        addrGo = new Button();
        addrGo.Text = "前往";
        addrGo.Dock = DockStyle.Right;
        addrGo.Width = 58;
        addrGo.FlatStyle = FlatStyle.Flat;
        addrGo.FlatAppearance.BorderSize = 1;
        addrGo.FlatAppearance.BorderColor = Color.FromArgb(96, 74, 168);
        addrGo.FlatAppearance.MouseOverBackColor = C_TAB_ACTIVE;
        addrGo.ForeColor = C_TEXT_ACTIVE;
        addrGo.Font = new Font("Microsoft YaHei UI", 9f);
        addrGo.Click += (s, e) => NavigateActive();

        addrBox = new TextBox();
        addrBox.Dock = DockStyle.Fill;
        addrBox.BackColor = Color.FromArgb(20, 20, 32);
        addrBox.ForeColor = C_TEXT_ACTIVE;
        addrBox.BorderStyle = BorderStyle.FixedSingle;
        addrBox.Font = new Font("Consolas", 9.5f);
        addrBox.KeyDown += AddrKeyDown;

        addrBar.Controls.Add(addrBox);
        addrBar.Controls.Add(addrGo);

        Controls.Add(content);
        Controls.Add(addrBar);
        Controls.Add(tabBar);

        /* “+”按钮与菜单 */
        addBtn = new Button();
        addBtn.Text = "＋";
        addBtn.FlatStyle = FlatStyle.Flat;
        addBtn.FlatAppearance.BorderSize = 0;
        addBtn.FlatAppearance.MouseOverBackColor = C_TAB_ACTIVE;
        addBtn.ForeColor = C_TEXT_ACTIVE;
        addBtn.Size = new Size(32, 28);
        addBtn.Margin = new Padding(2, 0, 2, 0);
        addBtn.Font = new Font("Microsoft YaHei UI", 10f);
        addBtn.Cursor = Cursors.Hand;

        addMenu = new ContextMenuStrip();
        var mDsh = addMenu.Items.Add("新 DSH 标签");
        var mGh = addMenu.Items.Add("新 GitHub 标签");
        var mChat = addMenu.Items.Add("新 Chat 标签");
        var mUrl = addMenu.Items.Add("自定义网址…");
        mDsh.Click += (s, e) => AddTabAsyncSafe("DSH " + (++dshSeq), "http://127.0.0.1:3080", true);
        mGh.Click += (s, e) => AddTabAsyncSafe("GitHub " + (++ghSeq), "https://github.com", true);
        mChat.Click += (s, e) => AddTabAsyncSafe("Chat " + (++chatSeq), "https://chat.deepseek.com/", true);
        mUrl.Click += (s, e) =>
        {
            string u = Interaction.InputBox("输入网址（以 http/https 开头）：", "自定义标签", "https://", -1, -1);
            if (!string.IsNullOrWhiteSpace(u) && (u.StartsWith("http://") || u.StartsWith("https://")))
                AddTabAsyncSafe(u, u, true);
        };
        addBtn.Click += (s, e) => addMenu.Show(addBtn, new Point(0, addBtn.Height));

        tabMenu = new ContextMenuStrip();
        tabMenu.Items.Add("删除标签");
        tabMenu.ItemClicked += TabMenuDelete;

        tabBar.Controls.Add(addBtn);

        /* F11 全屏切换 / Esc 退出全屏（键盘快捷键，对标极速版） */
        KeyPreview = true;
        KeyDown += (s, e) =>
        {
            if (e.KeyCode == Keys.F11)
            {
                ToggleFullscreen();
                e.Handled = true;
                e.SuppressKeyPress = true;
            }
            else if (e.KeyCode == Keys.Escape && fullscreen)
            {
                ExitFullscreen();
                e.Handled = true;
            }
            else if (e.KeyCode == Keys.F12)
            {
                // 调试：为当前标签打开 WebView2 开发者工具
                if (active >= 0 && active < tabs.Count)
                {
                    var t = tabs[active];
                    if (t.View != null && t.View.CoreWebView2 != null)
                    {
                        try { t.View.CoreWebView2.OpenDevToolsWindow(); } catch { }
                    }
                }
                e.Handled = true;
            }
        };

        startTab = MatchTab(initialHost);
        active = startTab;
        Load += async (s, e) => await InitAsync();
        FormClosing += (s, e) => Cleanup();
    }

    private async void AddTabAsyncSafe(string name, string url, bool closable)
    {
        if (env == null) return;
        try { await AddTabAsync(name, url, closable); }
        catch (Exception ex) { MessageBox.Show("打开标签失败：" + ex.Message, "DSH 服务中心"); }
    }

    private async System.Threading.Tasks.Task InitAsync()
    {
        try
        {
            string baseDir = HubRuntime.UdfBase();
            if (HubRuntime.SharedEnvTask == null)
                HubRuntime.SharedEnvTask = CoreWebView2Environment.CreateAsync(null, baseDir);
            env = await HubRuntime.SharedEnvTask;
            dshEnv = env;
            if (winSeq >= 2)
            {
                try { dshEnv = await CoreWebView2Environment.CreateAsync(null, Path.Combine(baseDir, "win-" + winSeq)); }
                catch { dshEnv = env; }
            }
            await AddTabAsync("DSH", "http://127.0.0.1:3080", false);
            await AddTabAsync("用量", "https://platform.deepseek.com/usage", false);
            await AddTabAsync("Chat", "https://chat.deepseek.com/", false);
            if (startTab == -1)
                await AddTabAsync("GitHub " + (++ghSeq), "https://github.com", true);
            else
                ShowTab(startTab);
            if (pendingSwitch != null)
            {
                string h = pendingSwitch;
                pendingSwitch = null;
                SwitchTo(h);
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show("WebView2 初始化失败：" + ex.Message, "DSH 服务中心", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private async System.Threading.Tasks.Task AddTabAsync(string name, string url, bool closable)
    {
        var wrap = new Panel();
        wrap.AutoSize = true;
        wrap.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        wrap.Height = 28;
        wrap.Margin = new Padding(2, 0, 2, 0);
        wrap.BackColor = C_BG;

        var b = new Button();
        b.Text = name;
        b.FlatStyle = FlatStyle.Flat;
        b.FlatAppearance.BorderSize = 0;
        b.FlatAppearance.MouseOverBackColor = C_TAB_ACTIVE;
        b.AutoSize = true;
        b.Height = 28;
        b.Padding = new Padding(12, 0, 12, 0);
        b.Margin = new Padding(0);
        b.Font = new Font("Microsoft YaHei UI", 9.5f);
        b.Cursor = Cursors.Hand;
        b.Tag = wrap;
        b.Click += TabBtnClick;
        wrap.Controls.Add(b);

        if (closable)
        {
            b.ContextMenuStrip = tabMenu;
            b.MouseDown += TabMouseDown;
            b.MouseMove += TabMouseMove;
            b.MouseUp += TabMouseUp;

            var x = new Button();
            x.Text = "×";
            x.FlatStyle = FlatStyle.Flat;
            x.FlatAppearance.BorderSize = 0;
            x.FlatAppearance.MouseOverBackColor = C_CLOSE_HOVER;
            x.ForeColor = C_TEXT;
            x.Size = new Size(22, 28);
            x.Margin = new Padding(0);
            x.Font = new Font("Microsoft YaHei UI", 10f);
            x.Cursor = Cursors.Hand;
            x.Tag = wrap;
            x.Click += CloseBtnClick;
            wrap.Controls.Add(x);
        }

        tabBar.Controls.Add(wrap);
        tabBar.Controls.Add(addBtn); // 保持“+”在末尾

        var wv = new WebView2();
        wv.Dock = DockStyle.Fill;
        content.Controls.Add(wv);
        CoreWebView2Environment wvEnv = env;
        if (url == "http://127.0.0.1:3080")
        {
            if (closable)
            {
                multiSeq = multiSeq + 1;
                try
                {
                    string ud = Path.Combine(HubRuntime.UdfBase(), "win-" + winSeq + "-multi-" + multiSeq);
                    wvEnv = await CoreWebView2Environment.CreateAsync(null, ud);
                }
                catch { }
            }
            else
            {
                wvEnv = dshEnv;
            }
        }
        await wv.EnsureCoreWebView2Async(wvEnv);
        // 「用量」标签伪装为标准 Chrome UA：platform.deepseek.com 对 WebView2
        // 默认 UA 可能走降级渲染路径（Edge 正常、内嵌 WebView2 局部显示）。
        // 只作用于本标签，不影响 DSH/Chat/GitHub 标签的现有行为。
        if (url.Contains("platform.deepseek.com"))
        {
            wv.CoreWebView2.Settings.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36";
        }
        // 页内跳转同步到地址栏
        int navIdx = tabs.Count;
        wv.CoreWebView2.NavigationStarting += (s2, e2) =>
        {
            if (navIdx >= 0 && navIdx < tabs.Count) tabs[navIdx].Url = e2.Uri;
            if (navIdx == active && addrBox != null && !addrBox.Focused) addrBox.Text = e2.Uri;
        };
        wv.CoreWebView2.NavigationCompleted += (s2, e2) =>
        {
            if (navIdx == active && e2.IsSuccess && addrBox != null && !addrBox.Focused && navIdx < tabs.Count)
                addrBox.Text = tabs[navIdx].Url ?? "";
        };
        wv.Source = new Uri(url);

        tabs.Add(new HubTab { Name = name, Url = url, View = wv, Wrap = wrap, Btn = b, Closable = closable });
        ShowTab(tabs.Count - 1);
    }

    private int IndexOfWrap(Control c)
    {
        for (int i = 0; i < tabs.Count; i++)
            if (tabs[i].Wrap == c) return i;
        return -1;
    }

    private void TabBtnClick(object sender, EventArgs e)
    {
        int idx = IndexOfWrap((Control)((Button)sender).Tag);
        if (idx >= 0) ShowTab(idx);
    }

    private void CloseBtnClick(object sender, EventArgs e)
    {
        int idx = IndexOfWrap((Control)((Button)sender).Tag);
        if (idx >= 0) CloseTab(idx);
    }

    private void TabMouseDown(object sender, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        int idx = IndexOfWrap((Control)((Button)sender).Tag);
        if (idx < 3) return; // 固定标签不可拖动
        dragActive = true;
        dragMoved = false;
        dragIdx = idx;
        dragStart = Control.MousePosition;
    }

    private void TabMouseMove(object sender, MouseEventArgs e)
    {
        if (!dragActive) return;
        Point cur = Control.MousePosition;
        if (!dragMoved)
        {
            if (Math.Abs(cur.X - dragStart.X) < 10 && Math.Abs(cur.Y - dragStart.Y) < 10) return;
            dragMoved = true;
        }
        int curIdx = dragIdx;
        while (curIdx + 1 < tabs.Count)
        {
            var next = tabs[curIdx + 1];
            Rectangle rc = next.Wrap.RectangleToScreen(next.Wrap.ClientRectangle);
            if (cur.X > rc.Left + rc.Width / 2)
            {
                MoveTab(curIdx, curIdx + 1);
                curIdx = curIdx + 1;
                dragIdx = curIdx;
            }
            else break;
        }
        while (curIdx - 1 >= 3)
        {
            var prev = tabs[curIdx - 1];
            Rectangle rc = prev.Wrap.RectangleToScreen(prev.Wrap.ClientRectangle);
            if (cur.X < rc.Left + rc.Width / 2)
            {
                MoveTab(curIdx, curIdx - 1);
                curIdx = curIdx - 1;
                dragIdx = curIdx;
            }
            else break;
        }
    }

    private void TabMouseUp(object sender, MouseEventArgs e)
    {
        dragActive = false;
        dragMoved = false;
        dragIdx = -1;
    }

    private void MoveTab(int from, int to)
    {
        if (from < 3 || to < 3 || from == to || from >= tabs.Count || to >= tabs.Count) return;
        var t = tabs[from];
        tabs.RemoveAt(from);
        tabs.Insert(to, t);
        tabBar.Controls.SetChildIndex(t.Wrap, to);
        if (active == from) active = to;
        else if (active > from && active <= to) active = active - 1;
        else if (active < from && active >= to) active = active + 1;
    }

    private void TabMenuDelete(object sender, ToolStripItemClickedEventArgs e)
    {
        if (tabMenu.SourceControl != null)
        {
            int idx = IndexOfWrap((Control)tabMenu.SourceControl.Tag);
            CloseTab(idx);
        }
    }

    private void CloseTab(int idx)
    {
        if (idx < 0 || idx >= tabs.Count || !tabs[idx].Closable) return;
        var t = tabs[idx];
        try { t.View.Dispose(); } catch { }
        tabBar.Controls.Remove(t.Wrap);
        t.Wrap.Dispose();
        tabs.RemoveAt(idx);
        if (active >= tabs.Count) active = tabs.Count - 1;
        else if (active > idx) active = active - 1;
        ShowTab(active);
    }

    private int MatchTab(string host)
    {
        if (host.Contains("chat.deepseek")) return 2;
        if (host.Contains("platform.deepseek")) return 1;
        if (host.Contains("github")) return -1;
        return 0;
    }

    private int FindTabByName(string prefix)
    {
        for (int i = 0; i < tabs.Count; i++)
            if (tabs[i].Name.StartsWith(prefix)) return i;
        return -1;
    }

    private void ShowTab(int idx)
    {
        if (idx < 0 || idx >= tabs.Count) return;
        active = idx;
        for (int i = 0; i < tabs.Count; i++)
        {
            tabs[i].Btn.BackColor = (i == idx) ? C_TAB_ACTIVE : C_BG;
            tabs[i].Btn.ForeColor = (i == idx) ? C_TEXT_ACTIVE : C_TEXT;
            tabs[i].Btn.Font = new Font("Microsoft YaHei UI", 9.5f, (i == idx) ? FontStyle.Bold : FontStyle.Regular);
        }
        if (tabs[idx].View != null) tabs[idx].View.BringToFront();
        if (addrBox != null && !addrBox.Focused) addrBox.Text = tabs[idx].Url ?? "";
    }

    /* 地址栏回车/点击前往：导航当前标签到任意网址（自动补 https://） */
    private void AddrKeyDown(object sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter)
        {
            NavigateActive();
            e.Handled = true;
            e.SuppressKeyPress = true;
        }
        else if (e.KeyCode == Keys.Escape && active >= 0 && active < tabs.Count)
        {
            addrBox.Text = tabs[active].Url ?? "";
            e.Handled = true;
        }
    }

    private void NavigateActive()
    {
        if (active < 0 || active >= tabs.Count) return;
        var t = tabs[active];
        if (t.View == null || t.View.CoreWebView2 == null) return;
        string input = (addrBox.Text ?? "").Trim();
        if (input == "") return;
        if (!input.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
            !input.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            input = "https://" + input;
        try
        {
            t.Url = input;
            t.View.CoreWebView2.Navigate(input);
            addrBox.Text = input;
        }
        catch (Exception ex)
        {
            MessageBox.Show("无法打开网址：" + ex.Message, "DSH 服务中心");
        }
    }

    public void SwitchTo(string host)
    {
        try
        {
            if (env == null || tabs.Count < 3)
            {
                pendingSwitch = host;
                return;
            }
            if (WindowState == FormWindowState.Minimized)
                WindowState = FormWindowState.Normal;
            int idx = MatchTab(host);
            if (idx >= 0)
            {
                ShowTab(idx);
            }
            else if (host.Contains("github"))
            {
                int gi = FindTabByName("GitHub");
                if (gi >= 0) ShowTab(gi);
                else AddTabAsyncSafe("GitHub " + (++ghSeq), "https://github.com", true);
            }
            if (!fullscreen)
            {
                TopMost = true;
                BringToFront();
                Activate();
                TopMost = false;
            }
            else
            {
                BringToFront();
                Activate();
            }
        }
        catch { }
    }

    private DateTime lastFsToggle = DateTime.MinValue;

    public bool IsFullscreen { get { return fullscreen; } }

    public void ToggleFullscreen()
    {
        if ((DateTime.Now - lastFsToggle).TotalMilliseconds < 300) return;
        lastFsToggle = DateTime.Now;
        if (fullscreen) ExitFullscreen(); else EnterFullscreen();
    }

    private void EnterFullscreen()
    {
        prevFsBounds = Bounds;
        prevWasMaximized = (WindowState == FormWindowState.Maximized);
        TopMost = true;
        WindowState = FormWindowState.Normal;
        FormBorderStyle = FormBorderStyle.None;
        Bounds = Screen.FromControl(this).Bounds;
        fullscreen = true;
    }

    public void ExitFullscreen()
    {
        TopMost = false;
        FormBorderStyle = FormBorderStyle.Sizable;
        WindowState = FormWindowState.Normal;
        Bounds = prevFsBounds;
        if (prevWasMaximized) WindowState = FormWindowState.Maximized;
        fullscreen = false;
    }

    private void Cleanup()
    {
        try
        {
            foreach (var t in tabs) if (t.View != null) t.View.Dispose();
        }
        catch { }
    }
}

public static class HubLog
{
    public static void W(string msg)
    {
        try
        {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DSHHub");
            Directory.CreateDirectory(dir);
            File.AppendAllText(Path.Combine(dir, "hub.log"),
                DateTime.Now.ToString("HH:mm:ss.fff") + " [pid " + System.Diagnostics.Process.GetCurrentProcess().Id + "] " + msg + Environment.NewLine);
        }
        catch { }
    }
}

public static class HubRuntime
{
    public static int WinSeq = 0;
    public static HubForm LastActive = null;
    public static List<HubForm> OpenForms = new List<HubForm>();
    public static System.Threading.Tasks.Task<CoreWebView2Environment> SharedEnvTask = null;

    public static string UdfBase()
    {
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DSHHub", "WebView2");
    }
}

public static class ThemeGuard
{
    /* 主题自愈已改由 dsh 插件（dsh-shadowgarden-ui-suite）承担：
       主题/看板资源随插件常驻，无需任何部署步骤。 */
}

public class HubAppContext : ApplicationContext
{
    private System.Windows.Forms.Timer cmdTimer;

    public HubAppContext(string initialHost)
    {
        OpenWindow(initialHost);
        FsHotkey.EnsureInstalled();
        cmdTimer = new System.Windows.Forms.Timer();
        cmdTimer.Interval = 500;
        cmdTimer.Tick += (s, e) => PollCmd();
        cmdTimer.Start();
    }

    public void OpenWindow(string host)
    {
        HubLog.W("OpenWindow " + host);
        HubRuntime.WinSeq = HubRuntime.WinSeq + 1;
        var f = new HubForm(host, HubRuntime.WinSeq);
        HubLog.W("form created, seq=" + HubRuntime.WinSeq);
        f.Show();
        HubLog.W("form shown");
        HubRuntime.OpenForms.Add(f);
        HubRuntime.LastActive = f;
        f.Activated += (s, e) => { if (!f.IsDisposed) HubRuntime.LastActive = f; };
        f.FormClosed += (s, e) =>
        {
            HubLog.W("form closed, remaining=" + HubRuntime.OpenForms.Count);
            HubRuntime.OpenForms.Remove(f);
            if (HubRuntime.LastActive == f) HubRuntime.LastActive = null;
            if (HubRuntime.OpenForms.Count == 0) Application.Exit();
        };
    }

    private static string CmdPath()
    {
        string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DSHHub");
        try { Directory.CreateDirectory(dir); } catch { }
        return Path.Combine(dir, "cmd.txt");
    }

    private void PollCmd()
    {
        try
        {
            string p = CmdPath();
            if (!File.Exists(p)) return;
            string[] lines = File.ReadAllLines(p);
            File.Delete(p);
            HubLog.W("PollCmd lines=" + lines.Length);
            foreach (string raw in lines)
            {
                string line = raw.Trim();
                if (line.Length == 0) continue;
                string cmd = "SWITCH";
                string host = line;
                int sp = line.IndexOf(' ');
                if (sp > 0)
                {
                    cmd = line.Substring(0, sp);
                    host = line.Substring(sp + 1).Trim();
                }
                HubLog.W("cmd=" + cmd + " host=" + host);
                if (cmd == "NEW")
                {
                    OpenWindow(host);
                }
                else
                {
                    HubForm t = HubRuntime.LastActive;
                    if (t == null || t.IsDisposed)
                        t = HubRuntime.OpenForms.Count > 0 ? HubRuntime.OpenForms[HubRuntime.OpenForms.Count - 1] : null;
                    if (t != null) t.SwitchTo(host);
                }
            }
        }
        catch (Exception ex) { HubLog.W("PollCmd ex: " + ex.ToString()); }
    }
}

public static class FsHotkey
{
    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT { public uint vkCode; public uint scanCode; public uint flags; public uint time; public IntPtr dwExtraInfo; }
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string name);

    private static IntPtr hook = IntPtr.Zero;
    private static LowLevelKeyboardProc proc;

    public static void EnsureInstalled()
    {
        if (hook != IntPtr.Zero) return;
        try
        {
            proc = new LowLevelKeyboardProc(HookCallback);
            hook = SetWindowsHookEx(13 /*WH_KEYBOARD_LL*/, proc, GetModuleHandle(null), 0);
        }
        catch { }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        try
        {
            if (nCode >= 0 && wParam == (IntPtr)0x100) // WM_KEYDOWN
            {
                var k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
                if (k.vkCode == 0x7A || k.vkCode == 0x1B) // F11 / Esc
                {
                    uint pid;
                    IntPtr fg = GetForegroundWindow();
                    GetWindowThreadProcessId(fg, out pid);
                    if (pid == (uint)System.Diagnostics.Process.GetCurrentProcess().Id)
                    {
                        foreach (var f in HubRuntime.OpenForms)
                        {
                            if (f.IsDisposed || f.Handle != fg) continue;
                            if (k.vkCode == 0x7A) f.ToggleFullscreen();
                            else if (f.IsFullscreen) f.ExitFullscreen();
                            break;
                        }
                    }
                }
            }
        }
        catch { }
        return CallNextHookEx(hook, nCode, wParam, lParam);
    }
}

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        string initial = "dsh";
        bool isProtocol = false;
        if (args.Length > 0 && args[0].IndexOf("://") > 0)
        {
            initial = args[0].Substring(args[0].IndexOf("://") + 3).TrimEnd('/');
            isProtocol = true;
        }

        bool created;
        using (var mutex = new Mutex(true, "DSHHubSingleInstance", out created))
        {
            if (!created)
            {
                try
                {
                    string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DSHHub");
                    Directory.CreateDirectory(dir);
                    string line = (isProtocol ? "SWITCH " : "NEW ") + initial;
                    HubLog.W("second instance writing: " + line);
                    File.AppendAllText(Path.Combine(dir, "cmd.txt"), line + Environment.NewLine);
                }
                catch { }
                return;
            }

            HubLog.W("first instance, initial=" + initial + " protocol=" + isProtocol);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new HubAppContext(initial));
            HubLog.W("Application.Run returned");
        }
    }
}
