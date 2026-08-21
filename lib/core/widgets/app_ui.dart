import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/models/app_models.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.semanticLabel,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Semantics(
        image: true,
        label: semanticLabel,
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 220),
          placeholder: (_, _) => Container(
            width: width,
            height: height,
            color: AppColors.primaryVeryLight,
            alignment: Alignment.center,
            child: const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            width: width,
            height: height,
            color: AppColors.primaryVeryLight,
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.outlined = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool outlined;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
    void handlePress() {
      HapticFeedback.selectionClick();
      onPressed?.call();
    }

    final action = loading || onPressed == null ? null : handlePress;
    final button = outlined
        ? OutlinedButton(onPressed: action, child: child)
        : FilledButton(onPressed: action, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    required this.hint,
    this.onTap,
    this.onChanged,
    super.key,
  });

  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        onTap: onTap,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        decoration: const InputDecoration().copyWith(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 22),
          suffixIcon: const Icon(
            Icons.tune_rounded,
            size: 21,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class LocationHeader extends StatelessWidget {
  const LocationHeader({
    this.grocery = false,
    this.locationLabel,
    this.deliveryLabel,
    this.onNotifications,
    super.key,
  });

  final bool grocery;
  final String? locationLabel;
  final String? deliveryLabel;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.light,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on_rounded, color: AppColors.dark),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deliveryLabel ??
                    (grocery ? 'Grocery delivery' : 'Delivering to'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: grocery ? AppColors.dark : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      locationLabel ?? 'Use current location',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                ],
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filledTonal(
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const Positioned(
              right: 9,
              top: 7,
              child: CircleAvatar(radius: 4, backgroundColor: AppColors.error),
            ),
          ],
        ),
      ],
    );
  }
}

class DeliveryModeSwitch extends StatelessWidget {
  const DeliveryModeSwitch({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final DeliveryMode mode;
  final ValueChanged<DeliveryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: DeliveryMode.values.map((item) {
          final selected = item == mode;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item == DeliveryMode.food
                            ? Icons.restaurant_rounded
                            : Icons.local_grocery_store_rounded,
                        size: 19,
                        color: selected
                            ? AppColors.dark
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        item == DeliveryMode.food ? 'Food' : 'Grocery',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AppColors.dark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.onViewAll,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}

class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    this.icon,
    this.background = AppColors.light,
    this.foreground = AppColors.dark,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuantityControl extends StatelessWidget {
  const QuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.compact = false,
    super.key,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = quantity == 0
        ? SizedBox(
            key: const ValueKey('add'),
            height: compact ? 38 : 44,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onAdd();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(compact ? 72 : 88, compact ? 38 : 44),
                padding: const EdgeInsets.symmetric(horizontal: 13),
              ),
              child: const Text('ADD'),
            ),
          )
        : Container(
            key: const ValueKey('quantity'),
            height: compact ? 38 : 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuantityButton(
                  icon: Icons.remove,
                  onTap: onRemove,
                  compact: compact,
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _QuantityButton(
                  icon: Icons.add,
                  onTap: onAdd,
                  compact: compact,
                ),
              ],
            ),
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: child,
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: BoxConstraints.tightFor(
        width: compact ? 34 : 40,
        height: compact ? 38 : 44,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.light,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: AppColors.dark),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key});

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.8).animate(_controller),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => Container(
          height: 116,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({this.offline = false, this.onRetry, super.key});

  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
      title: offline ? 'You’re offline' : 'Something went wrong',
      message: offline
          ? 'Check your connection and try again.'
          : 'We couldn’t load this content right now.',
      action: AppButton(label: 'Try again', onPressed: onRetry, expand: false),
    );
  }
}
