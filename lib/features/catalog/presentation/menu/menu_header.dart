import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../../../shared/formatting/distance_format.dart';
import 'menu_image.dart';
import 'menu_styles.dart';
import 'veg_mark.dart';

/// Height of the cover banner, excluding the status-bar inset.
const double kMenuBannerHeight = 210;

/// Height of the sticky bar that replaces the banner once it scrolls away.
const double kMenuCollapsedBarHeight = 60;

const double _kCardOverlap = 28;
const double _kLogoSize = 88;

/// Cover banner with the info card overlapping its bottom edge and the
/// restaurant logo badge straddling that edge.
///
/// Everything comes from [restaurant]; no colour is derived from its images.
class MenuHeader extends StatelessWidget {
  const MenuHeader({
    required this.restaurant,
    required this.topInset,
    required this.onBack,
    this.onFavourite,
    this.onShare,
    this.onFoodShare,
    super.key,
  });

  final Restaurant restaurant;
  final double topInset;
  final VoidCallback onBack;
  final VoidCallback? onFavourite;
  final VoidCallback? onShare;
  final VoidCallback? onFoodShare;

  @override
  Widget build(BuildContext context) {
    final bannerHeight = kMenuBannerHeight + topInset;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: bannerHeight,
          width: double.infinity,
          child: _Banner(
            restaurant: restaurant,
            topInset: topInset,
            onBack: onBack,
            onFavourite: onFavourite,
            onShare: onShare,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, bannerHeight - _kCardOverlap, 16, 0),
          child: MenuInfoCard(restaurant: restaurant, onFoodShare: onFoodShare),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.restaurant,
    required this.topInset,
    required this.onBack,
    required this.onFavourite,
    required this.onShare,
  });

  final Restaurant restaurant;
  final double topInset;
  final VoidCallback onBack;
  final VoidCallback? onFavourite;
  final VoidCallback? onShare;

  /// Cover photo; falls back to the single legacy image when it is not the
  /// logo, otherwise a solid ink banner.
  String get _coverUrl {
    if (restaurant.coverUrl.isNotEmpty) return restaurant.coverUrl;
    if (restaurant.imageUrl.isNotEmpty &&
        restaurant.imageUrl != restaurant.logoUrl) {
      return restaurant.imageUrl;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cover = _coverUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.ink),
        if (cover.isNotEmpty)
          ExcludeSemantics(
            child: MenuImage(url: cover, fit: BoxFit.cover),
          ),
        // Keeps the round buttons legible on any photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x73000000), Color(0x00000000), Color(0x40000000)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: topInset + 8,
          child: Row(
            children: [
              MenuRoundButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back',
                onPressed: onBack,
              ),
              const Spacer(),
              MenuRoundButton(
                icon: Icons.favorite_border_rounded,
                label: 'Save restaurant',
                onPressed: onFavourite,
              ),
              const SizedBox(width: 8),
              MenuRoundButton(
                icon: Icons.ios_share_rounded,
                label: 'Share restaurant',
                onPressed: onShare,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 44x44 round icon button with a translucent white background.
class MenuRoundButton extends StatelessWidget {
  const MenuRoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.plain = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// No background, for use on the white collapsed bar.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: plain ? Colors.transparent : const Color(0xE6FFFFFF),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// White badge showing the logo uncropped, or the initials when there is none.
class MenuLogoBadge extends StatelessWidget {
  const MenuLogoBadge({required this.name, required this.logoUrl, super.key});

  final String name;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    final fallback = Center(
      child: Text(
        initials.isEmpty ? '·' : initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.deepTeal,
        ),
      ),
    );
    return Container(
      width: _kLogoSize,
      height: _kLogoSize,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x290B2E2C),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: logoUrl.isEmpty
          ? fallback
          : Semantics(
              image: true,
              label: '$name logo',
              child: MenuImage(
                url: logoUrl,
                fit: BoxFit.contain,
                semanticLabel: '$name logo',
              ),
            ),
    );
  }
}

/// Name, cuisine, rating, meta row, and the offer / closed / FoodShare strips.
class MenuInfoCard extends StatelessWidget {
  const MenuInfoCard({required this.restaurant, this.onFoodShare, super.key});

  final Restaurant restaurant;
  final VoidCallback? onFoodShare;

  List<_MetaItem> _meta() {
    final r = restaurant;
    final distance = formatDistanceKm(r.distanceKm);
    return [
      if (r.deliveryMinutes > 0)
        _MetaItem(Icons.schedule_outlined, '${r.deliveryMinutes} min'),
      if (distance != null || r.area.isNotEmpty)
        _MetaItem(
          Icons.near_me_outlined,
          [
            ?distance,
            if (r.area.isNotEmpty) r.area,
          ].join(' · '),
        ),
      if (r.costForTwo > 0)
        _MetaItem(Icons.payments_outlined, '${rupees(r.costForTwo)} for two'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final meta = _meta();
    final offer = r.offerText.isNotEmpty
        ? r.offerText
        : (r.discount > 0 ? '${r.discount}% OFF' : '');
    final closed = r.isOpen == false;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B2E2C),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  // Clears the lower half of the logo badge.
                  constraints: const BoxConstraints(minHeight: 58),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: _kLogoSize + 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: MenuText.restaurantName,
                            ),
                            if (r.cuisine.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                r.cuisine,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: MenuText.meta,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RatingBadge(rating: r.rating),
                    ],
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const DashedDivider(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [for (final item in meta) _MetaChip(item: item)],
                  ),
                ],
                if (closed) ...[
                  const SizedBox(height: 12),
                  _Strip(
                    icon: Icons.schedule_outlined,
                    background: AppColors.errorLight,
                    iconColor: AppColors.error,
                    text: r.opensAt.isEmpty
                        ? 'Currently closed'
                        : 'Currently closed · Opens at ${friendlyTime(r.opensAt)}',
                  ),
                ],
                if (offer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Strip(
                    icon: Icons.local_offer_outlined,
                    background: AppColors.coral,
                    iconColor: AppColors.ink,
                    text: offer,
                  ),
                ],
                if (r.foodShare) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onFoodShare,
                    child: const _Strip(
                      icon: Icons.people_alt_outlined,
                      background: AppColors.mint,
                      iconColor: AppColors.deepTeal,
                      text: 'FoodShare available',
                      trailing: Icons.chevron_right_rounded,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 14,
            top: -16,
            child: MenuLogoBadge(name: r.name, logoUrl: r.logoUrl),
          ),
        ],
      ),
    );
  }
}

