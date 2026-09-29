"use strict";

/* Lonestar - DUI renderer.
   Pure presentation: Lua owns the cursor, the input buffer and every
   widget interaction, then pushes state down with these messages. */

var state = {
  brand: "Lonestar",
  version: "",
  title: "Lonestar",
  accent: "#ff0000",
  tabs: [],
  keybinds: [],
  tabId: 0,
  groupId: 0,
  index: 0,
  mode: "groups",
  ddIndex: 0
};

var el = {
  menu:    document.getElementById("menu"),
  brand:   document.getElementById("brand"),
  version: document.getElementById("version"),
  tabs:    document.getElementById("tabs"),
  list:    document.getElementById("list"),
  crumb:   document.getElementById("crumb"),
  hint:    document.getElementById("hint"),
  menuKey: document.getElementById("menuKey"),
  dd:      document.getElementById("dropdown"),
  ddList:  document.getElementById("dropdownList"),
  kb:      document.getElementById("keyboard"),
  kbTitle: document.getElementById("kbTitle"),
  kbValue: document.getElementById("kbValue"),
  toasts:  document.getElementById("toasts")
};

function setAccent(hex) {
  if (typeof hex !== "string" || !/^#[0-9a-f]{6}$/i.test(hex)) return;
  state.accent = hex;
  document.documentElement.style.setProperty("--accent", hex);
}

function findTab(id) {
  for (var i = 0; i < state.tabs.length; i++) {
    if (state.tabs[i].id === id) return state.tabs[i];
  }
  return null;
}

function findGroup(tabId, groupId) {
  var tab = findTab(tabId);
  if (!tab || !tab.groups) return null;
  for (var i = 0; i < tab.groups.length; i++) {
    if (tab.groups[i].id === groupId) return tab.groups[i];
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

/* ---------------- rendering ---------------- */

function renderTabs() {
  el.tabs.innerHTML = "";
  for (var i = 0; i < state.tabs.length; i++) {
    var tab = state.tabs[i];
    var node = document.createElement("div");
    node.className = "tab" + (tab.id === state.tabId ? " active" : "");
    node.textContent = tab.label;
    (function (id) {
      node.addEventListener("click", function () {
        /* Presentation only - Lua keeps the cursor. Clicking a tab is
           a visual affordance; navigation stays keyboard driven. */
        var t = findTab(id);
        if (t && t.groups && t.groups.length) {
          el.list.scrollTop = 0;
        }
      });
    })(tab.id);
    el.tabs.appendChild(node);
  }
}

function textNode(item, selected) {
  var row = document.createElement("li");
  row.className = "row";

  if (item.type === "text" && /:\s*$/.test(item.label || "")) row.className += " heading";
  if (item.type === "smalltext") row.className += " smalltext";
  if (item.centered) row.className += " centered";
  if (selected) row.className += " sel";

  var label = document.createElement("span");
  label.className = "label";
  label.textContent = item.label || "";
  row.appendChild(label);
  return row;
}

function checkboxNode(item, selected) {
  var row = document.createElement("li");
  row.className = "row" + (selected ? " sel" : "") + (item.checked ? " on" : "");

  var box = document.createElement("span");
  box.className = "box";
  row.appendChild(box);

  var label = document.createElement("span");
  label.className = "label";
  label.textContent = item.label || "";
  row.appendChild(label);

  return row;
}

function sliderNode(item, selected) {
  var row = document.createElement("li");
  row.className = "row" + (selected ? " sel" : "");

  var label = document.createElement("span");
  label.className = "label";
  label.textContent = item.label || "";
  row.appendChild(label);

  var track = document.createElement("span");
  track.className = "track";
  var fill = document.createElement("span");
  fill.className = "fill";
  var min = item.min || 0;
  var max = item.max || 100;
  var pct = max > min ? ((item.value - min) / (max - min)) * 100 : 0;
  fill.style.width = Math.max(0, Math.min(100, pct)) + "%";
  track.appendChild(fill);
  row.appendChild(track);

  var val = document.createElement("span");
  val.className = "val";
  val.innerHTML = "<strong>" + item.value + "</strong>" + (item.suffix || "");
  row.appendChild(val);

  return row;
}

function valueNode(item, selected, text, empty) {
  var row = document.createElement("li");
  row.className = "row" + (selected ? " sel" : "");

  var label = document.createElement("span");
  label.className = "label";
  label.textContent = item.label || "";
  row.appendChild(label);

  var val = document.createElement("span");
  val.className = "val";
  val.innerHTML = "<strong>" + (text || "") + "</strong>";
  row.appendChild(val);

  return row;
}

function dropdownNode(item, selected) {
  var options = item.options || [];
  var text = options[item.value - 1] !== undefined ? options[item.value - 1] : "-";
  return valueNode(item, selected, String(text), false);
}

function inputNode(item, selected) {
  var row = document.createElement("li");
  row.className = "row" + (selected ? " sel" : "");

  var label = document.createElement("span");
  label.className = "label";
  label.textContent = item.label || "";
  row.appendChild(label);

  var val = document.createElement("span");
  var has = item.value !== undefined && item.value !== null && item.value !== "";
  val.className = "input-val" + (has ? "" : " empty");
  val.textContent = has ? item.value : (item.placeholder || "");
  row.appendChild(val);

  return row;
}

function keybindNode(item, selected) {
  var row = document.createElement("li");
  row.className = "row" + (selected ? " sel" : "");

  var label = document.createElement("span");
  label.className = "label";
  label.textContent = item.label || "";
  row.appendChild(label);

  var val = document.createElement("span");
  val.className = "kb-val";
  val.textContent = item.value || "unbound";
  row.appendChild(val);

  return row;
}

function buildRow(item, selected) {
  switch (item.type) {
    case "checkbox": return checkboxNode(item, selected);
    case "slider":   return sliderNode(item, selected);
    case "dropdown": return dropdownNode(item, selected);
    case "input":    return inputNode(item, selected);
    case "keybind":  return keybindNode(item, selected);
    default:         return textNode(item, selected);
  }
}

function renderGroups(tab) {
  state.mode = "groups";
  el.crumb.textContent = state.title;
  el.hint.textContent = "select a group";

  el.list.innerHTML = "";
  var groups = (tab && tab.groups) || [];
  for (var i = 0; i < groups.length; i++) {
    var row = document.createElement("li");
    row.className = "row" + (i === state.index ? " sel" : "");
    var label = document.createElement("span");
    label.className = "label";
    label.textContent = groups[i].label;
    row.appendChild(label);
    var count = (groups[i].items || []).length;
    var val = document.createElement("span");
    val.className = "val";
    val.textContent = count ? count + " items" : "";
    row.appendChild(val);
    el.list.appendChild(row);
  }
}

function renderItems(group) {
  state.mode = "items";
  var tab = findTab(state.tabId);
  var tabLabel = tab ? tab.label : "";
  el.crumb.textContent = (group ? group.label : "") + "  /  " + tabLabel;
  el.hint.textContent = "backspace to go back";

  el.list.innerHTML = "";
  var items = (group && group.items) || [];
  for (var i = 0; i < items.length; i++) {
    el.list.appendChild(buildRow(items[i], i === state.index));
  }
  scrollSelected();
}

function scrollSelected() {
  var sel = el.list.querySelector(".sel");
  if (!sel) return;
  var top = sel.offsetTop - el.list.clientHeight / 2 + sel.offsetHeight / 2;
  el.list.scrollTop = Math.max(0, top);
}

function render() {
  renderTabs();
  if (state.mode === "items") {
    renderItems(findGroup(state.tabId, state.groupId));
  } else {
    renderGroups(findTab(state.tabId));
  }
}

/* ---------------- dropdown overlay ---------------- */

function openDropdown(data) {
  el.ddList.innerHTML = "";
  var options = data.options || [];
  for (var i = 0; i < options.length; i++) {
    var li = document.createElement("li");
    if (i === (data.value || 1) - 1) li.className = "sel";
    var name = document.createElement("span");
    name.textContent = options[i];
    li.appendChild(name);
    if (i === (data.value || 1) - 1) {
      var tick = document.createElement("span");
      tick.className = "tick";
      tick.textContent = "✓";
      li.appendChild(tick);
    }
    (function (idx) {
      li.addEventListener("click", function () {
        /* Visual only; Lua confirms with the arrow keys. */
        for (var j = 0; j < el.ddList.children.length; j++) {
          el.ddList.children[j].className = j === idx ? "sel" : "";
        }
        state.ddIndex = idx;
      });
    })(i);
    el.ddList.appendChild(li);
  }
  el.dd.classList.remove("hidden");
}

function closeDropdown() {
  el.dd.classList.add("hidden");
}

/* ---------------- toasts ---------------- */

function toast(data) {
  var node = document.createElement("div");
  node.className = "toast " + (data.kind === "ok" ? "ok" : data.kind === "err" ? "err" : "");

  var t = document.createElement("div");
  t.className = "t";
  t.textContent = data.title || "";
  node.appendChild(t);

  var m = document.createElement("div");
  m.className = "m";
  m.textContent = data.message || "";
  node.appendChild(m);

  el.toasts.appendChild(node);

  var life = typeof data.time === "number" && data.time > 0 ? data.time : 4000;
  setTimeout(function () {
    node.className += " out";
    setTimeout(function () { if (node.parentNode) node.parentNode.removeChild(node); }, 300);
  }, life);
}

/* ---------------- messages from Lua ---------------- */

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
      var parts = String(state.brand).split(" ");
      el.brand.textContent = parts[0] || "Lonestar";
      el.version.textContent = parts.slice(1).join(" ") || "";
      setAccent(data.accent);
      el.menu.classList.remove("hidden");
      break;

    case "show":
      el.menu.classList.remove("hidden");
      break;

    case "hide":
      el.menu.classList.add("hidden");
      closeDropdown();
      el.kb.classList.add("hidden");
      break;

    case "view":
      state.tabId = data.tab || 0;
      state.index = typeof data.index === "number" ? data.index : 0;
      if (data.items) {
        state.groupId = data.group || 0;
        renderItems(findGroup(state.tabId, state.groupId));
      } else {
        state.groupId = 0;
        renderGroups(findTab(state.tabId));
      }
      renderTabs();
      if (state.mode === "items") scrollSelected();
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
      el.menuKey.textContent = data.value || "INSERT";
      break;

    case "notify":
      toast(data);
      break;

    case "keyboard":
      if (data.visible) {
        el.kbTitle.textContent = data.title || "Input";
        el.kbValue.textContent = data.value || "";
        el.kbValue.className = "kb-value" + (data.hint ? " hint" : "");
        el.kb.classList.remove("hidden");
      } else {
        el.kb.classList.add("hidden");
      }
      break;

    case "dropdown":
      if (data.visible) openDropdown(data); else closeDropdown();
      break;
  }
}

window.addEventListener("message", function (event) {
  handle(event.data);
});

/* Fallback for a plain browser preview. */
if (typeof window.GetParentResourceName === "function") {
  /* FiveM NUI: nothing further needed, messages arrive on window. */
}

window.LS_DEBUG = { state: state, handle: handle };
