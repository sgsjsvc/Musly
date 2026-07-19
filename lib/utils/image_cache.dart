import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageCacheConfig {
  static void configure({bool lowMemoryMode = false}) {
    if (lowMemoryMode) {
      PaintingBinding.instance.imageCache.maximumSize = 10;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 5 << 20; // 5MB
    } else {
      PaintingBinding.instance.imageCache.maximumSize = 15;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 10 << 20; // 10MB
    }
  }
}

class ImagePreloader {

  static Future<void> preloadImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (_) {
          
        }
      }
    }
  }

  static Future<void> preloadImage(
    BuildContext context,
    String imageUrl,
  ) async {
    if (imageUrl.isEmpty) return;

    try {
      await precacheImage(CachedNetworkImageProvider(imageUrl), context);
    } catch (_) {
      
    }
  }
}