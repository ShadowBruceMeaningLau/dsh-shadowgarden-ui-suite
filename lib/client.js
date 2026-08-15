// dsh-shadowgarden-ui-suite — client half (runs in the DSH web page)
// Injects the Shadow theme stylesheets and the kanban/effects layer. The
// assets are served by the plugin host routes; the kanban script guards
// against double injection on its own.
(function () {
  "use strict";
  if (window.top !== window.self) return;

  function injectLink(href) {
    if (document.querySelector('link[href="' + href + '"]')) return;
    const link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = href;
    document.head.appendChild(link);
  }

  function injectScript(src) {
    if (document.querySelector('script[src="' + src + '"]')) return;
    const script = document.createElement("script");
    script.src = src;
    script.defer = true;
    document.head.appendChild(script);
  }

  injectLink("/shadow-theme.css");
  injectLink("/dsh-kanban.css");
  injectScript("/dsh-kanban.js");
})();
