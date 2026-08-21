import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/models/app_models.dart';
import 'app_ui.dart';

class PremiumSurface extends StatelessWidget {
  const PremiumSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.radius = 18,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AppLocationHeader extends StatelessWidget {
  const AppLocationHeader({
    required this.mode,
    this.deliveryLabel,
    this.locationLabel,
    this.onLocationTap,
    this.onNotifications,
    super.key,
  });

  final DeliveryMode mode;
  final String? deliveryLabel;
  final String? locationLabel;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final grocery = mode == DeliveryMode.grocery;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Change delivery location',
            child: InkWell(
              onTap: onLocationTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deliveryLabel ??
                          (grocery ? 'GROCERY DELIVERY' : 'DELIVERING TO'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 0,
                        color: grocery
                            ? AppColors.primaryDark
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            locationLabel ?? 'Use current location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            AppIconAction(
              tooltip: 'Notifications',
              icon: Icons.notifications_none_rounded,
              onPressed: onNotifications,
            ),
            const Positioned(
              right: 6,
              top: 5,
              child: CircleAvatar(radius: 4, backgroundColor: AppColors.error),
            ),
          ],
        ),
      ],
    );
  }
}

class AppIconAction extends StatelessWidget {
  const AppIconAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.translucent = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        backgroundColor: translucent
            ? Colors.white.withValues(alpha: 0.88)
            : AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        side: translucent
            ? BorderSide.none
            : const BorderSide(color: AppColors.border),
        shadowColor: AppColors.shadow,
        elevation: translucent ? 1 : 0,
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

class PremiumCategoryTile extends StatelessWidget {
  const PremiumCategoryTile({
    required this.label,
    this.iconKey = '',
    this.imageUrl = '',
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String iconKey;

  /// Category artwork from the backend. Falls back to [iconKey] when empty or
  /// when the image fails to load, so the rail never renders a blank tile.
  final String imageUrl;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label category',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap?.call();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.primaryVeryLight,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? Icon(
                        categoryIcon(iconKey),
                        size: 34,
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                      )
                    : AppNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        semanticLabel: label,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData categoryIcon(String key) {
    return switch (key) {
      'rice' => Icons.rice_bowl_rounded,
      'pizza' => Icons.local_pizza_outlined,
      'burger' => Icons.lunch_dining_outlined,
      'indian' => Icons.soup_kitchen_outlined,
      'noodles' => Icons.ramen_dining_outlined,
      'healthy' => Icons.eco_outlined,
      'dessert' => Icons.cake_outlined,
      'fruit' => Icons.eco_outlined,
      'vegetable' => Icons.grass_rounded,
      'dairy' => Icons.water_drop_outlined,
      'snack' => Icons.cookie_outlined,
      'bakery' => Icons.bakery_dining_outlined,
      'household' => Icons.cleaning_services_outlined,
      'personal' => Icons.spa_outlined,
      'frozen' => Icons.ac_unit_rounded,
      'baby' => Icons.child_care_outlined,
      _ => Icons.local_cafe_outlined,
    };
  }
}

class PremiumFeatureBanner extends StatelessWidget {
  const PremiumFeatureBanner({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 1.8).clamp(184.0, 220.0);
        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.featureDark),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 150,
                  child: AppNetworkImage(
                    url: imageUrl,
                    semanticLabel: 'Featured delivery collection',
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.featureDark,
                        AppColors.featureDark.withValues(alpha: 0.94),
                        AppColors.featureDark.withValues(alpha: 0.08),
                      ],
                      stops: const [0, 0.58, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.ml),
                  child: FractionallySizedBox(
                    widthFactor: 0.7,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.white, fontSize: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFD5F2ED)),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: onAction,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryDark,
                              minimumSize: const Size(44, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: Text(actionLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BenefitRow extends StatelessWidget {
  const BenefitRow({
    required this.icon,
    required this.label,
    this.stacked = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class WelcomeHeroComposition extends StatelessWidget {
  const WelcomeHeroComposition({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: compact ? 2 : 1.36,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryVeryLight,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DeliveryRoutePainter()),
            ),
            const Positioned(
              left: 18,
              top: 18,
              child: _HeroImageCard(
                label: 'Dinner',
                icon: Icons.restaurant_rounded,
                imageUrl:
                    'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=500',
              ),
            ),
            const Positioned(
              right: 18,
              bottom: 18,
              child: _HeroImageCard(
                label: 'Essentials',
                icon: Icons.shopping_basket_rounded,
                imageUrl:
                    'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500',
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadow, blurRadius: 14),
                    ],
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 16,
              top: 18,
              child: AppPill(
                label: 'Save ₹72 together',
                icon: Icons.savings_outlined,
                background: AppColors.surface,
                foreground: AppColors.primaryDark,
              ),
            ),
            const Positioned(left: 20, bottom: 20, child: _MiniAvatarStack()),
          ],
        ),
      ),
    );
  }
}

class _HeroImageCard extends StatelessWidget {
  const _HeroImageCard({
    required this.label,
    required this.icon,
    required this.imageUrl,
  });

  final String label;
  final IconData icon;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 104,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12)],
      ),
      child: Column(
        children: [
          Expanded(
            child: AppNetworkImage(
              url: imageUrl,
              borderRadius: 14,
              width: double.infinity,
              semanticLabel: label,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.primaryDark),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAvatarStack extends StatelessWidget {
  const _MiniAvatarStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 34,
      child: Stack(
        children: List.generate(3, (index) {
          return Positioned(
            left: index * 22,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: const [
                  Color(0xFFDDEBFF),
                  Color(0xFFFFE0EE),
                  AppColors.primaryLight,
                ][index],
                child: Text(
                  const ['M', 'K', 'N'][index],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DeliveryRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.28)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(95, 90)
      ..cubicTo(
        size.width * 0.42,
        18,
        size.width * 0.6,
        size.height - 22,
        size.width - 90,
        size.height - 68,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
