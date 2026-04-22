import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'share_helper_stub.dart'
    if (dart.library.html) 'share_helper_web.dart';

class ShareHelper {
  /// Captures a widget as an image and shares it.
  /// The widget must be wrapped in a [RepaintBoundary] with the provided [key].
  static Future<void> shareWidgetAsImage({
    required GlobalKey key,
    required String text,
    required String fileName,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('RepaintBoundary not found for key: $key');
        return;
      }

      // Higher pixelRatio for better quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();

      if (key.currentContext != null) {
        ScaffoldMessenger.of(key.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Preparing your achievement image... ✨'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // On Web, we try to share, but fall back to download if the Share API is not supported
      if (kIsWeb) {
        try {
          await SharePlus.instance.share(ShareParams(
            text: text,
            files: [
              XFile.fromData(bytes,
                  name: '$fileName.png', mimeType: 'image/png'),
            ],
          ));
        } catch (e) {
          debugPrint('Web share failed, falling back to download: $e');
          downloadBytesWeb(bytes, '$fileName.png');
        }
      } else {
        // On Mobile/Desktop
        await SharePlus.instance.share(ShareParams(
          text: text,
          files: [
            XFile.fromData(bytes, name: '$fileName.png', mimeType: 'image/png'),
          ],
        ));
      }
    } catch (e) {
      debugPrint('Error sharing widget as image: $e');
    }
  }
}
