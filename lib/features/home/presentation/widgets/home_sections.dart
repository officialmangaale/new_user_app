import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/premium_components.dart';
import '../../../../shared/models/app_models.dart';
import '../../../../shared/formatting/distance_format.dart';
import '../../../catalog/presentation/menu/menu_image.dart';
import '../../../catalog/presentation/menu/menu_styles.dart';

/// Section title with an optional "View all" link (deep teal, 48px tall).
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    required this.title,
    this.trailingText,
    this.onViewAll,
    super.key,
  });

  final String title;

  /// Muted note shown beside the title, e.g. "12 open now".
  final String? trailingText;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                if (trailingText != null && trailingText!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      trailingText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.deepTeal,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.only(left: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A quick filter the home feed applies to the loaded restaurants.
class HomeFilterOption {
  const HomeFilterOption(this.id, this.label, this.test);

  final String id;
  final String label;
  final bool Function(Restaurant restaurant) test;
}

/// The filters the home feed understands. All run client-side on the loaded
/// list; "Pure veg" is absent because restaurant records carry no veg flag.
final List<HomeFilterOption> kHomeFilters = [
  HomeFilterOption('rating', 'Rating 4.0+', (r) => r.rating >= 4.0),
  HomeFilterOption(
    'fast',
    'Under 30 min',
    (r) => r.deliveryMinutes > 0 && r.deliveryMinutes <= 30,
  ),
  HomeFilterOption('offers', 'Offers', (r) => r.displayOffer.isNotEmpty),
  HomeFilterOption(
    'cheap',
    'Under ₹200',
    (r) => r.costForTwo > 0 && r.costForTwo <= 200,
  ),
];

class HomeFilterChips extends StatelessWidget {
  const HomeFilterChips({
    required this.options,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final List<HomeFilterOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final on = selected.contains(option.id);
          return Center(
            child: Semantics(
              button: true,
              selected: on,
              label: option.label,
              excludeSemantics: true,
              child: Material(
                color: on ? AppColors.primary : AppColors.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: on ? AppColors.primary : AppColors.hairline,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onToggle(option.id),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text(
                      option.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "What's on your mind?" rail.
class HomeCategoryRail extends StatelessWidget {
  const HomeCategoryRail({
    required this.categories,
    required this.selectedKey,
    required this.onTap,
    super.key,
  });

  final List<HomeCategory> categories;
  final String selectedKey;
  final ValueChanged<HomeCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.key == selectedKey;
          final isAll = category.key == '__all__';
          return Semantics(
            button: true,
            selected: selected,
            label: category.name,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(category),
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isAll ? AppColors.mint : Colors.white,
                        border: selected
                            ? Border.all(color: AppColors.primary, width: 2.5)
                            : null,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140B2E2C),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: isAll
                            ? const Center(
                                child: Icon(
                                  Icons.grid_view_rounded,
                                  size: 26,
                                  color: AppColors.deepTeal,
                                ),
                              )
                            : category.imageUrl.isNotEmpty
                            ? MenuImage(
                                url: category.imageUrl,
                                width: 62,
                                height: 62,
                              )
                            : Center(
                                child: Icon(
                                  PremiumCategoryTile.categoryIcon(
                                    category.icon,
                                  ),
                                  size: 26,
                                  color: AppColors.deepTeal,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Green rating chip, or "New" when the restaurant has no rating yet.
class RatingChip extends StatelessWidget {
  const RatingChip({required this.rating, super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final isNew = rating <= 0;
    return Semantics(
      label: isNew ? 'New restaurant' : 'Rated $rating out of 5',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.vegGreen,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isNew) ...[
              const Icon(Icons.star_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 2),
            ],
            Text(
              isNew ? 'New' : rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 164px "Popular near you" card.
class PopularRestaurantCard extends StatelessWidget {
  const PopularRestaurantCard({
    required this.restaurant,
    required this.onTap,
    super.key,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final closed = r.isOpen == false;
    return Semantics(
      button: true,
      label: '${r.name}${closed ? ', closed' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 164,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _Greyable(
                  grey: closed,
                  child: MenuImage(
                    url: r.displayCoverUrl,
                    width: 164,
                    height: 116,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  RatingChip(rating: r.rating),
                  if (r.deliveryMinutes > 0) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${r.deliveryMinutes} min',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width restaurant card for "All restaurants".
class HomeRestaurantCard extends StatelessWidget {
  const HomeRestaurantCard({
    required this.restaurant,
    required this.onTap,
    this.favourite,
    this.onFavourite,
    super.key,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  /// `null` hides the heart (guests have no favourites).
  final bool? favourite;
  final VoidCallback? onFavourite;

  String _meta() {
    final r = restaurant;
    // Null (not 0) when the distance is unknown: the card then shows no
    // distance at all rather than claiming the restaurant is at the door.
    final distance = formatDistanceKm(r.distanceKm) ?? '';
    return [
      if (r.deliveryMinutes > 0) '${r.deliveryMinutes} min',
      if (distance.isNotEmpty) distance,
      if (r.costForTwo > 0) '${rupees(r.costForTwo)} for two',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final closed = r.isOpen == false;
    final offer = r.displayOffer;
    final meta = _meta();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B2E2C),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Semantics(
              button: true,
              label:
                  '${r.name}${closed ? ', closed' : ''}'
                  '${r.cuisine.isEmpty ? '' : ', ${r.cuisine}'}',
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 170,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Greyable(
                            grey: closed,
                            child: MenuImage(url: r.displayCoverUrl),
                          ),
                          if (offer.isNotEmpty && !closed)
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: _CoralBadge(text: offer),
                            ),
                          if (closed)
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: _ClosedBadge(opensAt: r.opensAt),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LogoBadge(name: r.name, logoUrl: r.logoUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          height: 1.3,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    RatingChip(rating: r.rating),
                                  ],
                                ),
                                if (r.cuisine.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      r.cuisine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ),
                                if (meta.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      meta,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (favourite != null)
              Positioned(
                right: 8,
                top: 8,
                child: Semantics(
                  button: true,
                  label: favourite!
                      ? 'Remove ${r.name} from favourites'
                      : 'Save ${r.name} to favourites',
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onFavourite,
                      // 36px circle with a 44px hit area.
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            favourite!
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: favourite! ? AppColors.error : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Greyable extends StatelessWidget {
  const _Greyable({required this.grey, required this.child});

  final bool grey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!grey) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 0.7, 0,
      ]),
      child: child,
    );
  }
}

class _CoralBadge extends StatelessWidget {
  const _CoralBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _ClosedBadge extends StatelessWidget {
  const _ClosedBadge({required this.opensAt});

  final String opensAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        opensAt.isEmpty
            ? 'Closed'
            : 'Closed · Opens at ${friendlyTime(opensAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.name, required this.logoUrl});

  final String name;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: logoUrl.isEmpty
          ? Center(
              child: Text(
                initials.isEmpty ? '·' : initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MenuImage(
                url: logoUrl,
                fit: BoxFit.contain,
                semanticLabel: '$name logo',
              ),
            ),
    );
  }
}
