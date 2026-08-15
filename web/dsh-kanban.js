/* DeepSeek Harness — Shadow 定制注入层 v74
   右缘仅一个把手：看板（打开抽屉）。服务入口统一由服务中心窗口负责。
   特效：星尘+流星、三重旋转幽灵框、全局边界灯+流光、能量接缝（三色彗星+宝石）
   任务完成通知：Windows 原生通知 / PowerShell 气泡（dshnotify://）
   版本徽标：侧边栏字标下方
*/
(function () {
  "use strict";
  if (window.top !== window.self) return;
  if (document.getElementById("dsk-root")) return;

  var VER_TEXT = "v0.1.0-rc.6 · 定制 v78";
  var OPEN_KEY = "dsh-kanban-open";
  var WIDTH_KEY = "dsh-kanban-width";
  var MIN_W = 340;

  var root = document.createElement("div");
  root.id = "dsk-root";

  /* ---- 看板把手 ---- */
  var btn = document.createElement("button");
  btn.className = "dsk-btn";
  btn.title = "看板 · Kanban";
  btn.setAttribute("aria-label", "打开看板");
  btn.innerHTML =
    '<svg viewBox="0 0 24 24" aria-hidden="true">' +
    '<rect x="3" y="4" width="6" height="16" rx="1.6"/>' +
    '<rect x="9.8" y="4" width="5.2" height="10" rx="1.6"/>' +
    '<rect x="15.8" y="4" width="5.2" height="13" rx="1.6"/>' +
    "</svg>";

  /* ---- 看板抽屉 ---- */
  var drawer = document.createElement("div");
  drawer.className = "dsk-drawer";
  drawer.innerHTML =
    '<div class="dsk-handle" title="拖动调整宽度 · 影之剑">' +
    '<div class="dsk-sword"><i class="sw-guard"></i><i class="sw-pommel"></i><i class="sw-blade"></i></div>' +
    "</div>" +
    '<div class="dsk-head">' +
    '<span class="dsk-title">看板 · Kanban</span>' +
    '<span class="dsk-tools">' +
    '<button class="dsk-close" title="关闭">&#10005;</button>' +
    "</span>" +
    "</div>" +
    '<iframe class="dsk-frame" title="kanban" allow="clipboard-read; clipboard-write"></iframe>';

  var frame = drawer.querySelector(".dsk-frame");
  var handle = drawer.querySelector(".dsk-handle");
  var loaded = false;

  function setOpen(open) {
    drawer.classList.toggle("dsk-open", open);
    btn.style.display = open ? "none" : "flex";
    if (open && !loaded) {
      loaded = true;
      frame.src = "/kanban.html?v=15";
    }
    try {
      localStorage.setItem(OPEN_KEY, open ? "1" : "0");
    } catch (e) {}
  }

  /* ---- 看板按钮：固定居中，点击打开 ---- */
  btn.addEventListener("click", function () {
    setOpen(true);
  });

  /* ---- 抽屉：左缘拖拽调宽 ---- */
  var resizing = false;
  var startX = 0;
  var startW = 0;

  handle.addEventListener("pointerdown", function (e) {
    resizing = true;
    startX = e.clientX;
    startW = drawer.getBoundingClientRect().width;
    drawer.classList.add("dsk-resizing");
    frame.style.pointerEvents = "none";
    e.preventDefault();
  });
  window.addEventListener("pointermove", function (e) {
    if (!resizing) return;
    var maxW = window.innerWidth * 0.92;
    var w = startW + (startX - e.clientX);
    w = Math.min(Math.max(w, MIN_W), maxW);
    drawer.style.width = w + "px";
  });
  window.addEventListener("pointerup", function () {
    if (!resizing) return;
    resizing = false;
    drawer.classList.remove("dsk-resizing");
    frame.style.pointerEvents = "";
    try {
      localStorage.setItem(WIDTH_KEY, String(Math.round(drawer.getBoundingClientRect().width)));
    } catch (e) {}
  });

  /* ---- 关闭 ---- */
  drawer.querySelector(".dsk-close").addEventListener("click", function () {
    setOpen(false);
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && drawer.classList.contains("dsk-open")) {
      setOpen(false);
    }
  });
  document.addEventListener("pointerdown", function (e) {
    if (!drawer.classList.contains("dsk-open")) return;
    if (drawer.contains(e.target)) return;
    setOpen(false);
  });

  /* ---- FX：星尘 + 流星 ---- */
  var fx = document.createElement("div");
  fx.className = "dsk-fx";
  fx.innerHTML = '<canvas class="dsk-stars"></canvas>';
  root.appendChild(fx);
  var frameWrap = document.createElement("div");
  frameWrap.className = "dsk-frame-wrap";
  frameWrap.innerHTML = '<i class="dsk-frame-rot"></i><i class="dsk-frame-rot2"></i><i class="dsk-frame-rot3"></i>';
  root.appendChild(frameWrap);
  var globalBorder = document.createElement("div");
  globalBorder.className = "dsk-global-border";
  root.appendChild(globalBorder);

  var starsCanvas = fx.querySelector(".dsk-stars");
  var sctx = starsCanvas.getContext("2d");
  var stars = [];
  var meteors = [];
  var lastT = 0;
  var nextMeteorAt = 1500;
  (function makeStars() {
    stars = [];
    for (var i = 0; i < 90; i++) {
      var tint = Math.random();
      var color = tint < 0.7 ? "200,205,255" : (tint < 0.9 ? "167,139,250" : "244,63,94");
      stars.push({
        x: Math.random(),
        y: Math.random(),
        r: 0.4 + Math.random() * 1.1,
        phase: Math.random() * Math.PI * 2,
        speed: 0.4 + Math.random() * 1.2,
        drift: 0.00002 + Math.random() * 0.00006,
        color: color
      });
    }
  })();
  function sizeStars() {
    starsCanvas.width = window.innerWidth;
    starsCanvas.height = window.innerHeight;
  }
  window.addEventListener("resize", sizeStars);
  sizeStars();
  function spawnMeteor(w, h) {
    var fromLeft = Math.random() < 0.5;
    var x = fromLeft ? Math.random() * w * 0.6 : w * (0.2 + Math.random() * 0.8);
    var y = Math.random() * h * 0.25;
    var angle = (fromLeft ? 1 : -1) * (Math.PI / 5 + Math.random() * Math.PI / 6);
    var speed = 900 + Math.random() * 700;
    meteors.push({ x: x, y: y, vx: Math.cos(angle) * speed, vy: Math.abs(Math.sin(angle)) * speed, life: 0 });
  }
  function drawStars(t) {
    var dt = lastT ? (t - lastT) / 1000 : 0.016;
    lastT = t;
    if (!fx.hidden) {
      var w = starsCanvas.width;
      var h = starsCanvas.height;
      sctx.clearRect(0, 0, w, h);
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i];
        s.x += s.drift;
        if (s.x > 1) s.x -= 1;
        var a = 0.25 + 0.55 * (0.5 + 0.5 * Math.sin(t / 1000 * s.speed + s.phase));
        sctx.fillStyle = "rgba(" + s.color + "," + a.toFixed(3) + ")";
        sctx.beginPath();
        sctx.arc(s.x * w, s.y * h, s.r, 0, Math.PI * 2);
        sctx.fill();
      }
      if (t >= nextMeteorAt) {
        spawnMeteor(w, h);
        nextMeteorAt = t + 3500 + Math.random() * 5000;
      }
      for (var m = meteors.length - 1; m >= 0; m--) {
        var me = meteors[m];
        me.life += dt;
        if (me.life > 0.85) { meteors.splice(m, 1); continue; }
        me.x += me.vx * dt;
        me.y += me.vy * dt;
        var tx = me.x - me.vx * 0.16;
        var ty = me.y - me.vy * 0.16;
        var grad = sctx.createLinearGradient(me.x, me.y, tx, ty);
        var fa = 1 - me.life / 0.85;
        grad.addColorStop(0, "rgba(255,255,255," + (0.95 * fa).toFixed(3) + ")");
        grad.addColorStop(1, "rgba(139,92,246,0)");
        sctx.strokeStyle = grad;
        sctx.lineWidth = 1.6;
        sctx.beginPath();
        sctx.moveTo(me.x, me.y);
        sctx.lineTo(tx, ty);
        sctx.stroke();
      }
    }
    requestAnimationFrame(drawStars);
  }
  requestAnimationFrame(drawStars);
  function syncFx() {
    var dark = document.body.hasAttribute("data-ds-dark-theme");
    fx.hidden = !dark;
    frameWrap.hidden = !dark;
    globalBorder.hidden = !dark;
    root.classList.toggle("dsk-dark", dark);
  }
  syncFx();
  var fxObserver = new MutationObserver(syncFx);
  fxObserver.observe(document.body, { attributes: true, attributeFilter: ["data-ds-dark-theme"] });

  /* ---- 版本徽标 ---- */
  function findWordmarkSvg() {
    var svgs = document.querySelectorAll("svg");
    for (var i = 0; i < svgs.length; i++) {
      if (svgs[i].getAttribute("viewBox") === "0 0 182 24") return svgs[i];
    }
    return null;
  }
  var verEl = null;
  var seenWordmark = false;
  var verTicks = 0;
  function placeVersion() {
    var svg = findWordmarkSvg();
    if (!svg) return false;
    seenWordmark = true;
    var r = svg.getBoundingClientRect();
    if ((r.width === 0 && r.height === 0) || r.width < 120) {
      if (verEl) verEl.style.display = "none";
      return true;
    }
    if (!verEl) {
      verEl = document.createElement("div");
      verEl.id = "dsk-ver";
      verEl.className = "dsk-ver-inline";
      verEl.textContent = VER_TEXT;
      root.appendChild(verEl);
    }
    verEl.style.display = "";
    verEl.style.left = Math.round(r.left) + "px";
    verEl.style.top = Math.round(r.bottom + 4) + "px";
    return true;
  }

  /* ---- 能量接缝（三色彗星 + 宝石） ---- */
  var seam = document.createElement("div");
  seam.className = "dsk-seam";
  seam.innerHTML = '<i class="dsk-gem dsk-gem-t"></i><i class="dsk-gem dsk-gem-b"></i><i class="dsk-comet3"></i>';
  root.appendChild(seam);
  function findSidebarColumn() {
    var svg = findWordmarkSvg();
    if (!svg) return null;
    var node = svg;
    var best = null;
    var vh = window.innerHeight;
    var vw = window.innerWidth;
    for (var i = 0; i < 7 && node; i++) {
      node = node.parentElement;
      if (!node) break;
      var r = node.getBoundingClientRect();
      if (r.left < 2 && r.height >= vh * 0.9 && r.width >= 56 && r.width < vw * 0.5) {
        best = node;
      }
    }
    return best;
  }
  function placeSeam() {
    if (!document.body.hasAttribute("data-ds-dark-theme")) { seam.style.display = "none"; return; }
    var col = findSidebarColumn();
    if (!col) { seam.style.display = "none"; return; }
    var r = col.getBoundingClientRect();
    if (r.width < 120) { seam.style.display = "none"; return; }
    seam.style.display = "";
    seam.style.left = Math.round(r.right - 1) + "px";
    seam.style.height = window.innerHeight + "px";
  }

  /* ---- 任务完成通知 ---- */
  var turnRunning = false;
  var quietSec = 0;
  function isRunning() {
    var els = document.querySelectorAll("[aria-label]");
    for (var i = 0; i < els.length; i++) {
      var l = els[i].getAttribute("aria-label") || "";
      if (l.indexOf("停止") >= 0 || l.indexOf("Stop generating") >= 0) return true;
    }
    return false;
  }
  var activityLast = 0;
  var actObserver = new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      if (root.contains(muts[i].target)) continue;
      activityLast = Date.now();
      break;
    }
  });
  actObserver.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
    attributeFilter: ["class", "aria-label"]
  });
  function balloonNotify() {
    try {
      var a = document.createElement("a");
      a.href = "dshnotify://done";
      a.style.display = "none";
      document.body.appendChild(a);
      a.click();
      a.remove();
      console.log("[dsh-notify] balloon protocol fired");
    } catch (e) {
      console.log("[dsh-notify] balloon failed:", e);
    }
  }
  function notifyComplete() {
    var title = "DeepSeek Harness";
    var body = "任务已完成";
    try { console.log("[dsh-notify] task completion detected"); } catch (e) {}
    if ("Notification" in window && Notification.permission === "granted") {
      try {
        new Notification(title, { body: body, icon: "/favicon.svg" });
        console.log("[dsh-notify] native notification sent");
        return;
      } catch (e) {
        console.log("[dsh-notify] native failed:", e);
        balloonNotify();
        return;
      }
    }
    if ("Notification" in window && Notification.permission === "default") {
      try {
        var settled = false;
        Notification.requestPermission().then(function (p) {
          settled = true;
          console.log("[dsh-notify] permission result:", p);
          if (p === "granted") {
            try { new Notification(title, { body: body, icon: "/favicon.svg" }); } catch (e) { balloonNotify(); }
          } else {
            balloonNotify();
          }
        }).catch(function (e) {
          console.log("[dsh-notify] requestPermission error:", e);
          balloonNotify();
        });
        setTimeout(function () {
          if (!settled) {
            console.log("[dsh-notify] permission unanswered, using balloon");
            balloonNotify();
          }
        }, 3000);
        return;
      } catch (e) {
        console.log("[dsh-notify] requestPermission threw:", e);
        balloonNotify();
        return;
      }
    }
    balloonNotify();
  }

  /* ---- 主循环 ---- */
  var verTimer = setInterval(function () {
    try {
      verTicks++;
      var placed = placeVersion();
      placeSeam();
      var running = isRunning();
      var actRecent = (Date.now() - activityLast) < 500;
      if (running) {
        if (!turnRunning) {
          turnRunning = true;
          try { console.log("[dsh-notify] run started"); } catch (e) {}
        }
        quietSec = 0;
      } else if (turnRunning) {
        if (actRecent) {
          quietSec = 0;
        } else {
          quietSec += 0.2;
          if (quietSec >= 3) {
            turnRunning = false;
            quietSec = 0;
            try { console.log("[dsh-notify] run ended"); } catch (e) {}
            notifyComplete();
          }
        }
      }
      var fb = document.getElementById("dsk-ver-fallback");
      if (placed) {
        if (fb) fb.remove();
      } else if (seenWordmark) {
        if (verEl) verEl.style.display = "none";
        if (fb) fb.remove();
      } else if (verTicks > 6 && !fb) {
        fb = document.createElement("div");
        fb.id = "dsk-ver-fallback";
        fb.className = "dsk-ver";
        fb.textContent = VER_TEXT;
        root.appendChild(fb);
      }
    } catch (e) {}
  }, 200);
  window.addEventListener("resize", function () {
    try { placeVersion(); placeSeam(); } catch (e) {}
  });
  try { console.log("[dsh-notify] watcher armed"); } catch (e) {}

  /* ---- 设置页/弹窗层级：特效 z-index 500/501 天然低于 DSH 弹窗遮罩(1000)，
     因此设置页打开时特效自动处于其下方，无需隐藏逻辑 ---- */

  /* ---- 恢复记忆 ---- */
  var startOpen = false;
  try {
    startOpen = localStorage.getItem(OPEN_KEY) === "1";
    var savedW = parseInt(localStorage.getItem(WIDTH_KEY), 10);
    if (!isNaN(savedW)) {
      var maxW = window.innerWidth * 0.92;
      drawer.style.width = Math.min(Math.max(savedW, MIN_W), maxW) + "px";
    }
  } catch (e) {}

  root.appendChild(btn);
  root.appendChild(drawer);
  document.body.appendChild(root);

  setOpen(startOpen);
})();
