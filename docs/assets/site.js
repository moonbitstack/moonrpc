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

  // --- scrollbar: shown while the page moves or the pointer is at the right
  // edge, hidden a moment after both stop ---
  var idle = 0, near = false;
  function hideSoon() { clearTimeout(idle); idle = setTimeout(function () { if (!near) root.classList.remove("scrolling"); }, 1200); }
  window.addEventListener("scroll", function () { root.classList.add("scrolling"); hideSoon(); }, { passive: true });
  window.addEventListener("pointermove", function (e) {
    var was = near;
    near = e.pointerType === "mouse" && e.clientX >= root.clientWidth - 24;
    if (near) root.classList.add("scrolling"); else if (was) hideSoon();
  }, { passive: true });
  root.addEventListener("pointerleave", function () { near = false; hideSoon(); });

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

  // --- engineering title block: one shared block, injected into every footer ---
  // Drawing-sheet metadata, the same on every page but for the sheet number. Kept
  // in one place so the generated API page and the hand-written pages never drift.
  (function titleBlock() {
    var foot = document.querySelector("footer .wrap");
    if (!foot || foot.querySelector(".titleblock")) return;
    var page = (location.pathname.split("/").pop() || "index.html").replace(/\.html?$/, "");
    var sheets = { index: "01", guide: "02", api: "03", showcase: "04" };
    var sheet = sheets[page] || "00";
    function cell(k, v) {
      return '<div class="cell"><span class="k">' + k + '</span><span class="v">' + v + '</span></div>';
    }
    var el = document.createElement("div");
    el.className = "titleblock";
    el.innerHTML =
      cell("drawing", "moonrpc") +
      cell("title", "A pure gRPC engine for MoonBit") +
      cell("org", "moonbitstack") +
      cell("sheet", sheet + " / 04") +
      cell("scale", "1:1") +
      cell("status", "current");
    foot.insertBefore(el, foot.firstChild);
  })();
})();
