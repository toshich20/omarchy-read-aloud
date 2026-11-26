import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "toshich20.read-aloud"
  ipcTarget: "toshich20.read-aloud"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  readonly property string statePath: runtimeDir + "/read-aloud/state.json"
  readonly property string ctlScript: localPath("bin/read-aloud-ctl")
  readonly property string readScript: localPath("bin/read-aloud")

  readonly property var ruVoices: ["ru-RU-DmitryNeural", "ru-RU-SvetlanaNeural"]
  readonly property var enVoices: ["en-US-AndrewNeural", "en-US-JennyNeural", "en-GB-SoniaNeural", "en-US-GuyNeural"]

  property string status: "idle"
  property int index: 0
  property int total: 0
  property int failed: 0
  property bool paused: false

  readonly property string ruVoice: selectVoice(root.ruVoices, "ruVoice")
  readonly property string enVoice: selectVoice(root.enVoices, "enVoice")
  readonly property bool active: root.status !== "idle"
  readonly property real progress: Math.min(1, Math.max(0, (root.index > 0 ? root.index : 1) / Math.max(1, root.total)))

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function localPath(relative) {
    return Qt.resolvedUrl(relative).toString().replace(/^file:\/\//, "")
  }

  function clampInt(value, maximum) {
    var number = Number(value)
    if (!isFinite(number) || number < 0) return 0
    return Math.min(maximum, Math.round(number))
  }

  function selectVoice(voices, key) {
    var configured = String(root.setting(key, voices[0]))
    return voices.indexOf(configured) >= 0 ? configured : voices[0]
  }

  function loadState(raw) {
    var parsed = null
    try {
      parsed = JSON.parse(raw)
    } catch (error) {
      parsed = null
    }
    if (!parsed || typeof parsed !== "object") {
      root.status = "idle"
      root.index = 0
      root.total = 0
      root.failed = 0
      return
    }
    var allowed = ["idle", "synthesizing", "playing"]
    var nextStatus = String(parsed.status || "idle")
    root.status = allowed.indexOf(nextStatus) >= 0 ? nextStatus : "idle"
    root.index = clampInt(parsed.index, 100000)
    root.total = clampInt(parsed.total, 100000)
    root.failed = clampInt(parsed.failed, 100000)
  }

  function statusText() {
    if (root.status === "synthesizing") return strings.t("synthesizing").arg(root.index).arg(root.total)
    if (root.status === "playing") return strings.t("playing").arg(Math.max(1, root.index)).arg(root.total)
    if (root.failed > 0) return strings.t("failed").arg(root.failed)
    return strings.t("idle")
  }

  function persistSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings)
      if (existing !== "id") entry[existing] = root.settings[existing]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function cycleVoice(key, voices) {
    var current = selectVoice(voices, key)
    root.persistSetting(key, voices[(voices.indexOf(current) + 1) % voices.length])
  }

  function ctl(action) {
    if (ctlProcess.running) return
    if (action === "toggle") root.paused = !root.paused
    if (action === "stop") root.paused = false
    ctlProcess.command = [root.ctlScript, action]
    ctlProcess.running = true
  }

  function readSelection() {
    root.paused = false
    Quickshell.execDetached([root.readScript])
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("{}")
    onFileChanged: reload()
  }

  Process {
    id: ctlProcess
    command: []
  }

  ShellIpc {
    target: root.ipcTarget
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function read() { root.readSelection() }
    function pause() { root.ctl("pause") }
    function resume() { root.ctl("resume") }
    function stop() { root.ctl("stop") }
    function status(): string {
      return JSON.stringify({
        status: root.status,
        index: root.index,
        total: root.total,
        failed: root.failed
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰸬"
    active: root.active
    tooltipText: root.statusText() + "\n" + strings.t("read")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.readSelection()
      else if (buttonCode === Qt.MiddleButton) root.ctl("stop")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(420))

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.ctl("toggle")
      onTextKey: function(key) {
        if (key === "p" || key === "P") root.ctl("toggle")
        else if (key === "s" || key === "S") root.ctl("stop")
        else if (key === "r" || key === "R") root.readSelection()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          id: hero
          width: parent.width
          title: strings.t("title")
          meta: root.statusText()
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Rectangle {
          width: parent.width
          height: Style.space(6)
          radius: height / 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

          Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: parent.radius
            color: root.accent
            visible: root.active
          }
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: root.paused ? strings.t("resume") : strings.t("pause")
            focusable: true
            enabled: root.active
            onClicked: root.ctl("toggle")
          }

          Button {
            text: strings.t("stop")
            focusable: true
            enabled: root.active
            onClicked: root.ctl("stop")
          }

          Button {
            text: strings.t("previous")
            focusable: true
            enabled: root.active
            onClicked: root.ctl("prev")
          }

          Button {
            text: strings.t("next")
            focusable: true
            enabled: root.active
            onClicked: root.ctl("next")
          }
        }

        Button {
          text: strings.t("read")
          focusable: true
          leftAlign: true
          onClicked: root.readSelection()
        }

        Button {
          text: strings.t("ruVoice") + ": " + root.ruVoice
          focusable: true
          leftAlign: true
          onClicked: root.cycleVoice("ruVoice", root.ruVoices)
        }

        Button {
          text: strings.t("enVoice") + ": " + root.enVoice
          focusable: true
          leftAlign: true
          onClicked: root.cycleVoice("enVoice", root.enVoices)
        }
      }
    }
  }
}
