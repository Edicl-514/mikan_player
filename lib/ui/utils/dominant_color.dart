import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Dominant-color extraction for the desktop window chrome.
///
/// The Bangumi detail page paints a full-bleed blurred cover behind its
/// content, so a dark/light boolean cannot describe it: the cover's *hue* is
/// what should bleed into the title bar. These helpers derive a single
/// representative color from a cover image and shape it into a chrome
/// background + foreground pair.

/// Extracts a representative color from encoded image bytes.
///
/// The image is decoded downscaled (kept cheap for a page backdrop) and the
/// most-populated color bucket is returned. `null` when the bytes cannot be
/// decoded or contain no opaque pixels.
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

/// Representative color over a `rawRgba` pixel buffer (stride 4).
///
/// Pixels are coarsely quantized into a histogram; the average of the winning
/// bucket is the dominant color. When no bucket dominates (a noisy or highly
/// varied image), the per-channel mean is used instead so the result never
/// comes from a 2%-of-image outlier.
@visibleForTesting
Color dominantColorFromRgbaPixels(ByteData pixels, int pixelCount) {
  const bucketShift = 4; // 16 levels per channel -> 4096 buckets.
  final counts = Int32List(1 << 12);
  final sumR = Int32List(1 << 12);
  final sumG = Int32List(1 << 12);
  final sumB = Int32List(1 << 12);

  var validCount = 0;
  var meanR = 0, meanG = 0, meanB = 0;

  for (var i = 0; i < pixelCount; i++) {
    final offset = i * 4;
    final r = pixels.getUint8(offset);
    final g = pixels.getUint8(offset + 1);
    final b = pixels.getUint8(offset + 2);
    final a = pixels.getUint8(offset + 3);
    if (a < 128) continue;

    meanR += r;
    meanG += g;
    meanB += b;
    validCount++;

    final bucket =
        ((r >> bucketShift) << 8) | ((g >> bucketShift) << 4) | (b >> bucketShift);
    counts[bucket]++;
    sumR[bucket] += r;
    sumG[bucket] += g;
    sumB[bucket] += b;
  }

  if (validCount == 0) return const Color(0xff121212);

  var bestBucket = -1;
  var bestCount = 0;
  var secondCount = 0;
  for (var i = 0; i < counts.length; i++) {
    final count = counts[i];
    if (count > bestCount) {
      secondCount = bestCount;
      bestCount = count;
      bestBucket = i;
    } else if (count > secondCount) {
      secondCount = count;
    }
  }

  final mean = Color.fromARGB(
    255,
    (meanR / validCount).round(),
    (meanG / validCount).round(),
    (meanB / validCount).round(),
  );
  // Require a clear plurality: a dominant bucket must hold a meaningful share
  // and beat the runner-up by a comfortable margin. Otherwise the image has no
  // single color and the per-channel mean is the honest answer.
  final clearWinner =
      bestBucket >= 0 &&
      bestCount >= validCount * 0.05 &&
      bestCount > secondCount * 1.5;
  if (!clearWinner) return mean;

  return Color.fromARGB(
    255,
    (sumR[bestBucket] / bestCount).round(),
    (sumG[bestBucket] / bestCount).round(),
    (sumB[bestBucket] / bestCount).round(),
  );
}

/// Shapes [dominant] into a title-bar background: dark enough for white
/// chrome text, keeping the cover's hue so adjacent pages stay distinct.
///
/// Neutral covers (no saturation to speak of) stay neutral instead of snapping
/// to an arbitrary hue; dark covers yield a darker chrome than bright ones.
Color deriveChromeBackground(Color dominant) {
  final hsl = HSLColor.fromColor(dominant);
  final saturation =
      hsl.saturation < 0.12 ? hsl.saturation : hsl.saturation.clamp(0.25, 0.80);
  final lightness = (hsl.lightness * 0.55).clamp(0.16, 0.30);
  return hsl.withLightness(lightness).withSaturation(saturation).toColor();
}

/// Foreground for chrome drawn on [background] (window controls, tab text).
Color chromeForeground(Color background) =>
    background.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
