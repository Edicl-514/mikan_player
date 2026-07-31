import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/utils/dominant_color.dart';

void main() {
  int rOf(Color c) => (c.r * 255).round();
  int gOf(Color c) => (c.g * 255).round();
  int bOf(Color c) => (c.b * 255).round();

  group('dominantColorFromRgbaPixels', () {
    ByteData solidPixels(List<(int, int, int, int)> pixels) {
      final data = ByteData(pixels.length * 4);
      for (var i = 0; i < pixels.length; i++) {
        final (r, g, b, a) = pixels[i];
        final offset = i * 4;
        data.setUint8(offset, r);
        data.setUint8(offset + 1, g);
        data.setUint8(offset + 2, b);
        data.setUint8(offset + 3, a);
      }
      return data;
    }

    test('picks the most populated color bucket', () {
      final pixels = solidPixels([
        for (var i = 0; i < 80; i++) (200, 30, 30, 255),
        for (var i = 0; i < 16; i++) (10, 10, 200, 255),
      ]);
      final color = dominantColorFromRgbaPixels(pixels, 96);
      expect(rOf(color), inInclusiveRange(150, 220));
      expect(gOf(color), lessThan(80));
      expect(bOf(color), lessThan(80));
    });

    test('skips transparent pixels', () {
      final pixels = solidPixels([
        (0, 0, 0, 0),
        (0, 0, 0, 0),
        (40, 120, 200, 255),
        (40, 120, 200, 255),
      ]);
      final color = dominantColorFromRgbaPixels(pixels, 4);
      expect(rOf(color), closeTo(40, 5));
      expect(gOf(color), closeTo(120, 5));
      expect(bOf(color), closeTo(200, 5));
    });

    test('falls back to the mean for a scattered image', () {
      final pixels = solidPixels([
        for (var i = 0; i < 32; i++) (255, 255, 255, 255),
        for (var i = 0; i < 32; i++) (0, 0, 0, 255),
        for (var i = 0; i < 32; i++) (100, 100, 100, 255),
      ]);
      final color = dominantColorFromRgbaPixels(pixels, 96);
      // No bucket clearly dominates, so the result is the per-channel mean.
      expect(rOf(color), closeTo(118, 10));
      expect(gOf(color), closeTo(118, 10));
      expect(bOf(color), closeTo(118, 10));
    });
  });

  group('extractDominantColor', () {
    Future<ByteData> solidPng(Color color, int size) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..color = color,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return data!;
    }

    test('extracts a solid color from encoded bytes', () async {
      final png = await solidPng(const Color(0xFFC86000), 32);
      final color = await extractDominantColor(png.buffer.asUint8List());
      expect(color, isNotNull);
      expect(rOf(color!), inInclusiveRange(150, 230));
      expect(gOf(color), inInclusiveRange(60, 120));
      expect(bOf(color), lessThan(50));
    });
  });

  group('deriveChromeBackground', () {
    test('keeps the hue and darkens for white chrome text', () {
      final chrome = deriveChromeBackground(const Color(0xFFC80000));
      final hsl = HSLColor.fromColor(chrome);
      expect(hsl.lightness, inInclusiveRange(0.16, 0.30));
      // Red hue preserved (allow wrapping around 360/0).
      expect(hsl.hue < 15 || hsl.hue > 345, isTrue);
      expect(chrome.computeLuminance(), lessThan(0.3));
    });

    test('neutral covers stay neutral instead of snapping to a hue', () {
      final chrome = deriveChromeBackground(const Color(0xFFFFFFFF));
      final hsl = HSLColor.fromColor(chrome);
      expect(hsl.saturation, lessThan(0.12));
      expect(hsl.lightness, closeTo(0.30, 0.01));
    });

    test('dark covers yield darker chrome than bright ones', () {
      final dark = deriveChromeBackground(const Color(0xFF10002E));
      final bright = deriveChromeBackground(const Color(0xFFBFA8FF));
      expect(
        HSLColor.fromColor(dark).lightness,
        lessThan(HSLColor.fromColor(bright).lightness),
      );
    });
  });

  group('chromeForeground', () {
    test('white on dark chrome, dark on light chrome', () {
      expect(chromeForeground(const Color(0xFF181818)), Colors.white);
      expect(chromeForeground(const Color(0xFFE0E0E0)), Colors.black87);
    });
  });
}
