/**
 * Browser history for shinydashboard left-nav tabs.
 *
 * Problem: sidebar <a href="#shiny-tab-..."> creates hash history entries, so
 * Back often only toggles the hash and never changes the section.
 *
 * Solution: on sidebar clicks, preventDefault, pushState(?tab=...), and show
 * the tab ourselves. On popstate, restore the tab from ?tab=.
 */
(function () {
  "use strict";

  var VALID = {
    dashboard: true,
    books: true,
    sales_trends: true,
    authors: true,
    networks: true,
    royalties: true,
    royalty_query: true,
    genres: true,
    about: true
  };

  var handlerRegistered = false;
  var initDone = false;
  var lastWrittenTab = null;
  // Skip one server write after a client click already updated the URL
  var skipNextServerWrite = false;

  function readTab() {
    try {
      var params = new URLSearchParams(window.location.search);
      var tab = params.get("tab");
      if (tab && VALID[tab]) return tab;
    } catch (e) {
      /* ignore */
    }
    return null;
  }

  function buildUrl(tab) {
    // Intentionally drop hash — hash fragments fight with ?tab= history
    var url = new URL(window.location.href);
    url.searchParams.set("tab", tab);
    url.hash = "";
    return url.pathname + url.search;
  }

  function writeTab(tab, mode) {
    if (!VALID[tab]) return false;
    if (readTab() === tab && !window.location.hash) {
      lastWrittenTab = tab;
      return false;
    }
    var newUrl = buildUrl(tab);
    var state = { aneskoTab: tab };
    if (mode === "push") {
      window.history.pushState(state, "", newUrl);
    } else {
      window.history.replaceState(state, "", newUrl);
    }
    lastWrittenTab = tab;
    return true;
  }

  /**
   * Show a shinydashboard tab pane and mark the sidebar item active.
   */
  function showTab(tab) {
    if (!VALID[tab]) return;

    var paneId = "shiny-tab-" + tab;

    if (window.jQuery) {
      var $ = window.jQuery;
      $(".tab-pane").removeClass("active");
      $("#" + paneId).addClass("active");

      var $menu = $(".sidebar-menu");
      $menu.find("li").removeClass("active");

      var $link = $menu.find("a[data-value='" + tab + "']");
      if (!$link.length) {
        $link = $menu.find('a[href="#shiny-tab-' + tab + '"]');
      }
      if ($link.length) {
        $link.parents("li").first().addClass("active");
        $link.parents("li.treeview").addClass("active menu-open");
        $link.parents("ul.treeview-menu").css("display", "block");
      }
    } else {
      var panes = document.querySelectorAll(".tab-pane");
      for (var i = 0; i < panes.length; i++) {
        panes[i].classList.remove("active");
      }
      var pane = document.getElementById(paneId);
      if (pane) pane.classList.add("active");
    }
  }

  function setMainMenuInput(tab) {
    if (window.Shiny && typeof Shiny.setInputValue === "function") {
      Shiny.setInputValue("main_menu", tab, { priority: "event" });
    }
  }

  function notifyBrowserNav(tab, source) {
    if (!(window.Shiny && typeof Shiny.setInputValue === "function")) return;
    Shiny.setInputValue(
      "browser_nav_tab",
      { tab: tab, source: source, nonce: Date.now() },
      { priority: "event" }
    );
  }

  function tabFromAnchor(a) {
    if (!a) return null;
    var tab = a.getAttribute("data-value");
    if (tab && VALID[tab]) return tab;
    var href = a.getAttribute("href") || "";
    var m = href.match(/#shiny-tab-([A-Za-z0-9_]+)/);
    if (m && VALID[m[1]]) return m[1];
    return null;
  }

  function isSidebarLink(a) {
    if (!a) return false;
    if (a.closest) return !!a.closest(".sidebar-menu");
    var p = a.parentElement;
    while (p) {
      if (
        p.classList &&
        (p.classList.contains("sidebar-menu") || p.classList.contains("sidebar"))
      ) {
        return true;
      }
      p = p.parentElement;
    }
    return false;
  }

  function registerHandlers() {
    if (handlerRegistered) return true;
    if (!(window.Shiny && typeof Shiny.addCustomMessageHandler === "function")) {
      return false;
    }

    Shiny.addCustomMessageHandler("anesko_nav_history", function (msg) {
      if (!msg || !msg.tab || !VALID[msg.tab]) return;

      if (skipNextServerWrite) {
        skipNextServerWrite = false;
        lastWrittenTab = msg.tab;
        return;
      }

      var mode = msg.mode === "push" ? "push" : "replace";
      writeTab(msg.tab, mode);
    });

    Shiny.addCustomMessageHandler("anesko_show_tab", function (msg) {
      if (!msg || !msg.tab || !VALID[msg.tab]) return;
      showTab(msg.tab);
    });

    handlerRegistered = true;
    return true;
  }

  function doInit() {
    if (initDone) return;
    if (!(window.Shiny && typeof Shiny.setInputValue === "function")) return;
    initDone = true;
    registerHandlers();

    var tab = readTab();
    if (tab) {
      lastWrittenTab = tab;
      // Drop any leftover hash without adding history
      writeTab(tab, "replace");
      showTab(tab);
      notifyBrowserNav(tab, "init");
      setMainMenuInput(tab);
    } else {
      writeTab("dashboard", "replace");
      lastWrittenTab = "dashboard";
      notifyBrowserNav("dashboard", "init");
    }
  }

  window.addEventListener("popstate", function () {
    var tab = readTab() || "dashboard";
    lastWrittenTab = tab;
    showTab(tab);
    // Tell server only via browser_nav_tab (sets syncing_from_url, then
    // updateTabItems). Do NOT also set main_menu here — that races and can
    // push a new history entry before the guard is set.
    notifyBrowserNav(tab, "popstate");
  });

  function bindSidebarClicks() {
    document.addEventListener(
      "click",
      function (event) {
        var el = event.target;
        if (!el) return;

        var a = el.closest ? el.closest("a") : null;
        if (!a) {
          a = el;
          for (var i = 0; i < 5 && a; i++) {
            if (a.tagName && a.tagName.toLowerCase() === "a") break;
            a = a.parentElement;
          }
          if (!a || !a.tagName || a.tagName.toLowerCase() !== "a") return;
        }

        if (!isSidebarLink(a)) return;

        var tab = tabFromAnchor(a);
        if (!tab) return;

        // Critical: stop #shiny-tab-* hash history entries
        event.preventDefault();
        // Don't stopPropagation — some AdminLTE handlers may still need bubble
        // but preventDefault alone stops hash navigation.

        if (readTab() === tab && lastWrittenTab === tab) {
          showTab(tab);
          return;
        }

        var mode = lastWrittenTab || readTab() ? "push" : "replace";
        writeTab(tab, mode);
        showTab(tab);
        skipNextServerWrite = true;

        // Drive Shiny the same way a normal menu click would
        setMainMenuInput(tab);
      },
      true
    );
  }

  function bindShinyEvents() {
    bindSidebarClicks();
    registerHandlers();

    if (window.jQuery) {
      $(document).on("shiny:connected", doInit);
      $(document).on("shiny:sessioninitialized", doInit);
    }

    var tries = 0;
    var timer = setInterval(function () {
      tries += 1;
      registerHandlers();
      if (window.Shiny && Shiny.setInputValue) {
        var connected =
          Shiny.shinyapp &&
          typeof Shiny.shinyapp.isConnected === "function" &&
          Shiny.shinyapp.isConnected();
        if (connected || tries > 40) {
          doInit();
          clearInterval(timer);
        }
      } else if (tries > 50) {
        clearInterval(timer);
      }
    }, 100);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bindShinyEvents);
  } else {
    bindShinyEvents();
  }
})();
