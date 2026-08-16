// dsh-shadowgarden-ui-suite — client half
// Evaluated by the dsh client module system: the bundle must register
// synchronously with the shell's module table, and the factory MUST return a
// proper plugin shape ({ apply }) — the client kernel applies the factory's
// return value as the plugin. Returning a bare object fails the whole boot
// with "invalid plugin, expect function or object with an apply method".
window.__ModuleLoader__.load({
    id: "dsh-shadowgarden-ui-suite",
    factory: function (require) {
        function apply(ctx) {
            // No-op inside iframes (e.g. split.html panes): the theme is
            // injected once by the top window.
            if (window.top !== window.self) return;

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
        }

        return { apply: apply };
    }
});
