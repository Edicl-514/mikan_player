import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
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

    test('picks the most prominent color', () async {
      final pixels = solidPixels([
        for (var i = 0; i < 80; i++) (200, 30, 30, 255),
        for (var i = 0; i < 16; i++) (10, 10, 200, 255),
      ]);
      final color = await dominantColorFromRgbaPixels(pixels, 96);
      expect(color, isNotNull);
      expect(rOf(color!), greaterThan(150));
      expect(gOf(color), lessThan(80));
      expect(bOf(color), lessThan(80));
    });

    test('skips transparent pixels', () async {
      final pixels = solidPixels([
        (0, 0, 0, 0),
        (0, 0, 0, 0),
        (40, 120, 200, 255),
        (40, 120, 200, 255),
      ]);
      final color = await dominantColorFromRgbaPixels(pixels, 4);
      expect(color, isNotNull);
      expect(rOf(color!), closeTo(40, 20));
      expect(gOf(color), closeTo(120, 20));
      expect(bOf(color), closeTo(200, 20));
    });

    test('returns null when every pixel is transparent', () async {
      final pixels = solidPixels([for (var i = 0; i < 4; i++) (0, 0, 0, 0)]);
      final color = await dominantColorFromRgbaPixels(pixels, 4);
      expect(color, isNull);
    });

    test(
      'keeps a neutral image neutral instead of using Score fallback',
      () async {
        final pixels = solidPixels([
          for (var i = 0; i < 32; i++) (128, 128, 128, 255),
        ]);
        final color = await dominantColorFromRgbaPixels(pixels, 32);
        expect(color, isNotNull);
        expect(Hct.fromInt(color!.toARGB32()).chroma, lessThan(6));
      },
    );
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
      expect(rOf(color!), inInclusiveRange(120, 230));
      expect(gOf(color), inInclusiveRange(40, 120));
      expect(bOf(color), lessThan(90));
    });
  });

  group('deriveChromeBackground', () {
    double hitOf(Color c) => Hct.fromInt(c.toARGB32()).tone;

    test('keeps the hue and darkens for white chrome text', () {
      final chrome = deriveChromeBackground(const Color(0xFFC80000));
      final hsl = HSLColor.fromColor(chrome);
      expect(hitOf(chrome), inInclusiveRange(20, 40));
      // Red hue preserved in sRGB space (allow wrapping around 360/0).
      expect(hsl.hue < 15 || hsl.hue > 345, isTrue);
      expect(chrome.computeLuminance(), lessThan(0.3));
    });

    test('neutral covers stay neutral instead of snapping to a hue', () {
      final chrome = deriveChromeBackground(const Color(0xFFFFFFFF));
      final hct = Hct.fromInt(chrome.toARGB32());
      expect(hct.chroma, lessThan(6));
    });

    test('dark covers yield darker chrome than bright ones', () {
      final dark = deriveChromeBackground(const Color(0xFF10002E));
      final bright = deriveChromeBackground(const Color(0xFFBFA8FF));
      expect(
        Hct.fromInt(dark.toARGB32()).tone,
        lessThan(Hct.fromInt(bright.toARGB32()).tone),
      );
    });

    test('caps chroma so a loud cover never floods the title bar', () {
      final chrome = deriveChromeBackground(const Color(0xFF00FF00));
      final hct = Hct.fromInt(chrome.toARGB32());
      expect(hct.chroma, lessThanOrEqualTo(64));
    });
  });

  group('chromeForeground', () {
    test('white on dark chrome, dark on light chrome', () {
      expect(chromeForeground(const Color(0xFF181818)), Colors.white);
      expect(chromeForeground(const Color(0xFFE0E0E0)), Colors.black87);
    });
  });
}
