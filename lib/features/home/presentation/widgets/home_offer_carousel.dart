import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/app_models.dart';
import '../../../catalog/presentation/menu/menu_image.dart';

/// What the carousel shows for one banner, resolved from real data.
class OfferBannerData {
  const OfferBannerData({
    required this.banner,
    required this.headline,
    required this.restaurantLine,
  });

  final HomeBanner banner;

  /// The offer text; empty means "no offer", so the OFFER tag is hidden.
  final String headline;

  /// "at Bite Hut · Cafe", or empty when the restaurant is unknown.
  final String restaurantLine;
}

/// Resolves banners against the loaded restaurants so the restaurant name is
/// shown exactly as stored. Banners with nothing to say are dropped.
List<OfferBannerData> resolveOfferBanners(
  List<HomeBanner> banners,
  List<Restaurant> restaurants,
) {
  final byId = {for (final r in restaurants) r.id: r};
  final out = <OfferBannerData>[];
  for (final banner in banners) {
    final restaurant = byId[banner.restaurantId];
    final headline = _clean(banner.title);
    final name = restaurant != null
        ? _clean(restaurant.name)
        : _clean(banner.subtitle);
    final kind = restaurant == null ? '' : _firstCuisine(restaurant.cuisine);
    if (headline.isEmpty && name.isEmpty) continue;
    out.add(
      OfferBannerData(
        banner: banner,
        headline: headline.isEmpty ? name : headline,
        restaurantLine: name.isEmpty || headline.isEmpty
            ? ''
            : 'at $name${kind.isEmpty ? '' : ' · $kind'}',
      ),
    );
  }
  return out;
}

String _clean(String raw) {
  final value = raw.trim();
  return value.toLowerCase() == 'null' ? '' : value;
}

String _firstCuisine(String cuisine) {
  final first = cuisine.split(RegExp(r'[,·]')).first.trim();
  return first;
}

class HomeOfferCarousel extends StatefulWidget {
  const HomeOfferCarousel({
    required this.banners,
    required this.onOpen,
    super.key,
  });

  final List<OfferBannerData> banners;
  final ValueChanged<HomeBanner> onOpen;

  @override
  State<HomeOfferCarousel> createState() => _HomeOfferCarouselState();
}

class _HomeOfferCarouselState extends State<HomeOfferCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _OfferCard(
                data: banners[index],
                onTap: () => widget.onOpen(banners[index].banner),
              ),
            ),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.deepTeal
                        : AppColors.onInkMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.data, required this.onTap});

  final OfferBannerData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasOffer =
        data.banner.title.trim().isNotEmpty &&
        data.banner.title.trim().toLowerCase() != 'null';
    final cta = data.banner.ctaText.trim().isEmpty
        ? 'Order now'
        : data.banner.ctaText.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: AppColors.ink,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasOffer)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OFFER',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    if (hasOffer) const SizedBox(height: 6),
                    Text(
                      data.headline,
                      maxLines: MediaQuery.textScalerOf(context).scale(1) > 1.3
                          ? 1
                          : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (data.restaurantLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.restaurantLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onInkMuted,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: '$cta. ${data.headline}',
                      excludeSemantics: true,
                      child: Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 38,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              maxWidth: 160,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    cta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.ink,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 140,
              height: double.infinity,
              child: ExcludeSemantics(
                child: MenuImage(url: data.banner.imageUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
