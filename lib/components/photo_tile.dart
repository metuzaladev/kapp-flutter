import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'icon.dart';

/// Image cache key for a signed photo URL: the URL without its signature (the object path). Object
/// keys contain the photo id and never change, while the signature does on every fetch — keying by
/// the full URL would download the same image again and again.
String photoCacheKey(String url) => url.split('?').first;

/// A signed network photo cached by object path.
class SignedImage extends StatelessWidget {
  const SignedImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height});
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: url,
    cacheKey: photoCacheKey(url),
    fit: fit,
    width: width,
    height: height,
    fadeInDuration: const Duration(milliseconds: 150),
    errorWidget: (_, _, _) => const SizedBox.shrink(),
  );
}

/// Rounded-square photo of a dog (or person), the M9 replacement for round avatars (Figma List Row
/// photo, Park Card faces, Map Pin / Dog). Without a photo: the initial on the soft accent colour,
/// or a paw when there is no name. Decorative: the name is always next to it.
class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, this.url, this.asset, this.name, this.size = 44, this.radius, this.border});

  /// Signed thumbnail URL (M4 dog profile photo).
  final String? url;

  /// A bundled image (sample illustrations only).
  final String? asset;
  final String? name;

  /// Figma: 44 (list rows), 26 (park card faces), 48/56 (map pins).
  final double size;

  /// Figma radius: 14 for 44, 8 for 26. Defaults to ~32 % of the size.
  final double? radius;
  final ({double width, Color color})? border;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = radius ?? (size * 0.32).roundToDouble();
    final initial = name?.trim().isNotEmpty == true ? name!.trim()[0].toUpperCase() : null;
    Widget content;
    if (url != null) {
      content = SignedImage(url!, width: size, height: size);
    } else if (asset != null) {
      content = Image.asset(asset!, width: size, height: size, fit: BoxFit.cover);
    } else if (initial != null) {
      content = Center(
        child: Text(initial, style: textStyle(size >= 40 ? TextType.heading : TextType.micro, color: c.accent)),
      );
    } else {
      content = Center(
        child: AppIcon(IconName.pawPrint, size: (size * 0.45).roundToDouble(), color: c.brand),
      );
    }
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.soft,
          borderRadius: BorderRadius.circular(r),
          border: border == null ? null : Border.all(color: border!.color, width: border!.width),
        ),
        child: content,
      ),
    );
  }
}
