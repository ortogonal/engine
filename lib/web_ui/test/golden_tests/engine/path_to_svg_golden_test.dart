// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.6
import 'dart:html' as html;

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart';

import 'package:web_engine_tester/golden_tester.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() async {
  final Rect region = Rect.fromLTWH(8, 8, 600, 800); // Compensate for old scuba tester padding

  Future<void> testPath(Path path, String scubaFileName,
      {Paint paint, double maxDiffRatePercent = null, bool write = false,
      bool strokeEnabled = true, bool enableFill = true}) async {
    const Rect canvasBounds = Rect.fromLTWH(0, 0, 600, 800);
    final BitmapCanvas bitmapCanvas = BitmapCanvas(canvasBounds,
        RenderStrategy());
    final RecordingCanvas canvas = RecordingCanvas(canvasBounds);

    if (enableFill) {
      paint ??= Paint()
        ..color = const Color(0x807F7F7F)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
    }

    if (strokeEnabled) {
      paint = Paint()
        ..strokeWidth = 2
        ..color = enableFill ? const Color(0xFFFF0000) :
            const Color(0xFF000000)
        ..style = PaintingStyle.stroke;
    }

    canvas.drawPath(path, paint);

    final html.Element svgElement = pathToSvgElement(path, paint,
        enableFill);

    html.document.body.append(bitmapCanvas.rootElement);
    html.document.body.append(svgElement);

    canvas.endRecording();
    canvas.apply(bitmapCanvas, canvasBounds);

    await matchGoldenFile('$scubaFileName.png', region: region,
        maxDiffRatePercent: maxDiffRatePercent, write: write);

    bitmapCanvas.rootElement.remove();
    svgElement.remove();
  }

  tearDown(() {
    html.document.body.children.clear();
  });

  test('render line strokes', () async {
    final Path path = Path();
    path.moveTo(50, 60);
    path.lineTo(200, 300);
    await testPath(path, 'svg_stroke_line',
        paint: Paint()
          ..color = const Color(0xFFFF0000)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke);
  });

  test('render quad bezier curve', () async {
    final Path path = Path();
    path.moveTo(50, 60);
    path.quadraticBezierTo(200, 60, 50, 200);
    await testPath(path, 'svg_quad_bezier');
  });

  test('render cubic curve', () async {
    final Path path = Path();
    path.moveTo(50, 60);
    path.cubicTo(200, 60, -100, -50, 150, 200);
    await testPath(path, 'svg_cubic_bezier');
  });

  test('render arcs', () async {
    final List<ArcSample> arcs = <ArcSample>[
      ArcSample(const Offset(0, 0),
          largeArc: false, clockwise: false, distance: 20),
      ArcSample(const Offset(200, 0),
          largeArc: true, clockwise: false, distance: 20),
      ArcSample(const Offset(0, 150),
          largeArc: false, clockwise: true, distance: 20),
      ArcSample(const Offset(200, 150),
          largeArc: true, clockwise: true, distance: 20),
      ArcSample(const Offset(0, 300),
          largeArc: false, clockwise: false, distance: -20),
      ArcSample(const Offset(200, 300),
          largeArc: true, clockwise: false, distance: -20),
      ArcSample(const Offset(0, 450),
          largeArc: false, clockwise: true, distance: -20),
      ArcSample(const Offset(200, 450),
          largeArc: true, clockwise: true, distance: -20)
    ];
    int sampleIndex = 0;
    for (ArcSample sample in arcs) {
      ++sampleIndex;
      final Path path = sample.createPath();
      await testPath(path, 'svg_arc_$sampleIndex');
    }
  });

  test('render rect', () async {
    final Path path = Path();
    path.addRect(const Rect.fromLTRB(15, 15, 60, 20));
    path.addRect(const Rect.fromLTRB(35, 160, 15, 100));
    await testPath(path, 'svg_rect', maxDiffRatePercent: 1.0);
  });

  test('render notch', () async {
    final Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(83, 0);
    path.quadraticBezierTo(98, 0, 99.97, 7.8);
    path.arcToPoint(const Offset(162, 7.8),
        radius: const Radius.circular(32),
        largeArc: false,
        clockwise: false,
        rotation: 0);
    path.lineTo(200, 7.8);
    path.lineTo(200, 80);
    path.lineTo(0, 80);
    path.lineTo(0, 10);
    await testPath(path, 'svg_notch');
  });

  /// Regression test for https://github.com/flutter/flutter/issues/70980
  test('render notch', () async {
    const double w = 0.7;
    final Path path = Path();
    path.moveTo(0.5, 14);
    path.conicTo(0.5, 10.5, 4, 10.5, w);
    path.moveTo(4, 10.5);
    path.lineTo(6.5, 10.5);
    path.moveTo(36.0, 10.5);
    path.lineTo(158, 10.5);
    path.conicTo(161.5, 10.5, 161.5, 14, w);
    path.moveTo(161.5, 14);
    path.lineTo(161.5, 48);
    path.conicTo(161.5, 51.5, 158, 51.5, w);
    path.lineTo(4, 51.5);
    path.conicTo(0.5, 51.5, 0.5, 48, w);
    path.lineTo(0.5, 14);
    await testPath(path, 'svg_editoutline', enableFill: false);
  });
}

html.Element pathToSvgElement(Path path, Paint paint,
    bool enableFill) {
  final Rect bounds = path.getBounds();
  final StringBuffer sb = StringBuffer();
  sb.write(
      '<svg viewBox="0 0 ${bounds.right} ${bounds.bottom}" '
          'width="${bounds.right}" height="${bounds.bottom}">');
  sb.write('<path ');
  if (paint.style == PaintingStyle.stroke) {
    sb.write('stroke="${colorToCssString(paint.color)}" ');
    sb.write('stroke-width="${paint.strokeWidth}" ');
    if (!enableFill) {
      sb.write('fill="none" ');
    }
  }
  if (paint.style == PaintingStyle.fill) {
    sb.write('fill="${colorToCssString(paint.color)}" ');
  }
  sb.write('d="');
  pathToSvg(path, sb); // This is what we're testing!
  sb.write('"></path>');
  sb.write('</svg>');
  final html.Element svgElement =
      html.Element.html(sb.toString(), treeSanitizer: _NullTreeSanitizer());
  svgElement.style.transform = 'translate(200px, 0px)';
  return svgElement;
}

class _NullTreeSanitizer implements html.NodeTreeSanitizer {
  @override
  void sanitizeTree(html.Node node) {}
}

class ArcSample {
  final Offset offset;
  final bool largeArc;
  final bool clockwise;
  final double distance;
  ArcSample(this.offset,
      {this.largeArc = false, this.clockwise = false, this.distance = 0});

  Path createPath() {
    final Offset startP =
        Offset(75 - distance + offset.dx, 75 - distance + offset.dy);
    final Offset endP =
        Offset(75.0 + distance + offset.dx, 75.0 + distance + offset.dy);
    final Path path = Path();
    path.moveTo(startP.dx, startP.dy);
    path.arcToPoint(endP,
        rotation: 60,
        radius: const Radius.elliptical(40, 60),
        largeArc: largeArc,
        clockwise: clockwise);
    return path;
  }

  // Returns bounds of start/end point of arc.
  Rect getBounds() {
    final Offset startP =
        Offset(75 - distance + offset.dx, 75 - distance + offset.dy);
    final Offset endP =
        Offset(75.0 + distance + offset.dx, 75.0 + distance + offset.dy);
    return Rect.fromLTRB(startP.dx, startP.dy, endP.dx, endP.dy);
  }
}
