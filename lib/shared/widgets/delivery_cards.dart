import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/widgets/app_ui.dart';
import '../models/app_models.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    required this.restaurant,
    this.onTap,
    this.width = 275,
    this.compact = false,
    super.key,
  });

  final Restaurant restaurant;
  final VoidCallback? onTap;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 15 : 18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AppNetworkImage(
                    url: restaurant.imageUrl,
                    width: width,
                    height: compact ? 116 : 140,
                  ),
                  if (restaurant.discount > 0)
                    Positioned(
                      left: compact ? 7 : 10,
                      top: compact ? 7 : 10,
                      child: AppPill(
                        label: '${restaurant.discount}% OFF',
                        background: AppColors.primary,
                        foreground: Colors.white,
                      ),
                    ),
                  if (restaurant.foodShare && restaurant.discount <= 0)
                    Positioned(
                      left: compact ? 7 : 10,
                      top: compact ? 7 : 10,
                      child: const AppPill(
                        label: 'FoodShare',
                        icon: Icons.people_alt_rounded,
                        background: AppColors.primary,
                        foreground: Colors.white,
                      ),
                    ),
                  if (restaurant.deliveryMinutes > 0)
                    Positioned(
                      right: compact ? 7 : 10,
                      bottom: compact ? 7 : 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 7 : 9,
                          vertical: compact ? 5 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A172022),
                              blurRadius: 7,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: compact ? 13 : 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${restaurant.deliveryMinutes} min',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: compact ? 9.5 : 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 9 : AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: compact ? 14 : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: compact ? 10.5 : null,
                      ),
                    ),
                    if (_restaurantFooterMeta(restaurant).isNotEmpty ||
                        restaurant.rating > 0) ...[
                      SizedBox(height: compact ? 7 : 8),
                      Row(
                        children: [
                          if (restaurant.rating > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.primary,
                              size: 15,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${restaurant.rating}',
                              style: TextStyle(
                                fontSize: compact ? 10 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_restaurantFooterMeta(restaurant).isNotEmpty)
                              const _MetaDot(),
                          ],
                          if (_restaurantFooterMeta(restaurant).isNotEmpty)
                            Flexible(
                              child: Text(
                                _restaurantFooterMeta(restaurant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: compact ? 9.5 : null,
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '•',
        style: TextStyle(color: AppColors.textMuted, fontSize: 9),
      ),
    );
  }
}

String _restaurantFooterMeta(Restaurant restaurant) {
  final parts = <String>[
    if (restaurant.distanceKm > 0) '${restaurant.distanceKm} km',
    if (restaurant.deliveryFee > 0) '₹${restaurant.deliveryFee} delivery',
  ];
  return parts.join('  •  ');
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.onTap,
    this.width = 174,
    super.key,
  });

  final CatalogItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppNetworkImage(
                      url: item.imageUrl,
                      width: double.infinity,
                      height: 112,
                      borderRadius: 14,
                    ),
                    if (item.sharedDiscount > 0)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: AppPill(
                          label: 'Group ${item.sharedDiscount}% off',
                          background: AppColors.dark.withValues(alpha: 0.92),
                          foreground: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (item.discountPercent > 0)
                  Text(
                    '${item.discountPercent}% OFF',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: [
                          Text(
                            '₹${item.price}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          if (item.originalPrice > item.price)
                            Text(
                              '₹${item.originalPrice}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    QuantityControl(
                      quantity: quantity,
                      onAdd: onAdd,
                      onRemove: onRemove,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SharedOrderCard extends StatelessWidget {
  const SharedOrderCard({
    required this.group,
    required this.joined,
    required this.onJoin,
    this.onTap,
    this.compact = false,
    super.key,
  });

  final SharedGroup group;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact
          ? (MediaQuery.sizeOf(context).width - 40).clamp(280, 320).toDouble()
          : double.infinity,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppNetworkImage(
                      url: group.imageUrl,
                      width: 68,
                      height: 68,
                      borderRadius: 14,
                      semanticLabel: group.title,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            group.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              AppPill(
                                label: '${group.distanceKm} km',
                                icon: Icons.near_me_rounded,
                              ),
                              GroupCountdown(minutes: group.minutesLeft),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                DiscountProgressBar(group: group),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _SavingStat(
                        label: 'Item discount',
                        value: '${group.currentDiscount}%',
                      ),
                    ),
                    Expanded(
                      child: _SavingStat(
                        label: 'Delivery off',
                        value: '${group.deliveryDiscount}%',
                      ),
                    ),
                    Expanded(
                      child: _SavingStat(
                        label: 'You save',
                        value: '₹${group.savings}',
                        highlight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: joined ? null : onJoin,
                    icon: Icon(
                      joined ? Icons.check_rounded : Icons.group_add_rounded,
                      size: 18,
                    ),
                    label: Text(
                      joined
                          ? 'Joined'
                          : group.mode == DeliveryMode.food
                          ? 'Join Order'
                          : 'Join Basket',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiscountProgressBar extends StatelessWidget {
  const DiscountProgressBar({required this.group, super.key});

  final SharedGroup group;

  @override
  Widget build(BuildContext context) {
    return DiscountMilestoneProgress(group: group);
  }
}

class DiscountMilestoneProgress extends StatelessWidget {
  const DiscountMilestoneProgress({required this.group, super.key});

  final SharedGroup group;

  @override
  Widget build(BuildContext context) {
    final progress = group.participants / group.requiredParticipants;
    final needed = (group.requiredParticipants - group.participants).clamp(
      0,
      group.requiredParticipants,
    );
    final milestones = group.mode == DeliveryMode.food
        ? const [(2, 5), (3, 8), (5, 15)]
        : const [(2, 3), (3, 5), (5, 8), (8, 12)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${group.participants} of ${group.requiredParticipants} people joined',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Text(
              'Up to ${group.maximumDiscount}%',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.primaryDark),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0, 1)),
          duration: const Duration(milliseconds: 650),
          builder: (_, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.border,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          needed == 0
              ? 'Maximum ${group.maximumDiscount}% saving unlocked'
              : '$needed more ${needed == 1 ? 'person' : 'people'} needed to unlock ${group.maximumDiscount}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: List.generate(milestones.length * 2 - 1, (index) {
            if (index.isOdd) {
              final previous = milestones[index ~/ 2].$1;
              return Expanded(
                child: Container(
                  height: 2,
                  color: group.participants >= previous
                      ? AppColors.primary
                      : AppColors.border,
                ),
              );
            }
            final milestone = milestones[index ~/ 2];
            final complete = group.participants >= milestone.$1;
            final current =
                !complete &&
                (index == 0 ||
                    group.participants >= milestones[(index ~/ 2) - 1].$1);
            return Semantics(
              label:
                  '${milestone.$1} people, ${milestone.$2}% discount${complete ? ', unlocked' : ''}',
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: complete ? AppColors.primary : AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: complete || current
                            ? AppColors.primary
                            : AppColors.border,
                        width: current ? 2 : 1,
                      ),
                    ),
                    child: complete
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : Center(
                            child: Text(
                              '${milestone.$1}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${milestone.$2}%',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class GroupCountdown extends StatefulWidget {
  const GroupCountdown({required this.minutes, super.key});

  final int minutes;

  @override
  State<GroupCountdown> createState() => _GroupCountdownState();
}

class _GroupCountdownState extends State<GroupCountdown> {
  Timer? _timer;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.minutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _seconds == 0) return;
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _seconds ~/ 60;
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return AppPill(
      label: 'Closes in $minutes:$seconds',
      icon: Icons.timer_outlined,
      background: AppColors.warningLight,
      foreground: const Color(0xFF8A6100),
    );
  }
}

class _SavingStat extends StatelessWidget {
  const _SavingStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: highlight ? AppColors.dark : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({
    required this.count,
    required this.store,
    required this.total,
    required this.onTap,
    super.key,
  });

  final int count;
  final String store;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      padding: const EdgeInsets.fromLTRB(14, 9, 9, 9),
      decoration: BoxDecoration(
        color: AppColors.featureDark,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$count ${count == 1 ? 'item' : 'items'} • ₹$total',
                  style: const TextStyle(
                    color: Color(0xFFD2F4EF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.dark,
              minimumSize: const Size(100, 42),
              padding: const EdgeInsets.symmetric(horizontal: 13),
            ),
            child: const Text('View cart'),
          ),
        ],
      ),
    );
  }
}

class FloatingHomeNavigation extends StatelessWidget {
  const FloatingHomeNavigation({
    required this.mode,
    required this.index,
    required this.onChanged,
    required this.onModeToggle,
    required this.hasActiveGroup,
    super.key,
  });

  final DeliveryMode mode;
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onModeToggle;
  final bool hasActiveGroup;

  @override
  Widget build(BuildContext context) {
    final groupLabel = mode == DeliveryMode.food ? 'FoodShare' : 'ShareBasket';
    return LayoutBuilder(
      builder: (context, constraints) {
        final modeWidth = constraints.maxWidth < 355 ? 112.0 : 130.0;
        return Container(
          height: AppSpacing.navigationHeight,
          margin: const EdgeInsets.fromLTRB(
            12,
            0,
            12,
            AppSpacing.navigationMargin,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A075E54),
                blurRadius: 22,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _NavigationItem(
                        icon: mode == DeliveryMode.food
                            ? Icons.people_alt_outlined
                            : Icons.shopping_basket_outlined,
                        label: groupLabel,
                        selected: index == 0,
                        badge: hasActiveGroup,
                        onTap: () => onChanged(0),
                      ),
                    ),
                    Expanded(
                      child: _NavigationItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        selected: index == 1,
                        onTap: () => onChanged(1),
                      ),
                    ),
                    Expanded(
                      child: _NavigationItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Orders',
                        selected: index == 2,
                        onTap: () => onChanged(2),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                color: AppColors.border,
              ),
              SizedBox(
                width: modeWidth,
                child: _ModeAction(
                  mode: mode,
                  onTap: onModeToggle,
                  compact: modeWidth < 120,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  icon,
                  size: 23,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              if (badge)
                const Positioned(
                  right: -5,
                  top: -3,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeAction extends StatefulWidget {
  const _ModeAction({
    required this.mode,
    required this.onTap,
    required this.compact,
  });

  final DeliveryMode mode;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_ModeAction> createState() => _ModeActionState();
}

class _ModeActionState extends State<_ModeAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final food = widget.mode == DeliveryMode.food;
    return Semantics(
      button: true,
      label: 'Switch from ${food ? 'Food' : 'Grocery'} mode',
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F8B7E),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      food
                          ? Icons.restaurant_rounded
                          : Icons.shopping_cart_outlined,
                      key: ValueKey(widget.mode),
                      size: widget.compact ? 17 : 19,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: widget.compact ? 4 : 6),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        food ? 'Food' : 'Grocery',
                        key: ValueKey(widget.mode),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.compact ? 10.5 : 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: widget.compact ? 34 : 38,
                    height: widget.compact ? 34 : 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
