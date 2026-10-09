import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// TinyTerminal for the bar: an "Omarchy  " prompt (accent coloured, so it
// follows the theme), a few spaces, then a one-line input. Enter runs the
// command in your interactive zsh and the output opens in a popup above (or
// below) the bar. It is a command runner, not a terminal emulator: programs
// that need a real TTY (vim, btop, ssh...) are handed to your terminal.
//
//   Enter          run            Shift+Enter  run in a real terminal
//   (anything with sudo / su / pkexec, and TUIs like vim or btop, opens a
//    real tiled terminal automatically)
//   Up / Down      history        Ctrl+C       stop the running command
//   Esc            close popup and stop typing
//   omarchy-shell s3pp3ku.tinyterminal focus|toggle|close   (bind a key)
BarWidget {
  id: root
  moduleName: "s3pp3ku.tinyterminal"

  // The host bar grants this widget the keyboard only while it is true.
  property bool typing: false
  readonly property bool wantsKeyboard: typing

  readonly property int inputWidth: Number(setting("inputWidth", 260))
  readonly property int gap: Math.max(0, Number(setting("gap", 4)))
  readonly property int popupWidth: Number(setting("popupWidth", 640))
  readonly property int popupHeight: Number(setting("popupHeight", 280))
  readonly property bool interactiveShell: setting("interactiveShell", false) === true

  readonly property color accent: Color.accent
  readonly property color fg: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string fontName: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string mono: "monospace"

  // Programs that need a real terminal.
  readonly property var tuiCommands: ["vim", "nvim", "vi", "nano", "emacs", "btop", "htop", "top", "less",
                                      "man", "ssh", "yazi", "ranger", "mc", "tmux", "herdr", "fzf", "watch"]

  // ---- state ---------------------------------------------------------------
  property bool popupOpen: false
  property string cwd: Quickshell.env("HOME")
  property string lastCommand: ""
  property string output: ""
  property bool running: proc.running
  property int exitCode: -1
  property var history: []
  property int historyIndex: -1

  function startTyping() {
    typing = true
    Qt.callLater(function () { input.forceActiveFocus() })
  }

  function stopTyping() {
    typing = false
    input.focus = false
    root.forceActiveFocus()   // move focus off the input so its cursor stops showing
  }

  // Called by the host bar when the user clicks away.
  function releaseKeyboard() { stopTyping() }

  function close() {
    popupOpen = false
    stopTyping()
  }

  // Backstop: never hold the keyboard for long without a keypress.
  Timer {
    id: idleRelease
    interval: 20000
    running: root.typing
    onTriggered: root.stopTyping()
  }

  function clean(s) {
    return s.replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "").replace(/\r/g, "")
  }

  function append(line) {
    var next = output + line + "\n"
    output = next.length > 200000 ? next.slice(next.length - 150000) : next
  }

  function openInTerminal(cmd) {
    Quickshell.execDetached({
      command: ["xdg-terminal-exec", "zsh", "-c", cmd + "; echo; read -k1 '?Press any key to close'"],
      workingDirectory: root.cwd
    })
  }

  function run(cmd, inTerminal) {
    cmd = cmd.trim()
    if (cmd === "") return
    history = history.concat([cmd]).slice(-200)
    historyIndex = -1
    if (cmd === "clear" || cmd === "cls") { output = ""; lastCommand = ""; exitCode = -1; return }

    var first = cmd.split(/\s+/)[0]
    // sudo/su/pkexec ask for a password on a TTY and there is none here, so
    // those go to a real (tiled) terminal window, as do full-screen programs.
    var needsTty = /(^|[\s;&|(])(sudo|su|pkexec|doas|passwd)(\s|$)/.test(cmd)
    if (inTerminal || needsTty || tuiCommands.indexOf(first) !== -1) {
      openInTerminal(cmd)
      return
    }

    if (proc.running) proc.running = false
    lastCommand = cmd
    output = ""
    exitCode = -1
    popupOpen = true
    proc.environment = { TT_CMD: cmd }
    proc.workingDirectory = cwd
    proc.running = true
  }

  Process {
    id: proc
    // stderr is folded into stdout inside the shell so lines stay in order.
    // "interactiveShell": true also loads ~/.zshrc (aliases, functions) but
    // runs anything that file prints, e.g. a fastfetch banner, every time.
    command: ["zsh", root.interactiveShell ? "-ic" : "-c", "exec 2>&1; eval \"$TT_CMD\"; __tt=$?; print -r -- \"__TT_END__ $__tt $PWD\""]
    stdout: SplitParser {
      onRead: function (data) {
        var line = root.clean(data)
        if (line.indexOf("__TT_END__ ") === 0) {
          var parts = line.split(" ")
          root.exitCode = Number(parts[1])
          root.cwd = parts.slice(2).join(" ")
        } else {
          root.append(line)
        }
      }
    }
    onExited: function (code) {
      if (root.exitCode === -1) root.exitCode = code
    }
  }

  IpcHandler {
    target: "s3pp3ku.tinyterminal"
    function focus(): void { root.startTyping() }
    function toggle(): void { if (root.typing || root.popupOpen) root.close(); else root.startTyping() }
    function close(): void { root.close() }
  }

  // ---- the bar item --------------------------------------------------------
  TextMetrics { id: spaceMetrics; font.family: root.mono; font.pixelSize: Style.font.body; text: " " }

  implicitWidth: row.implicitWidth + Style.space(16)
  implicitHeight: root.barSize

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Style.space(8)
    spacing: 0

    // "Omarchy  " in the accent colour.
    Text {
      id: logo
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "Omarchy "
      color: root.accent
      font.family: root.fontName
      font.pixelSize: Style.bar.iconFont
      font.bold: true
    }

    // The spaces between the logo and where you type.
    // (plus a fixed pad: the terminal glyph overhangs its advance width, so
    // without it the cursor sits on top of the icon)
    Item { width: root.gap * spaceMetrics.width + Style.space(8); height: 1 }

    Item {
      width: root.inputWidth
      height: root.barSize
      anchors.verticalCenter: parent.verticalCenter

      TextInput {
        id: input
        anchors.fill: parent
        anchors.topMargin: Style.space(3)
        anchors.bottomMargin: Style.space(3)
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: root.fg
        selectionColor: root.accent
        selectedTextColor: Color.background
        font.family: root.mono
        font.pixelSize: Style.font.body
        cursorVisible: root.typing
        cursorDelegate: Rectangle { width: Style.space(2); color: root.accent; visible: root.typing }

        Keys.onPressed: function (e) {
          idleRelease.restart()
          if (e.key === Qt.Key_Escape) { root.close(); e.accepted = true }
          else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) {
            var cmd = input.text
            input.text = ""
            // Let go of the keyboard first, always: a hand-off to a real
            // terminal (sudo!) has to be able to receive keys.
            root.stopTyping()
            root.run(cmd, (e.modifiers & Qt.ShiftModifier) !== 0)
            e.accepted = true
          }
          else if (e.key === Qt.Key_C && (e.modifiers & Qt.ControlModifier) && proc.running) {
            proc.signal(2); e.accepted = true
          }
          else if (e.key === Qt.Key_Up && root.history.length > 0) {
            root.historyIndex = Math.min(root.historyIndex + 1, root.history.length - 1)
            input.text = root.history[root.history.length - 1 - root.historyIndex]
            input.cursorPosition = input.text.length
            e.accepted = true
          }
          else if (e.key === Qt.Key_Down) {
            root.historyIndex = Math.max(root.historyIndex - 1, -1)
            input.text = root.historyIndex < 0 ? "" : root.history[root.history.length - 1 - root.historyIndex]
            input.cursorPosition = input.text.length
            e.accepted = true
          }
        }
      }

      // Faint hint while empty so the field is findable.
      Text {
        visible: input.text === "" && !root.typing
        anchors.verticalCenter: parent.verticalCenter
        text: "run a command…"
        color: root.fg
        opacity: 0.35
        font.family: root.mono
        font.pixelSize: Style.font.body
      }

      // Clicking starts typing (and takes the keyboard from the bar).
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: function (m) { root.startTyping(); m.accepted = false }
      }
    }
  }

  // Clicking the logo re-opens the last output.
  MouseArea {
    x: row.x
    width: logo.width
    height: parent.height
    cursorShape: Qt.PointingHandCursor
    onClicked: { if (root.lastCommand !== "") root.popupOpen = !root.popupOpen }
  }

  // ---- output popup --------------------------------------------------------
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(root.popupWidth))
    contentHeight: popup.fittedContentHeight(Style.space(root.popupHeight))

    Column {
      anchors.fill: parent
      spacing: Style.space(6)

      // "Omarchy  command" + status
      Item {
        width: parent.width
        height: headerCommand.implicitHeight

        Text {
          id: headerCommand
          anchors.left: parent.left
          anchors.right: status.left
          anchors.rightMargin: Style.space(8)
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: "  " + root.lastCommand
          color: root.accent
          font.family: root.mono
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          id: status
          anchors.right: parent.right
          text: root.running ? "running…  (Ctrl+C stops)" : (root.exitCode === 0 ? "done" : (root.exitCode > 0 ? "exit " + root.exitCode : ""))
          color: root.exitCode > 0 && !root.running ? Color.urgent : Color.muted
          font.family: root.mono
          font.pixelSize: Style.font.caption
        }
      }

      Rectangle { width: parent.width; height: 1; color: root.accent; opacity: 0.5 }

      Flickable {
        id: flick
        width: parent.width
        height: parent.height - headerCommand.implicitHeight - Style.space(14)
        contentWidth: width
        contentHeight: outputText.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Follow the output while it grows, unless the user scrolled up.
        property bool stick: true
        onContentHeightChanged: if (stick) contentY = Math.max(0, contentHeight - height)
        onMovementEnded: stick = contentY >= contentHeight - height - 4

        TextEdit {
          id: outputText
          width: flick.width
          readOnly: true
          selectByMouse: true
          wrapMode: TextEdit.Wrap
          textFormat: TextEdit.PlainText
          text: root.output === "" && !root.running ? "(no output)" : root.output
          color: Color.popups.text
          selectionColor: root.accent
          selectedTextColor: Color.background
          font.family: root.mono
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
