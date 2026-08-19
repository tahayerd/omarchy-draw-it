pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property bool active: false
  property string currentColor: "#ff4d4f"
  property int currentWidth: 4
  property int eraserRadius: 18
  property bool clearOnExit: false

  property var strokes: []
  property var currentStroke: null
  property var undoStack: []
  property var redoStack: []
  property string toastText: ""

  signal closeRequested()
  signal requestPaintSignal()

  function open() {
    active = true
    toastText = "✏️ Draw-It · Left-click: Draw · Right-click: Erase · C: Clear · U / Ctrl+Z: Undo · 1-9: Color · Esc: Exit"
    toastTimer.restart()
    requestPaintSignal()
    repaintTimer.restart()
  }

  function close() {
    if (clearOnExit) {
      clearAll()
    }
    active = false
    closeRequested()
  }

  function toggle() {
    if (active) close()
    else open()
  }

  function clearAll() {
    if (strokes.length > 0) {
      undoStack.push({ type: "clear", strokes: strokes.slice() })
      redoStack = []
      strokes = []
      currentStroke = null
      requestPaintSignal()
    }
  }

  function undo() {
    if (undoStack.length === 0) return
    var action = undoStack.pop()
    if (action.type === "add") {
      strokes = strokes.filter(function(s) { return s.id !== action.stroke.id })
      redoStack.push(action)
    } else if (action.type === "replace") {
      strokes = action.before.slice()
      redoStack.push(action)
    } else if (action.type === "clear") {
      strokes = action.strokes.slice()
      redoStack.push(action)
    }
    requestPaintSignal()
  }

  function redo() {
    if (redoStack.length === 0) return
    var action = redoStack.pop()
    if (action.type === "add") {
      strokes = strokes.concat([action.stroke])
      undoStack.push(action)
    } else if (action.type === "replace") {
      strokes = action.after.slice()
      undoStack.push(action)
    } else if (action.type === "clear") {
      undoStack.push({ type: "clear", strokes: strokes.slice() })
      strokes = []
    }
    requestPaintSignal()
  }

  function eraseAt(ex, ey) {
    var updated = Model.eraseStrokesPartial(strokes, ex, ey, eraserRadius)
    if (updated !== strokes) {
      strokes = updated
      requestPaintSignal()
    }
  }

  function erasePath(x1, y1, x2, y2) {
    var updated = Model.eraseAlongPath(strokes, x1, y1, x2, y2, eraserRadius)
    if (updated !== strokes) {
      strokes = updated
      requestPaintSignal()
    }
  }

  function showToast(msg) {
    toastText = msg
    toastTimer.restart()
  }

  Timer {
    id: toastTimer
    interval: 3500
    running: false
    onTriggered: root.toastText = ""
  }

  // Backup repaint timer to ensure full render after Wayland surface mapping
  Timer {
    id: repaintTimer
    interval: 60
    repeat: false
    onTriggered: root.requestPaintSignal()
  }

  Variants {
    id: screenVariants
    model: Quickshell.screens

    delegate: PanelWindow {
      id: window
      required property var modelData

      screen: modelData
      visible: root.active
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-draw-it-overlay"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      onVisibleChanged: {
        if (visible) {
          Qt.callLater(function() {
            keyCatcherItem.forceActiveFocus()
            drawCanvas.requestPaint()
          })
        }
      }

      Connections {
        target: root
        function onRequestPaintSignal() {
          if (drawCanvas.available) {
            drawCanvas.requestPaint()
          }
        }
        function onActiveChanged() {
          if (root.active) {
            Qt.callLater(function() {
              keyCatcherItem.forceActiveFocus()
              if (drawCanvas.available) {
                drawCanvas.requestPaint()
              }
            })
          }
        }
      }

      Item {
        id: canvasHost
        anchors.fill: parent

        Canvas {
          id: drawCanvas
          anchors.fill: parent
          renderTarget: Canvas.Image
          renderStrategy: Canvas.Immediate
          antialiasing: true

          onAvailableChanged: {
            if (available) requestPaint()
          }
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()

          onPaint: {
            var ctx = getContext("2d")
            if (!ctx) return

            var w = width
            var h = height
            if (w <= 0 || h <= 0) return

            ctx.save()
            ctx.clearRect(0, 0, w, h)

            // Draw all committed strokes
            var allStrokes = root.strokes
            if (allStrokes && allStrokes.length > 0) {
              for (var i = 0; i < allStrokes.length; i++) {
                drawSingleStroke(ctx, allStrokes[i])
              }
            }

            // Draw current active stroke
            if (root.currentStroke) {
              drawSingleStroke(ctx, root.currentStroke)
            }

            ctx.restore()
          }

          function drawSingleStroke(ctx, stroke) {
            if (!stroke || !stroke.points || stroke.points.length === 0) return

            var col = String(stroke.color || root.currentColor || "#ff4d4f")
            var lw = Number(stroke.width || root.currentWidth || 4)
            var pts = stroke.points

            ctx.save()
            ctx.strokeStyle = col
            ctx.fillStyle = col
            ctx.lineWidth = lw
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            if (pts.length === 1) {
              ctx.beginPath()
              ctx.arc(pts[0].x, pts[0].y, lw / 2, 0, Math.PI * 2)
              ctx.fill()
            } else {
              ctx.beginPath()
              ctx.moveTo(pts[0].x, pts[0].y)
              for (var j = 1; j < pts.length; j++) {
                ctx.lineTo(pts[j].x, pts[j].y)
              }
              ctx.stroke()
            }

            ctx.restore()
          }
        }

        // Dedicated item for keyboard capture
        Item {
          id: keyCatcherItem
          anchors.fill: parent
          focus: true
          z: 10

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
              root.close()
              event.accepted = true
            } else if (event.key === Qt.Key_C) {
              root.clearAll()
              root.showToast("Canvas cleared")
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
              if (event.modifiers & Qt.ShiftModifier) {
                root.redo()
              } else {
                root.undo()
              }
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) {
              root.redo()
              event.accepted = true
            } else if (event.key === Qt.Key_U) {
              root.undo()
              event.accepted = true
            } else if (event.key === Qt.Key_BracketLeft) {
              root.currentWidth = Math.max(1, root.currentWidth - 2)
              root.showToast("Width: " + root.currentWidth + "px")
              event.accepted = true
            } else if (event.key === Qt.Key_BracketRight) {
              root.currentWidth = Math.min(40, root.currentWidth + 2)
              root.showToast("Width: " + root.currentWidth + "px")
              event.accepted = true
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
              var keyChar = String.fromCharCode(event.key)
              var col = Model.colorByKey(keyChar)
              if (col) {
                root.currentColor = col
                root.showToast("Color: " + col)
              }
              event.accepted = true
            }
          }
        }

        // Custom visual cursor indicator showing current brush or eraser size
        Rectangle {
          id: cursorIndicator
          visible: mouseArea.containsMouse && root.active
          x: mouseArea.mouseX - width / 2
          y: mouseArea.mouseY - height / 2
          width: mouseArea.isErasing ? root.eraserRadius * 2 : Math.max(8, root.currentWidth)
          height: width
          radius: width / 2
          color: mouseArea.isErasing ? Qt.rgba(1, 0, 0, 0.2) : Qt.rgba(0, 0, 0, 0.1)
          border.color: mouseArea.isErasing ? "#ff4d4f" : root.currentColor
          border.width: mouseArea.isErasing ? 2 : 1.5
          z: 100
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          hoverEnabled: true
          cursorShape: Qt.BlankCursor
          z: 30

          property bool isDrawing: false
          property bool isErasing: false
          property real lastEraseX: 0
          property real lastEraseY: 0
          property var eraseSnapshot: null

          onPressed: function(mouse) {
            keyCatcherItem.forceActiveFocus()
            if (mouse.button === Qt.LeftButton) {
              isDrawing = true
              isErasing = false
              root.currentStroke = Model.createStroke(root.currentColor, root.currentWidth)
              root.currentStroke.points = [{ x: mouse.x, y: mouse.y }]
              drawCanvas.requestPaint()
            } else if (mouse.button === Qt.RightButton) {
              isErasing = true
              isDrawing = false
              lastEraseX = mouse.x
              lastEraseY = mouse.y
              eraseSnapshot = root.strokes.slice()
              root.eraseAt(mouse.x, mouse.y)
              drawCanvas.requestPaint()
            }
          }

          onPositionChanged: function(mouse) {
            if (isDrawing && root.currentStroke) {
              root.currentStroke.points.push({ x: mouse.x, y: mouse.y })
              drawCanvas.requestPaint()
            } else if (isErasing) {
              root.erasePath(lastEraseX, lastEraseY, mouse.x, mouse.y)
              lastEraseX = mouse.x
              lastEraseY = mouse.y
              drawCanvas.requestPaint()
            }
          }

          onReleased: function(mouse) {
            if (isDrawing && root.currentStroke) {
              if (root.currentStroke.points.length > 0) {
                root.currentStroke.bbox = Model.computeBoundingBox(root.currentStroke.points)
                root.strokes.push(root.currentStroke)
                root.undoStack.push({ type: "add", stroke: root.currentStroke })
                root.redoStack = []
              }
              root.currentStroke = null
              isDrawing = false
              drawCanvas.requestPaint()
            } else if (isErasing) {
              if (eraseSnapshot !== null && eraseSnapshot !== root.strokes) {
                root.undoStack.push({ type: "replace", before: eraseSnapshot, after: root.strokes.slice() })
                root.redoStack = []
              }
              eraseSnapshot = null
              isErasing = false
              drawCanvas.requestPaint()
            }
          }
        }

        // Minimalist HUD toast
        Rectangle {
          id: toastCard
          anchors.top: parent.top
          anchors.topMargin: Style.space(16)
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.toastText !== ""
          opacity: visible ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 200 } }
          radius: Style.space(8)
          color: Qt.rgba(0.08, 0.08, 0.09, 0.88)
          border.color: Qt.rgba(1, 1, 1, 0.15)
          border.width: 1
          implicitWidth: toastLabel.implicitWidth + Style.space(24)
          implicitHeight: toastLabel.implicitHeight + Style.space(12)
          z: 200

          Text {
            id: toastLabel
            anchors.centerIn: parent
            text: root.toastText
            color: "white"
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }
      }
    }
  }
}
