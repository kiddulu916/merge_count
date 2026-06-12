import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Rasterises a rendered card widget to PNG bytes (Phase 3 richer share card).
///
/// Capture is isolated behind this seam — exactly like [ScoreSharer] isolates
/// the share transport — so the [share_card] widget stays "testable by eye" in
/// the running app while the byte pipeline stays mockable in tests. Callers feed
/// the resulting PNG to the existing `ScoreSharer`.
abstract class ShareCardRenderer {
  const ShareCardRenderer();

  /// Capture the [RepaintBoundary] behind [boundaryContext] as PNG bytes, or
  /// null when the boundary isn't laid out yet / capture fails. Production
  /// renders the on-screen card; tests inject [FakeShareCardRenderer].
  Future<Uint8List?> capture(BuildContext boundaryContext);
}

/// Production renderer: `RenderRepaintBoundary.toImage` → PNG (mirrors the
/// prior inline `_capture` in `score_share_screen`).
class RepaintBoundaryShareCardRenderer extends ShareCardRenderer {
  /// Device-pixel multiplier for crisp text on the shared image.
  final double pixelRatio;

  const RepaintBoundaryShareCardRenderer({this.pixelRatio = 3.0});

  @override
  Future<Uint8List?> capture(BuildContext boundaryContext) async {
    final obj = boundaryContext.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    // If the boundary still needs paint, capturing now would throw / produce a
    // stale frame — bail so the caller can fall back to the text share.
    if (obj.debugNeedsPaint) return null;
    try {
      final image = await obj.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

/// Test renderer: returns canned bytes (or null) without touching the GPU, so
/// the share pipeline + fallback logic can be unit-tested headlessly.
class FakeShareCardRenderer extends ShareCardRenderer {
  final Uint8List? bytes;

  const FakeShareCardRenderer(this.bytes);

  @override
  Future<Uint8List?> capture(BuildContext boundaryContext) async => bytes;
}
