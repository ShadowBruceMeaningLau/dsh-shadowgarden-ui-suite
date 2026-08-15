// dsh-shadowgarden-ui-suite — client half
// Registers with the dsh client-modules loader synchronously (the loader
// rejects bundles that register late), then injects the Shadow theme and the
// kanban/effects layer from the plugin's /shadow asset routes.
(function () {
    "use strict";
    if (typeof window === "undefined" || !window.__ModuleLoader__) return;

    window.__ModuleLoader__.load({
        id: "dsh-shadowgarden-ui-suite",
        factory: function (require) {
            if (window.top !== window.self) return {};

            function injectLink(href) {
                if (document.querySelector('link[href="' + href + '"]')) return;
                var link = document.createElement("link");
                link.rel = "stylesheet";
                link.href = href;
                document.head.appendChild(link);
            }

            function injectScript(src) {
                if (document.querySelector('script[src="' + src + '"]')) return;
                var script = document.createElement("script");
                script.src = src;
                script.defer = true;
                document.head.appendChild(script);
            }

            injectLink("/shadow/shadow-theme.css");
            injectLink("/shadow/dsh-kanban.css");
            injectScript("/shadow/dsh-kanban.js");
            return {};
        }
    });
})();
