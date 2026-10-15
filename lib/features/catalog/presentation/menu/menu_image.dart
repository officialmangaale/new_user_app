import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Network image with a mint placeholder. Failures and missing URLs fall back
/// to the same quiet tile, never a broken-image glyph.
class MenuImage extends StatelessWidget {
  const MenuImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.mint,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_outlined,
        color: AppColors.deepTeal,
        size: 28,
      ),
    );
    if (url.trim().isEmpty) return placeholder;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, _) =>
            Container(width: width, height: height, color: AppColors.mint),
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