class _MetaItem {
  const _MetaItem(this.icon, this.text);

  final IconData icon;
  final String text;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.item});

  final _MetaItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 16, color: AppColors.deepTeal),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            item.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MenuText.meta.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final isNew = rating <= 0;
    return Semantics(
      label: isNew ? 'New restaurant' : 'Rated $rating out of 5',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isNew ? AppColors.mint : AppColors.vegGreen,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isNew
            ? const Text(
                'New',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepTeal,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.star_rounded, size: 15, color: Colors.white),
                ],
              ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;
  final String text;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          if (trailing != null)
            Icon(trailing, size: 20, color: AppColors.deepTeal),
        ],
      ),
    );
  }
}

/// White 60px bar shown once the banner has scrolled away.
class MenuCollapsedBar extends StatelessWidget {
  const MenuCollapsedBar({
    required this.restaurant,
    required this.topInset,
    required this.onBack,
    required this.onSearch,
    this.onFavourite,
    super.key,
  });

  final Restaurant restaurant;
  final double topInset;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback? onFavourite;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final sub = [
      if (r.deliveryMinutes > 0) '${r.deliveryMinutes} min',
      if (r.area.isNotEmpty) r.area,
    ].join(' · ');
    return Container(
      height: kMenuCollapsedBarHeight + topInset,
      padding: EdgeInsets.fromLTRB(8, topInset, 8, 0),
      color: AppColors.surface,
      child: Row(
        children: [
          MenuRoundButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onPressed: onBack,
            plain: true,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MenuText.meta.copyWith(fontSize: 12),
                  ),
              ],
            ),
          ),
          MenuRoundButton(
            icon: Icons.search_rounded,
            label: 'Search dishes',
            onPressed: onSearch,
            plain: true,
          ),
          MenuRoundButton(
            icon: Icons.favorite_border_rounded,
            label: 'Save restaurant',
            onPressed: onFavourite,
            plain: true,
          ),
        ],
      ),
    );
  }
}
