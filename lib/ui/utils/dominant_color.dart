import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Dominant-color extraction for the desktop window chrome.
///
/// The Bangumi detail page paints a full-bleed blurred cover behind its
/// content, so a dark/light boolean cannot describe it: the cover's *hue* is
/// what should bleed into the title bar. These helpers derive a single
/// representative color from a cover image and shape it into a chrome
/// background + foreground pair.
///
/// Extraction uses [QuantizerCelebi] plus [Score] from `material_color_utilies`
/// (the same pipeline behind Android's Material You dynamic color): the image
/// is quantized in the perceptually-uniform Lab space, then the colors are
/// ranked by a blend of pixel population, chroma and hue distribution instead
/// of a raw RGB histogram — so noisy covers no longer collapse into a muddled
/// 4096-bucket average.

/// Extracts a representative color from encoded image bytes.
///
/// The image is decoded downscaled (kept cheap for a page backdrop), opaque
/// pixels are quantized with Celebi (16 clusters) and the most suitable color
/// is picked by [Score]. `null` when the bytes cannot be decoded or contain no
/// opaque pixels.
Future<Color?> extractDominantColor(
  Uint8List bytes, {
  int targetSize = 48,
}) async {
  if (bytes.isEmpty) return null;
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetSize,
      targetHeight: targetSize,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (data == null) return null;
    return dominantColorFromRgbaPixels(data, image.width * image.height);
  } catch (_) {
    return null;
  }
}

/// Dominant color over a `rawRgba` pixel buffer (stride 4).
///
/// Opaque pixels become a color-to-count population map, quantized and scored
/// in Lab space. `null` when the buffer contains no usable pixels.
@visibleForTesting
Future<Color?> dominantColorFromRgbaPixels(
  ByteData pixels,
  int pixelCount,
) async {
  final population = <int, int>{};
  for (var i = 0; i < pixelCount; i++) {
    final offset = i * 4;
    final a = pixels.getUint8(offset + 3);
    if (a < 128) continue;
    final r = pixels.getUint8(offset);
    final g = pixels.getUint8(offset + 1);
    final b = pixels.getUint8(offset + 2);
    final argb = (0xFF << 24) | (r << 16) | (g << 8) | b;
    population[argb] = (population[argb] ?? 0) + 1;
  }
  if (population.isEmpty) return null;
  return dominantColorFromPopulation(population);
}

/// Picks the single most suitable color from a population map.
///
/// [QuantizerCelebi] refines the raw color set into up to [maxColors] clusters
/// in Lab space, then [Score] ranks them by population, chroma and hue spread.
@visibleForTesting
Future<Color?> dominantColorFromPopulation(
  Map<int, int> population, {
  int maxColors = 16,
}) async {
  try {
    final pixels = <int>[];
    population.forEach((argb, count) {
      for (var i = 0; i < count && pixels.length < 20000; i++) {
        pixels.add(argb);
      }
    });
    if (pixels.isEmpty) return null;
    final quantized = await QuantizerCelebi().quantize(pixels, maxColors);
    if (quantized.colorToCount.isEmpty) return null;
    final fallback = quantized.colorToCount.entries.reduce(
      (best, candidate) => candidate.value > best.value ? candidate : best,
    );
    final scored = Score.score(
      quantized.colorToCount,
      desired: 1,
      fallbackColorARGB: fallback.key,
    );
    if (scored.isEmpty) return null;
    return Color(scored.first);
  } catch (_) {
    return null;
  }
}

/// Shapes [dominant] into a title-bar background: dark enough for white
/// chrome text, keeping the color's hue so adjacent pages stay distinct.
///
/// Works on the dominant cover color already curated by [Score], mapping it
/// into HCT (a perceptually-uniform color space) and bumping it down to a
/// dark tone band. The tone is scaled from the source tone so dark covers yield
/// a darker chrome than bright ones; chroma is trimmed so a cover with a strong
/// hue never drenches the title bar.
Color deriveChromeBackground(Color dominant) {
  final hct = Hct.fromInt(dominant.toARGB32());
  final tone = (hct.tone * 0.55).clamp(24.0, 38.0);
  final chroma = hct.chroma.clamp(0.0, 64.0);
  return Color(Hct.from(hct.hue, chroma, tone).toInt());
}

/// Foreground for chrome drawn on [background] (window controls, tab text).
Color chromeForeground(Color background) =>
    background.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
