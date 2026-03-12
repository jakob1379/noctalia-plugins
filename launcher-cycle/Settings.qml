import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
  readonly property var additionalModesSetting: cfg?.additionalModes ?? defaults?.additionalModes ?? []
  readonly property var excludeModesSetting: cfg?.excludeModes ?? defaults?.excludeModes ?? []

  property string editAdditionalModesText: modeListToText(additionalModesSetting)
  property string editExcludeModesText: modeListToText(excludeModesSetting)

  spacing: Style.marginL

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

  function parseModeInput(value) {
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

  function modeListToText(value) {
    return parseModeInput(value).map(function (mode) {
      return ">" + mode;
    }).join(", ");
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Additional modes"
    description: "Extra top-level modes to append to cycling (comma-separated, e.g. >todo, >git)"
    placeholderText: ">todo, >calc"
    text: root.editAdditionalModesText
    onTextChanged: root.editAdditionalModesText = text
  }

  NDivider {
    Layout.fillWidth: true
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Exclude modes"
    description: "Top-level modes to remove from cycling (comma-separated, e.g. >cmd, >clip)"
    placeholderText: ">cmd, >clip"
    text: root.editExcludeModesText
    onTextChanged: root.editExcludeModesText = text
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("LauncherCycle", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.additionalModes = parseModeInput(root.editAdditionalModesText);
    pluginApi.pluginSettings.excludeModes = parseModeInput(root.editExcludeModesText);
    pluginApi.saveSettings();
  }
}
