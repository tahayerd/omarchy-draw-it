pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.taha.draw-it"
  ipcTarget: "io.github.taha.draw-it"
  manageIpc: false

  property string currentColor: String(setting("defaultColor", "#ff4d4f"))
  property int currentWidth: parseInt(setting("defaultWidth", 4), 10) || 4
  property int eraserRadius: parseInt(setting("eraserRadius", 18), 10) || 18
  property bool clearOnExit: setting("clearOnExit", false) === true
  property string barIcon: String(setting("icon", "󰏫")).trim() || "󰏫"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  DrawingOverlay {
    id: overlay
    currentColor: root.currentColor
    currentWidth: root.currentWidth
    eraserRadius: root.eraserRadius
    clearOnExit: root.clearOnExit
    onCurrentColorChanged: root.currentColor = currentColor
    onCurrentWidthChanged: root.currentWidth = currentWidth
  }

  IpcHandler {
    target: root.ipcTarget

    function toggle(): void {
      overlay.toggle()
    }
    function start(): void {
      overlay.open()
    }
    function open(): void {
      overlay.open()
    }
    function stop(): void {
      overlay.close()
    }
    function close(): void {
      overlay.close()
    }
    function clear(): void {
      overlay.clearAll()
    }
    function undo(): void {
      overlay.undo()
    }
    function redo(): void {
      overlay.redo()
    }
    function settings(): void {
      root.open()
    }
    function setColor(col: string): string {
      root.currentColor = col
      overlay.currentColor = col
      return "ok"
    }
    function setWidth(w: int): string {
      root.currentWidth = w
      overlay.currentWidth = w
      return "ok"
    }
    function status(): string {
      return overlay.active ? "drawing" : "idle"
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIcon
    tooltipText: overlay.active
      ? "Draw-It (Drawing mode active - click to exit)"
      : "Draw-It (Left click: Draw, Right click: Settings)"
    active: overlay.active
    useActiveColor: true
    activeColor: root.currentColor

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        root.toggle()
        return
      }
      if (buttonCode === Qt.LeftButton) {
        if (root.opened) root.close()
        overlay.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(330))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(580))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Draw-It"
            meta: overlay.active ? "Drawing Mode Active" : "Screen Drawing Tool"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: root.barIcon
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                color: root.currentColor
              }
            }
          }

          // Quick actions: Start / Finish Drawing, Clear Canvas
          Row {
            width: parent.width
            spacing: Style.space(8)

            Rectangle {
              height: Style.space(32)
              width: (parent.width - Style.space(8)) / 2
              radius: Style.cornerRadius
              color: overlay.active ? Color.urgent : Color.accent

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.close()
                  overlay.toggle()
                }
              }

              Text {
                anchors.centerIn: parent
                text: overlay.active ? "Finish Drawing" : "Start Drawing"
                color: "white"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }

            Rectangle {
              height: Style.space(32)
              width: (parent.width - Style.space(8)) / 2
              radius: Style.cornerRadius
              color: Qt.rgba(1, 1, 1, 0.08)
              border.color: Qt.rgba(1, 1, 1, 0.15)
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  overlay.clearAll()
                }
              }

              Text {
                anchors.centerIn: parent
                text: "Clear Canvas"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          PanelSectionHeader {
            width: parent.width
            text: "Drawing Color"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          // Color palette swatches
          Grid {
            width: parent.width
            columns: 5
            spacing: Style.space(8)

            Repeater {
              model: Model.getPresets()

              Rectangle {
                required property var modelData
                width: (column.width - Style.space(32)) / 5
                height: Style.space(30)
                radius: Style.cornerRadius
                color: modelData.hex
                border.color: root.currentColor.toLowerCase() === modelData.hex.toLowerCase()
                  ? "white"
                  : Qt.rgba(0, 0, 0, 0.3)
                border.width: root.currentColor.toLowerCase() === modelData.hex.toLowerCase() ? 2.5 : 1

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.currentColor = parent.modelData.hex
                    overlay.currentColor = parent.modelData.hex
                  }
                }

                Text {
                  anchors.centerIn: parent
                  visible: root.currentColor.toLowerCase() === parent.modelData.hex.toLowerCase()
                  text: "✓"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: (modelData.hex === "#ffffff" || modelData.hex === "#fadb14") ? "#111111" : "white"
                }
              }
            }
          }

          PanelSectionHeader {
            width: parent.width
            text: "Brush Width (" + root.currentWidth + "px)"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          // Thickness presets
          Row {
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: Model.getWidthPresets()

              Rectangle {
                required property var modelData
                width: (column.width - Style.space(24)) / 4
                height: Style.space(30)
                radius: Style.cornerRadius
                color: root.currentWidth === modelData.value
                  ? Color.accent
                  : Qt.rgba(1, 1, 1, 0.08)
                border.color: root.currentWidth === modelData.value
                  ? "white"
                  : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.currentWidth = parent.modelData.value
                    overlay.currentWidth = parent.modelData.value
                  }
                }

                Text {
                  anchors.centerIn: parent
                  text: parent.modelData.label
                  color: root.currentWidth === parent.modelData.value ? "white" : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: root.currentWidth === parent.modelData.value
                }
              }
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 1
            maximum: 30
            step: 1
            integer: true
            value: root.currentWidth
            onMoved: function(val) {
              root.currentWidth = Math.round(val)
              overlay.currentWidth = Math.round(val)
            }
          }

          PanelSectionHeader {
            width: parent.width
            text: "Eraser Radius (" + root.eraserRadius + "px)"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 6
            maximum: 60
            step: 2
            integer: true
            value: root.eraserRadius
            onMoved: function(val) {
              root.eraserRadius = Math.round(val)
              overlay.eraserRadius = Math.round(val)
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          // Shortcut reference
          Column {
            width: parent.width
            spacing: Style.space(4)

            Text {
              width: parent.width
              text: "Shortcuts (while drawing):"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              width: parent.width
              text: "• Left Click: Draw\n• Right Click: Erase (carves only what you sweep over)\n• C: Clear the whole canvas\n• U / Ctrl+Z: Undo\n• Ctrl+Y / Ctrl+Shift+Z: Redo\n• [ / ]: Decrease / increase brush width\n• 1 - 9: Quick color selection\n• Esc / Q: Exit drawing mode\n• SUPER+ALT+D: Toggle drawing on/off (drawings are kept)"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
