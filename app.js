"use strict";

/* Lonestar - DUI renderer, matching the Allstar layout.
   Pure presentation: Lua owns the cursor, the input buffer and every widget
   interaction, then pushes state down with these messages. */

var state = {
  brand: "Lonestar", version: "1.0", title: "Lonestar", status: "",
  accent: "242, 109, 220",
  tabs: [], keybinds: [],
  tabIndex: 0, groupId: 0, index: 0,
  mode: "groups"
};

var el = {
  menu:       document.getElementById("menu"),
  categories: document.getElementById("categories"),
  highlight:  document.getElementById("highlight"),
  list:       document.getElementById("list"),
  vscroll:    document.getElementById("vscroll"),
  desc:       document.getElementById("desc"),
  descText:   document.getElementById("descText"),
  bannerName: document.getElementById("bannerName"),
  bannerVer:  document.getElementById("bannerVer"),
  footerBrand: document.getElementById("footerBrand"),
  footerName: document.getElementById("footerName"),
  footerStatus: document.getElementById("footerStatus"),
  keyboard:   document.getElementById("keyboard"),
  kbTitle:    document.getElementById("kbTitle"),
  kbValue:    document.getElementById("kbValue"),
  keybinds:   document.getElementById("keybinds"),
  kbList:     document.getElementById("kbList"),
  dd:         document.getElementById("dropdown"),
  ddList:     document.getElementById("dropdownList"),
  toasts:     document.getElementById("toasts")
};

