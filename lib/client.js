// dsh-shadowgarden-ui-suite — client half
// The dsh client-modules loader evaluates this bundle and expects a
// synchronous __ModuleLoader__.load registration with the package id —
// no guards, no deferral (a skipped registration fails the whole import).
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
