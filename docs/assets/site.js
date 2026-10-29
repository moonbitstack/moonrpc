// Shared behaviour for the moonrpc documentation site.
(function () {
  "use strict";
  var root = document.documentElement;

  // --- theme: explicit toggle, persisted; default to the blueprint paper (light) ---
  function apply(theme) {
    root.setAttribute("data-theme", theme);
    try { localStorage.setItem("moonrpc-theme", theme); } catch (e) {}
  }
  var saved;
  try { saved = localStorage.getItem("moonrpc-theme"); } catch (e) {}
  apply(saved === "dark" ? "dark" : "light");

  document.addEventListener("click", function (e) {
    var t = e.target.closest("[data-theme-toggle]");
    if (!t) return;
    var cur = root.getAttribute("data-theme") === "dark" ? "dark" : "light";
    apply(cur === "dark" ? "light" : "dark");
  });

  // --- scrollbar: hide the thumb while parked at the top, show it once scrolling ---
  function syncTop() { root.classList.toggle("at-top", window.scrollY <= 0); }
  window.addEventListener("scroll", syncTop, { passive: true });
  syncTop();

  // --- copy-to-clipboard buttons ---
  document.addEventListener("click", function (e) {
    var b = e.target.closest("[data-copy]");
    if (!b) return;
    var text = b.getAttribute("data-copy");
    navigator.clipboard.writeText(text).then(function () {
      var prev = b.textContent;
      b.textContent = "copied";
      b.classList.add("ok");
      setTimeout(function () { b.textContent = prev; b.classList.remove("ok"); }, 1100);
    });
  });

  // --- API page: highlight the section in the sidebar as it scrolls past ---
  var spy = document.getElementById("section-spy");
  if (spy) {
    var links = Array.prototype.slice.call(spy.querySelectorAll("a"));
    var map = {};
    links.forEach(function (a) { map[a.getAttribute("href").slice(1)] = a; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) {
          links.forEach(function (a) { a.classList.remove("active"); });
          var a = map[en.target.id];
          if (a) a.classList.add("active");
        }
      });
    }, { rootMargin: "-12% 0px -82% 0px" });
    document.querySelectorAll("section.pkg").forEach(function (s) { io.observe(s); });
  }
})();