/* Accepts either "r, g, b" or "#rrggbb" so the Lua side can send either. */
function setAccent(value) {
  if (typeof value !== "string") return;
  var rgb = null;
  var m = value.match(/(\d{1,3})\D+(\d{1,3})\D+(\d{1,3})/);
  if (m) {
    rgb = m[1] + ", " + m[2] + ", " + m[3];
  } else {
    var h = value.match(/^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
    if (!h) return;
    rgb = parseInt(h[1], 16) + ", " + parseInt(h[2], 16) + ", " + parseInt(h[3], 16);
  }
  state.accent = rgb;
  document.documentElement.style.setProperty("--menu-color", rgb);
}

function findTab(i) {
  for (var k = 0; k < state.tabs.length; k++) {
    if (state.tabs[k].id === i) return state.tabs[k];
  }
  return null;
}

function findGroup(tabId, groupId) {
  var tab = findTab(tabId);
  if (!tab || !tab.groups) return null;
  for (var k = 0; k < tab.groups.length; k++) {
    if (tab.groups[k].id === groupId) return tab.groups[k];
  }
  return null;
}

function itemById(id) {
  for (var t = 0; t < state.tabs.length; t++) {
    var groups = state.tabs[t].groups || [];
    for (var g = 0; g < groups.length; g++) {
      var items = groups[g].items || [];
      for (var i = 0; i < items.length; i++) {
        if (items[i].id === id) return items[i];
      }
    }
  }
  return null;
}

/* ---------------- category bar ---------------- */

function renderCategories() {
  if (!el.categories) return;
  var keep = el.categories.querySelectorAll(".PCategory");
  for (var k = 0; k < keep.length; k++) keep[k].remove();

  for (var i = 0; i < state.tabs.length; i++) {
    (function (i) {
      var c = document.createElement("div");
      c.className = "PCategory" + (i === state.tabIndex ? " active" : "");
      c.textContent = state.tabs[i].label;
      c.addEventListener("click", function () { el.list.scrollTop = 0; });
      el.categories.appendChild(c);
    })(i);
  }
  moveHighlight();
}

/* The original slides a full-width pill with transform; here each category
   gets an equal slice and the pill translates to the active one. */
function moveHighlight() {
  if (!el.highlight || !state.tabs.length) return;
  var pct = 100 / state.tabs.length;
  el.highlight.style.width = pct + "%";
  el.highlight.style.transform = "translateX(" + (state.tabIndex * 100) + "%)";
}

/* ---------------- rows ---------------- */

function rowShell(item, selected) {
  var row = document.createElement("li");
  row.className = "VTab" + (selected ? " Selected" : "");
  if (item.type === "text" && /:\s*$/.test(item.label || "")) row.className += " heading";
  if (item.type === "smalltext") row.className += " smalltext";
  if (item.centered) row.className += " centered";
  return row;
}

function labelNode(item) {
  var l = document.createElement("span");
  l.className = "VTLabel";
  l.textContent = item.label || "";
  return l;
}

function optionsNode() {
  var o = document.createElement("span");
  o.className = "VOptions";
  return o;
}

function valNode(text) {
  var v = document.createElement("span");
  v.className = "Val";
  v.innerHTML = "<b>" + (text === undefined || text === null ? "" : String(text)) + "</b>";
  return v;
}

function checkboxNode(item) {
  var box = document.createElement("span");
  box.className = "Checkbox" + (item.checked ? " on" : "");
  var knob = document.createElement("i");
  box.appendChild(knob);
  return box;
}

function sliderNode(item) {
  var wrap = document.createElement("span");
  wrap.className = "Slider";
  var min = item.min || 0, max = item.max || 100;
  var pct = max > min ? (item.value - min) / (max - min) : 0;
  if (pct < 0) pct = 0; if (pct > 1) pct = 1;

  var fill = document.createElement("span");
  fill.className = "BarFill";
  fill.style.width = (pct * 100) + "%";
  wrap.appendChild(fill);

  var thumb = document.createElement("i");
  thumb.style.left = (pct * 100) + "%";
  wrap.appendChild(thumb);
  return wrap;
}

function inputNode(item) {
  var has = item.value !== undefined && item.value !== null && item.value !== "";
  var v = document.createElement("span");
  v.className = "InputVal" + (has ? "" : " empty");
  v.textContent = has ? item.value : (item.placeholder || "");
  return v;
}

function keybindNode(item) {
  var v = document.createElement("span");
  v.className = "KeyVal";
  v.textContent = item.value || "unbound";
  return v;
}

function buildRow(item, selected) {
  var row = rowShell(item, selected);
  row.appendChild(labelNode(item));

  if (item.type === "button" || item.type === "text" || item.type === "smalltext") {
    return row;
  }

  var o = optionsNode();
  if (item.type === "checkbox") {
    o.appendChild(checkboxNode(item));
  } else if (item.type === "slider") {
    o.appendChild(valNode(item.value + (item.suffix || "")));
    o.appendChild(sliderNode(item));
  } else if (item.type === "dropdown") {
    var opts = item.options || [];
    o.appendChild(valNode(opts[item.value - 1] !== undefined ? opts[item.value - 1] : "-"));
  } else if (item.type === "input") {
    o.appendChild(inputNode(item));
  } else if (item.type === "keybind") {
    o.appendChild(keybindNode(item));
  }
  row.appendChild(o);
  return row;
}

function buildGroupRow(group, selected) {
  var row = document.createElement("li");
  row.className = "VTab" + (selected ? " Selected" : "");
  var l = document.createElement("span");
  l.className = "VTLabel";
  l.textContent = group.label;
  row.appendChild(l);
  var o = optionsNode();
  var count = (group.items || []).length;
  if (count) o.appendChild(valNode(count));
  row.appendChild(o);
  return row;
}

/* ---------------- scroll indicator ---------------- */

function renderScroll(items, index) {
  if (!el.vscroll) return;
  el.vscroll.innerHTML = "";
  if (!items || !items.length) return;

  var total = items.length;
  var visible = Math.max(1, Math.floor(el.list.clientHeight / (el.list.scrollHeight || 1) * total) || total);
  var pct = Math.max(0.08, Math.min(1, visible / total));
  var barH = pct * 100;
  var maxScroll = el.list.scrollHeight - el.list.clientHeight;
  var pos = maxScroll > 0 ? (el.list.scrollTop / maxScroll) * (100 - barH) : 0;

  var bar = document.createElement("i");
  bar.className = "on";
  bar.style.height = barH + "%";
  bar.style.marginTop = pos + "%";
  el.vscroll.appendChild(bar);
}

function scrollSelected() {
  var sel = el.list.querySelector(".Selected");
  if (!sel) return;
  var top = sel.offsetTop - el.list.clientHeight / 2 + sel.offsetHeight / 2;
  el.list.scrollTop = Math.max(0, top);
}

/* ---------------- render ---------------- */

function renderGroups(tab) {
  state.mode = "groups";
  el.footerName.textContent = tab ? tab.label : state.title;
  el.desc.classList.add("hidden");

  var groups = (tab && tab.groups) || [];
  el.list.innerHTML = "";
  for (var i = 0; i < groups.length; i++) {
    el.list.appendChild(buildGroupRow(groups[i], i === state.index));
  }
  renderScroll(groups, state.index);
}

function renderItems(group) {
  state.mode = "items";
  var tab = findTab(state.tabId);
  el.footerName.textContent = (group ? group.label : "") + (tab ? " / " + tab.label : "");

  if (el.desc && el.descText) {
    el.descText.textContent = "BACKSPACE - back   |   ENTER - select   |   LEFT / RIGHT - adjust";
    el.desc.classList.remove("hidden");
  }

  var items = (group && group.items) || [];
  el.list.innerHTML = "";
  for (var i = 0; i < items.length; i++) {
    el.list.appendChild(buildRow(items[i], i === state.index));
  }
  scrollSelected();
  renderScroll(items, state.index);
}

function render() {
  renderCategories();
  if (state.mode === "items") {
    renderItems(findGroup(state.tabId, state.groupId));
  } else {
    renderGroups(findTab(state.tabId));
  }
}

/* ---------------- dropdown ---------------- */

function openDropdown(data) {
  el.ddList.innerHTML = "";
  var options = data.options || [];
  var cur = (data.value || 1) - 1;
  for (var i = 0; i < options.length; i++) {
    (function (i) {
      var li = document.createElement("li");
      if (i === cur) li.className = "sel";
      var name = document.createElement("span");
      name.textContent = options[i];
      li.appendChild(name);
      if (i === cur) {
        var tick = document.createElement("span");
        tick.className = "tick";
        tick.textContent = "✔";
        li.appendChild(tick);
      }
      li.addEventListener("click", function () {
        var kids = el.ddList.children;
        for (var j = 0; j < kids.length; j++) kids[j].className = j === i ? "sel" : "";
      });
      el.ddList.appendChild(li);
    })(i);
  }
  el.dd.classList.remove("hidden");
}

function closeDropdown() { el.dd.classList.add("hidden"); }

/* ---------------- notifications ---------------- */

function toast(data) {
  var node = document.createElement("div");
  node.className = "Notification " + (data.kind === "ok" ? "ok" : data.kind === "err" ? "err" : "");

  var t = document.createElement("div");
  t.className = "NotificationTitle";
  t.textContent = data.title || "";
  node.appendChild(t);

  var m = document.createElement("div");
  m.className = "NotificationDesc";
  m.textContent = data.message || "";
  node.appendChild(m);

  var bar = document.createElement("div");
  bar.className = "NotificationProgress";
  node.appendChild(bar);

  el.toasts.appendChild(node);

  var life = (typeof data.time === "number" && data.time > 0) ? data.time : 4000;

  /* A DUI surface can be occluded, and an occluded CEF surface may never run
     requestAnimationFrame. Fall back to a timer so the toast cannot be
     stranded at opacity 0. */
  requestAnimationFrame(function () { node.classList.add("in"); });
  setTimeout(function () { node.classList.add("in"); }, 60);

  if (bar.animate) {
    bar.animate(
      [{ transform: "scaleX(1)" }, { transform: "scaleX(0)" }],
      { duration: life, easing: "linear", fill: "forwards" }
    );
  } else {
    bar.style.transition = "transform " + life + "ms linear";
    bar.style.transform = "scaleX(0)";
  }

  setTimeout(function () {
    node.classList.remove("in");
    setTimeout(function () { if (node.parentNode) node.parentNode.removeChild(node); }, 450);
  }, life);
}

/* ---------------- keybinds ---------------- */

function renderKeybinds(list) {
  if (!el.kbList) return;
  el.kbList.innerHTML = "";

  var rows = [];
  if (state.menuKey) rows.push({ value: state.menuKey, label: "Menu" });
  for (var i = 0; i < (list || []).length; i++) {
    if (list[i] && list[i].value) rows.push(list[i]);
  }

  if (!rows.length) { el.keybinds.classList.add("hidden"); return; }
  for (var r = 0; r < rows.length; r++) {
    var row = document.createElement("div");
    row.className = "Keybind";
    var b = document.createElement("b");
    b.textContent = rows[r].value || "-";
    var s = document.createElement("span");
    s.textContent = rows[r].label || "";
    row.appendChild(b);
    row.appendChild(s);
    el.kbList.appendChild(row);
  }
  el.keybinds.classList.remove("hidden");
}

/* ---------------- messages ---------------- */

function handle(data) {
  if (typeof data === "string") {
    try { data = JSON.parse(data); } catch (e) { return; }
  }
  if (!data || typeof data !== "object") return;

  switch (data.action) {
    case "init":
      state.brand = data.brand || "Lonestar";
      state.title = data.title || "Lonestar";
      state.tabs = data.tabs || [];
      state.keybinds = data.keybinds || [];

      el.bannerName.textContent = String(state.brand).toUpperCase();
      el.bannerVer.textContent = "v" + (data.version || "1.0");
      el.footerBrand.textContent = String(state.brand).slice(0, 2).toUpperCase();
      el.footerName.textContent = state.brand;
      el.footerStatus.textContent = data.status || "";

      setAccent(data.accent);
      renderKeybinds(state.keybinds);
      if (data.visible === false) el.menu.classList.add("hidden");
      else el.menu.classList.remove("hidden");
      render();
      break;

    case "show":
      el.menu.classList.remove("hidden");
      render();
      break;

    case "hide":
      el.menu.classList.add("hidden");
      closeDropdown();
      el.keyboard.classList.add("hidden");
      el.desc.classList.add("hidden");
      break;

    case "view":
      if (data.items) {
        state.mode = "items";
        state.groupId = data.group || 0;
      } else {
        state.mode = "groups";
        state.groupId = 0;
      }
      state.tabId = data.tab || 0;
      state.index = typeof data.index === "number" ? data.index : 0;

      /* tabs arrive as ids; the bar works on position */
      for (var i = 0; i < state.tabs.length; i++) {
        if (state.tabs[i].id === state.tabId) { state.tabIndex = i; break; }
      }
      render();
      break;

    case "text": {
      var t = itemById(data.id);
      if (t) { t.label = data.label; render(); }
      break;
    }

    case "widget": {
      var w = itemById(data.id);
      if (!w) break;
      if (data.type === "checkbox") w.checked = !!data.checked;
      else if (data.type === "slider") { w.value = data.value; if (data.label) w.label = data.label; }
      else if (data.type === "dropdown") { w.value = data.value; if (data.options) w.options = data.options; }
      else if (data.type === "input") w.value = data.value;
      else if (data.type === "keybind") w.value = data.value;
      render();
      break;
    }

    case "accent":
      setAccent(data.accent);
      break;

    case "menuKey":
      state.menuKey = data.value || "INSERT";
      renderKeybinds(state.keybinds);
      break;

    case "notify":
      toast(data);
      break;

    case "keyboard":
      if (data.visible) {
        el.kbTitle.textContent = data.title || "Input";
        el.kbValue.textContent = data.value || "";
        el.kbValue.className = "PromptValue" + (data.hint ? " hint" : "");
        el.keyboard.classList.remove("hidden");
      } else {
        el.keyboard.classList.add("hidden");
      }
      break;

    case "dropdown":
      if (data.visible) openDropdown(data); else closeDropdown();
      break;
  }
}

window.addEventListener("message", function (event) { handle(event.data); });
window.addEventListener("resize", function () { render(); });

window.LS_DEBUG = { state: state, handle: handle };
