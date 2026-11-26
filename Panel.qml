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
  readonly property string ctlScript: localPath("bin/read-aloud-ctl")
  readonly property string saveScript: localPath("bin/read-aloud-save")
  readonly property string readScript: localPath("bin/read-aloud")
  readonly property string backIcon: localPath("icons/back5.png")
  readonly property string forwardIcon: localPath("icons/forward5.png")

  readonly property var ruVoices: ["v5_ru:aidar", "v5_ru:baya", "v5_ru:kseniya", "v5_ru:eugene", "v5_ru:xenia"]
  readonly property var enVoices: ["v3_en:en_0", "v3_en:en_1", "v3_en:en_2", "v3_en:en_3", "v3_en:en_4", "v3_en:en_5", "v3_en:en_6", "v3_en:en_7", "v3_en:en_8", "v3_en:en_9", "v3_en:en_10", "v3_en:en_11"]
  readonly property var speeds: [1, 1.5, 2]

  property string status: "idle"
  property int index: 0
  property int total: 0
  property int failed: 0
  property int prepared: 0
  property int percent: 0
  property int eta: 0
  property real position: 0
  property real elapsed: 0
  property real duration: 0
  property real chunkPosition: 0
  property real chunkDuration: 0
  property real speed: 1
  property bool paused: false
  property bool downloadable: false

  readonly property string ruVoice: selectVoice(root.ruVoices, "ruVoice")
  readonly property string enVoice: selectVoice(root.enVoices, "enVoice")
  readonly property bool active: root.status !== "idle"
  readonly property bool chunkMode: root.status === "playing" && root.prepared < root.total

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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

  function numberOr(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
  }

  function selectVoice(voices, key) {
    var configured = String(root.setting(key, voices[0]))
    return voices.indexOf(configured) >= 0 ? configured : voices[0]
  }

  function selectSpeed() {
    var configured = String(root.setting("speed", "1x")).replace(/[xX]$/, "")
    var number = Number(configured)
    return root.speeds.indexOf(number) >= 0 ? number : 1
  }

  function speedLabel(value) {
    return String(value) + "x"
  }

  function voiceLabel(value) {
    var parts = String(value).split(":")
    return parts.length > 1 ? parts[1] : value
  }

  function resetState() {
    root.status = "idle"
    root.index = 0
    root.total = 0
    root.failed = 0
    root.prepared = 0
    root.percent = 0
    root.eta = 0
    root.position = 0
    root.elapsed = 0
    root.duration = 0
    root.chunkPosition = 0
    root.chunkDuration = 0
    root.paused = false
    root.downloadable = false
  }

  function loadState(raw) {
    var parsed = null
    try {
      parsed = JSON.parse(raw)
    } catch (error) {
      parsed = null
    }
    if (!parsed || typeof parsed !== "object") {
      root.resetState()
      return
    }
    var allowed = ["idle", "synthesizing", "playing", "ready"]
    var nextStatus = String(parsed.status || "idle")
    root.status = allowed.indexOf(nextStatus) >= 0 ? nextStatus : "idle"
    root.index = clampInt(parsed.index, 100000)
    root.total = clampInt(parsed.total, 100000)
    root.failed = clampInt(parsed.failed, 100000)
    root.prepared = clampInt(parsed.prepared, 100000)
    root.percent = clampInt(parsed.percent, 100)
    root.eta = clampInt(parsed.eta, 86400)
    root.position = Math.max(0, numberOr(parsed.position, 0))
    root.elapsed = Math.max(0, numberOr(parsed.elapsed, 0))
    root.duration = Math.max(0, numberOr(parsed.duration, 0))
    root.chunkPosition = Math.max(0, numberOr(parsed.chunkPosition, 0))
    root.chunkDuration = Math.max(0, numberOr(parsed.chunkDuration, 0))
    root.paused = parsed.paused === true
    root.downloadable = root.status === "ready"
  }

  function formatTime(value) {
    var seconds = Math.max(0, Math.floor(numberOr(value, 0)))
    var minutes = Math.floor(seconds / 60)
    var rest = seconds % 60
    return minutes + ":" + (rest < 10 ? "0" : "") + rest
  }

  function progressValue() {
    if (root.status === "synthesizing") return root.percent
    if (root.chunkMode) return Math.min(root.chunkDuration > 0 ? root.chunkPosition : 0, root.chunkDuration > 0 ? root.chunkDuration : 1)
    return root.duration > 0 ? root.elapsed : 0
  }

  function progressMaximum() {
    if (root.status === "synthesizing") return 100
    if (root.chunkMode) return Math.max(1, root.chunkDuration)
    return Math.max(1, root.duration)
  }

  function timeText() {
    if (root.chunkMode) return root.formatTime(root.chunkPosition) + " / " + root.formatTime(root.chunkDuration)
    return root.duration > 0 ? root.formatTime(root.elapsed) + " / " + root.formatTime(root.duration) : ""
  }

  function statusText() {
    if (root.status === "synthesizing")
      return strings.t("synthesizing").arg(Math.max(1, root.index)).arg(root.total)
        .arg(Commons.I18n.formatNumber(root.percent)).arg(Commons.I18n.formatNumber(root.eta))
    if (root.status === "playing") {
      if (root.prepared < root.total)
        return strings.t("playingPreparing").arg(Math.max(1, root.index)).arg(root.total)
          .arg(Commons.I18n.formatNumber(root.percent)).arg(Commons.I18n.formatNumber(root.eta))
      return strings.t("playing").arg(Math.max(1, root.index)).arg(root.total)
    }
    if (root.status === "ready") return strings.t("ready")
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

  function seek(value) {
    if (root.status !== "playing" || seekProcess.running) return
    var action = root.chunkMode ? "seek-chunk" : "seek"
    seekProcess.command = [root.ctlScript, action, String(Math.max(0, value))]
    seekProcess.running = true
  }

  function skip(seconds) {
    if (root.status !== "playing" || skipProcess.running) return
    skipProcess.command = [root.ctlScript, "skip", String(seconds)]
    skipProcess.running = true
  }

  function setSpeed(value) {
    var number = Number(value)
    if (root.speeds.indexOf(number) < 0) return
    root.speed = number
    root.persistSetting("speed", root.speedLabel(number))
    speedProcess.command = [root.ctlScript, "speed", String(number)]
    speedProcess.running = true
  }

  function cycleSpeed() {
    var index = root.speeds.indexOf(root.speed)
    root.setSpeed(root.speeds[(index + 1) % root.speeds.length])
  }

  function save() {
    if (!root.downloadable || saveProcess.running) return
    saveProcess.running = true
  }

  function readSelection() {
    root.paused = false
    Quickshell.execDetached([root.readScript])
  }

  Process {
    id: statusProcess
    command: [root.ctlScript, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadState(text)
    }
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: if (!statusProcess.running) statusProcess.running = true
  }

  Component.onCompleted: {
    root.speed = root.selectSpeed()
    statusProcess.running = true
  }

  Process {
    id: ctlProcess
    command: []
  }

  Process {
    id: seekProcess
    command: []
  }

  Process {
    id: skipProcess
    command: []
  }

  Process {
    id: speedProcess
    command: []
  }

  Process {
    id: saveProcess
    command: [root.saveScript]
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
    function setSpeed(value: string) { root.setSpeed(Number(value)) }
    function status(): string {
      return JSON.stringify({
        status: root.status,
        index: root.index,
        total: root.total,
        failed: root.failed,
        prepared: root.prepared,
        percent: root.percent,
        eta: root.eta,
        elapsed: root.elapsed,
        duration: root.duration,
        chunkPosition: root.chunkPosition,
        chunkDuration: root.chunkDuration,
        speed: root.speed,
        generating: root.chunkMode,
        downloadable: root.downloadable
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
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(480))

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
        else if (key === "d" || key === "D") root.save()
        else if (key === "v" || key === "V") root.cycleSpeed()
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

        Row {
          width: parent.width
          spacing: Style.space(8)

          PanelSlider {
            id: seekBar
            bar: root.bar
            width: parent.width - timeText.implicitWidth - parent.spacing
            minimum: 0
            maximum: root.progressMaximum()
            step: 1
            value: root.progressValue()
            enabled: root.status === "playing" && (root.chunkMode ? root.chunkDuration > 0 : root.duration > 0)
            onReleased: function(value) { root.seek(value) }
          }

          Text {
            id: timeText
            text: root.timeText()
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Row {
          spacing: Style.space(8)

          Button {
            id: playPauseButton
            iconText: root.paused ? "\uf04b" : "\uf04c"
            tooltipText: root.paused ? strings.t("resume") : strings.t("pause")
            bordered: true
            focusable: true
            enabled: root.active
            onClicked: root.ctl("toggle")
          }

          Button {
            iconText: "\uf04d"
            tooltipText: strings.t("stop")
            bordered: true
            focusable: true
            enabled: root.active
            onClicked: root.ctl("stop")
          }

          Button {
            id: back5Button
            width: playPauseButton.implicitWidth
            height: playPauseButton.implicitHeight
            tooltipText: strings.t("back5")
            bordered: true
            focusable: true
            enabled: root.status === "playing"
            onClicked: root.skip(-5)

            Image {
              anchors.centerIn: parent
              width: parent.width * 0.85
              height: parent.height * 0.85
              source: root.backIcon
              sourceSize.width: 128
              sourceSize.height: 128
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
          }

          Button {
            id: forward5Button
            width: playPauseButton.implicitWidth
            height: playPauseButton.implicitHeight
            tooltipText: strings.t("forward5")
            bordered: true
            focusable: true
            enabled: root.status === "playing"
            onClicked: root.skip(5)

            Image {
              anchors.centerIn: parent
              width: parent.width * 0.85
              height: parent.height * 0.85
              source: root.forwardIcon
              sourceSize.width: 128
              sourceSize.height: 128
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
          }

          Button {
            iconText: "\uf048"
            tooltipText: strings.t("previous")
            bordered: true
            focusable: true
            enabled: root.active
            onClicked: root.ctl("prev")
          }

          Button {
            iconText: "\uf050"
            tooltipText: strings.t("next")
            bordered: true
            focusable: true
            enabled: root.active
            onClicked: root.ctl("next")
          }

          Button {
            iconText: "\uf019"
            tooltipText: strings.t("download")
            bordered: true
            focusable: true
            enabled: root.downloadable
            onClicked: root.save()
          }
        }

        Button {
          text: strings.t("speed") + ": " + root.speedLabel(root.speed)
          tooltipText: strings.t("speed")
          bordered: true
          focusable: true
          leftAlign: true
          onClicked: root.cycleSpeed()
        }

        Button {
          text: strings.t("ruVoice") + ": " + root.voiceLabel(root.ruVoice)
          tooltipText: strings.t("ruVoice")
          bordered: true
          focusable: true
          leftAlign: true
          onClicked: root.cycleVoice("ruVoice", root.ruVoices)
        }

        Button {
          text: strings.t("enVoice") + ": " + root.voiceLabel(root.enVoice)
          tooltipText: strings.t("enVoice")
          bordered: true
          focusable: true
          leftAlign: true
          onClicked: root.cycleVoice("enVoice", root.enVoices)
        }
      }
    }
  }
}
