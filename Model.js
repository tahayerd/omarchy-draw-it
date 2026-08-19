.pragma library

// Standard color presets available for drawing
var COLOR_PRESETS = [
  { name: "Red", hex: "#ff4d4f", key: "1" },
  { name: "Green", hex: "#52c41a", key: "2" },
  { name: "Blue", hex: "#1890ff", key: "3" },
  { name: "Yellow", hex: "#fadb14", key: "4" },
  { name: "Orange", hex: "#fa8c16", key: "5" },
  { name: "Purple", hex: "#722ed1", key: "6" },
  { name: "Cyan", hex: "#13c2c8", key: "7" },
  { name: "White", hex: "#ffffff", key: "8" },
  { name: "Black", hex: "#141414", key: "9" }
];

var STROKE_WIDTHS = [
  { label: "Fine", value: 2 },
  { label: "Medium", value: 4 },
  { label: "Thick", value: 8 },
  { label: "Bold", value: 14 }
];

function getPresets() {
  return COLOR_PRESETS;
}

function getWidthPresets() {
  return STROKE_WIDTHS;
}

function colorByKey(key) {
  for (var i = 0; i < COLOR_PRESETS.length; i++) {
    if (COLOR_PRESETS[i].key === String(key)) {
      return COLOR_PRESETS[i].hex;
    }
  }
  return null;
}

function computeBoundingBox(points) {
  if (!points || points.length === 0) return null;
  var minX = points[0].x, maxX = points[0].x;
  var minY = points[0].y, maxY = points[0].y;
  for (var i = 1; i < points.length; i++) {
    var p = points[i];
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  return { minX: minX, maxX: maxX, minY: minY, maxY: maxY };
}

function createStroke(color, width) {
  return {
    id: Date.now() + "_" + Math.random().toString(36).substr(2, 5),
    color: color || "#ff4d4f",
    width: width || 4,
    points: [],
    bbox: null
  };
}

// Carve a single stroke with an eraser circle at (cx, cy) of radius R
function carveStrokeWithCircle(stroke, cx, cy, R) {
  if (!stroke || !stroke.points || stroke.points.length === 0) return [];
  var pts = stroke.points;
  var effectiveR = R + ((stroke.width || 4) * 0.35);
  var R_sq = effectiveR * effectiveR;

  // Single point (dot)
  if (pts.length === 1) {
    var dx = pts[0].x - cx;
    var dy = pts[0].y - cy;
    if (dx * dx + dy * dy <= R_sq) {
      return []; // completely erased
    }
    return [stroke];
  }

  // Bounding box quick reject
  if (stroke.bbox) {
    if (cx < stroke.bbox.minX - effectiveR || cx > stroke.bbox.maxX + effectiveR ||
        cy < stroke.bbox.minY - effectiveR || cy > stroke.bbox.maxY + effectiveR) {
      return [stroke]; // not touched
    }
  }

  var resultingStrokes = [];
  var currentSubPoints = [];

  function isInside(p) {
    var ddx = p.x - cx;
    var ddy = p.y - cy;
    return (ddx * ddx + ddy * ddy) <= R_sq;
  }

  function finishSubStroke() {
    if (currentSubPoints.length > 0) {
      var sub = {
        id: Date.now() + "_" + Math.random().toString(36).substr(2, 5),
        color: stroke.color,
        width: stroke.width,
        points: currentSubPoints,
        bbox: computeBoundingBox(currentSubPoints)
      };
      resultingStrokes.push(sub);
      currentSubPoints = [];
    }
  }

  var aInside = isInside(pts[0]);
  if (!aInside) {
    currentSubPoints.push({ x: pts[0].x, y: pts[0].y });
  }

  for (var i = 0; i < pts.length - 1; i++) {
    var A = pts[i];
    var B = pts[i + 1];
    var Dx = B.x - A.x;
    var Dy = B.y - A.y;
    var a = Dx * Dx + Dy * Dy;
    var bInside = isInside(B);

    if (a === 0) {
      aInside = bInside;
      continue;
    }

    var Fx = A.x - cx;
    var Fy = A.y - cy;
    var b = 2 * (Fx * Dx + Fy * Dy);
    var c = Fx * Fx + Fy * Fy - R_sq;
    var disc = b * b - 4 * a * c;

    if (disc < 0) {
      if (!aInside && !bInside) {
        currentSubPoints.push({ x: B.x, y: B.y });
      }
    } else {
      var sqrtDisc = Math.sqrt(disc);
      var t1 = (-b - sqrtDisc) / (2 * a);
      var t2 = (-b + sqrtDisc) / (2 * a);

      if (!aInside && !bInside) {
        if (t1 > 0 && t1 < 1 && t2 > 0 && t2 < 1) {
          var pEnter = { x: A.x + t1 * Dx, y: A.y + t1 * Dy };
          var pExit = { x: A.x + t2 * Dx, y: A.y + t2 * Dy };
          currentSubPoints.push(pEnter);
          finishSubStroke();
          currentSubPoints.push(pExit);
          currentSubPoints.push({ x: B.x, y: B.y });
        } else {
          currentSubPoints.push({ x: B.x, y: B.y });
        }
      } else if (!aInside && bInside) {
        var tEnter = (t1 > 0 && t1 < 1) ? t1 : (t2 > 0 && t2 < 1 ? t2 : 0.5);
        var pIn = { x: A.x + tEnter * Dx, y: A.y + tEnter * Dy };
        currentSubPoints.push(pIn);
        finishSubStroke();
      } else if (aInside && !bInside) {
        var tExit = (t2 > 0 && t2 < 1) ? t2 : (t1 > 0 && t1 < 1 ? t1 : 0.5);
        var pOut = { x: A.x + tExit * Dx, y: A.y + tExit * Dy };
        currentSubPoints.push(pOut);
        currentSubPoints.push({ x: B.x, y: B.y });
      }
    }

    aInside = bInside;
  }

  finishSubStroke();
  return resultingStrokes;
}

// Partially erase strokes at (cx, cy) with given radius
function eraseStrokesPartial(strokes, cx, cy, radius) {
  if (!strokes || strokes.length === 0) return strokes;
  var newStrokes = [];
  var modified = false;

  for (var i = 0; i < strokes.length; i++) {
    var s = strokes[i];
    var carved = carveStrokeWithCircle(s, cx, cy, radius);
    if (carved.length !== 1 || carved[0] !== s) {
      modified = true;
    }
    for (var k = 0; k < carved.length; k++) {
      newStrokes.push(carved[k]);
    }
  }

  return modified ? newStrokes : strokes;
}

// Interpolate continuous eraser path from (x1, y1) to (x2, y2)
function eraseAlongPath(strokes, x1, y1, x2, y2, radius) {
  var dx = x2 - x1;
  var dy = y2 - y1;
  var dist = Math.sqrt(dx * dx + dy * dy);
  var step = Math.max(3, radius * 0.4);
  var steps = Math.max(1, Math.ceil(dist / step));
  var currentStrokes = strokes;

  for (var i = 1; i <= steps; i++) {
    var t = i / steps;
    var x = x1 + t * dx;
    var y = y1 + t * dy;
    currentStrokes = eraseStrokesPartial(currentStrokes, x, y, radius);
  }

  return currentStrokes;
}
