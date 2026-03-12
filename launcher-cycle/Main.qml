import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
  readonly property var additionalModes: parseModeList(cfg?.additionalModes ?? defaults?.additionalModes ?? [])
  readonly property var excludedModes: parseModeList(cfg?.excludeModes ?? defaults?.excludeModes ?? [])

  readonly property var preferredBuiltInModes: ["file", "cmd", "win", "settings", "emoji", "clip"]

  function detectMode(searchText) {
    const text = searchText ?? "";
    const match = text.match(/^>(\S+)/);
    if (match && match[1])
      return match[1];
    return "";
  }

  function modeIndex(modeId, modes) {
    for (var i = 0; i < modes.length; i++) {
      if (modes[i] === modeId)
        return i;
    }
    return -1;
  }

  function normalizePrefix(prefix) {
    if (!prefix)
      return "";

    var normalized = ("" + prefix).trim();
    if (normalized.startsWith(">"))
      normalized = normalized.slice(1);
    if (!normalized)
      return "";
    if (/\s/.test(normalized))
      return "";
    return normalized;
  }

  function parseModeList(value) {
    if (value === undefined || value === null)
      return [];

    var items = [];
    if (Array.isArray(value)) {
      items = value;
    } else if (typeof value === "string") {
      items = value.split(",");
    } else {
      return [];
    }

    var seen = new Set();
    var result = [];
    for (var i = 0; i < items.length; i++) {
      var mode = normalizePrefix(items[i]);
      if (!mode || seen.has(mode))
        continue;
      seen.add(mode);
      result.push(mode);
    }
    return result;
  }

  function wrapIndex(index, count) {
    return (index % count + count) % count;
  }

  function getAvailableModes() {
    var result = [];
    var seen = {};

    function addMode(prefix) {
      var mode = normalizePrefix(prefix);
      if (!mode)
        return;
      if (seen[mode])
        return;
      seen[mode] = true;
      result.push(mode);
    }

    for (var i = 0; i < preferredBuiltInModes.length; i++) {
      addMode(preferredBuiltInModes[i]);
    }

    var pluginModes = [];
    var providerIds = LauncherProviderRegistry.getPluginProviders() ?? [];
    for (var j = 0; j < providerIds.length; j++) {
      var providerId = providerIds[j];
      var metadata = LauncherProviderRegistry.getProviderMetadata(providerId) ?? {};
      var pluginId = providerId.startsWith("plugin:") ? providerId.slice(7) : providerId;
      var prefix = metadata.commandPrefix;
      if (prefix === undefined || prefix === null || prefix === "")
        prefix = pluginId;
      prefix = normalizePrefix(prefix);
      if (prefix)
        pluginModes.push(prefix);
    }

    pluginModes.sort();
    for (var k = 0; k < pluginModes.length; k++) {
      addMode(pluginModes[k]);
    }

    for (var m = 0; m < additionalModes.length; m++) {
      addMode(additionalModes[m]);
    }

    if (excludedModes.length === 0)
      return result;

    var excluded = {};
    for (var n = 0; n < excludedModes.length; n++) {
      excluded[excludedModes[n]] = true;
    }

    return result.filter(function (mode) {
      return !excluded[mode];
    });
  }

  function cycle(step) {
    if (!pluginApi)
      return;

    pluginApi.withCurrentScreen(function (screen) {
      if (!screen)
        return;

      const isOpen = PanelService.isLauncherOpen(screen);
      const currentSearch = PanelService.getLauncherSearchText(screen) ?? "";
      const currentMode = detectMode(currentSearch);
      const modeOrder = getAvailableModes();
      const count = modeOrder.length;
      if (count === 0)
        return;

      var nextIndex = 0;
      if (isOpen) {
        const currentIndex = modeIndex(currentMode, modeOrder);
        if (currentIndex >= 0)
          nextIndex = wrapIndex(currentIndex + step, count);
      }

      const nextSearch = ">" + modeOrder[nextIndex] + " ";

      if (isOpen)
        PanelService.setLauncherSearchText(screen, nextSearch);
      else
        PanelService.openLauncherWithSearch(screen, nextSearch);
    });
  }

  IpcHandler {
    target: "plugin:launcher-cycle"

    function next() {
      root.cycle(1);
    }

    function previous() {
      root.cycle(-1);
    }
  }
}
