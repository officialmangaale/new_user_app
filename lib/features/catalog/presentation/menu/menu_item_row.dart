import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/catalog_entities.dart';
import 'menu_image.dart';
import 'menu_styles.dart';
import 'veg_mark.dart';

const double _kPhoto = 124;
const double _kButtonWidth = 100;
const double _kButtonHeight = 40;
const double _kButtonOverlap = _kButtonHeight / 2;

/// One dish: details on the left, photo + ADD/stepper on the right.
///
/// Reads everything from [item]; an item without a photo collapses the photo
/// column to just the ADD button so no empty image space is left behind.
class MenuItemRow extends StatefulWidget {
  const MenuItemRow({
    required this.item,
    required this.quantity,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
    this.ordersEnabled = true,
    super.key,
  });

  final CatalogItem item;
  final int quantity;
  final VoidCallback onTap;

  /// Receives the keys the fly-to-cart animation starts from.
  final void Function(GlobalKey imageKey, GlobalKey addKey) onAdd;
  final VoidCallback onRemove;

  /// False while the restaurant is closed.
  final bool ordersEnabled;

  @override
  State<MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<MenuItemRow> {
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _addKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final soldOut = !item.isAvailable;
    final hasPhoto = item.imageUrl.trim().isNotEmpty;
    final action = _ItemAction(
      key: _addKey,
      name: item.name,
      quantity: widget.quantity,
      soldOut: soldOut,
      enabled: widget.ordersEnabled,
      onAdd: () => widget.onAdd(hasPhoto ? _imageKey : _addKey, _addKey),
      onRemove: widget.onRemove,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: hasPhoto
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Opacity(
              opacity: soldOut ? 0.5 : 1,
              child: _Details(item: item, onTap: widget.onTap),
            ),
          ),
          const SizedBox(width: 12),
          if (hasPhoto)
            SizedBox(
              width: _kPhoto,
              // Reserves the half of the button that hangs below the photo.
              height: _kPhoto + _kButtonOverlap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Opacity(
                      opacity: soldOut ? 0.5 : 1,
                      child: GestureDetector(
                        onTap: widget.onTap,
                        child: ClipRRect(
                          key: _imageKey,
                          borderRadius: BorderRadius.circular(16),
                          child: MenuImage(
                            url: item.imageUrl,
                            width: _kPhoto,
                            height: _kPhoto,
                            semanticLabel: item.name,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: (_kPhoto - _kButtonWidth) / 2,
                    child: action,
                  ),
                ],
              ),
            )
          else
            SizedBox(width: _kButtonWidth, child: action),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.item, required this.onTap});

  final CatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final discounted = item.originalPrice > item.price && item.price > 0;
    int? fromPrice;
    if (item.price <= 0) {
      for (final variant in item.variants) {
        if (variant.price > 0 &&
            (fromPrice == null || variant.price < fromPrice)) {
          fromPrice = variant.price;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VegMark(isVeg: item.isVeg),
                  if (item.isBestseller) ...[
                    const SizedBox(width: 8),
                    const _Tag(label: 'Bestseller'),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MenuText.itemName,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      fromPrice != null
                          ? 'From ${rupees(fromPrice)}'
                          : rupees(item.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MenuText.price,
                    ),
                  ),
                  if (discounted) ...[
                    const SizedBox(width: 8),
                    Text(
                      rupees(item.originalPrice),
                      style: MenuText.meta.copyWith(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (item.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          ExpandableDescription(text: item.subtitle.trim()),
        ],
        if (item.needsCustomisation) ...[
          const SizedBox(height: 6),
          const Text('Customisable', style: MenuText.meta),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// Two-line description with an inline "more" when it overflows.
class ExpandableDescription extends StatefulWidget {
  const ExpandableDescription({required this.text, super.key});

  final String text;

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: MenuText.description),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : 2,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: MenuText.description,
            ),
            if (overflows)
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(
                      _expanded ? 'less' : 'more',
                      style: MenuText.meta.copyWith(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ADD / stepper / sold-out control, always 100x40.
class _ItemAction extends StatelessWidget {
  const _ItemAction({
    required this.name,
    required this.quantity,
    required this.soldOut,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final String name;
  final int quantity;
  final bool soldOut;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (soldOut) {
      return const _ButtonShell(
        label: 'Sold out',
        background: AppColors.disabledBackground,
        foreground: AppColors.disabledText,
        semanticLabel: 'Sold out',
      );
    }
    if (quantity > 0) {
      return QuantityStepper(
        name: name,
        quantity: quantity,
        onAdd: enabled ? onAdd : null,
        onRemove: onRemove,
      );
    }
    return _ButtonShell(
      label: 'ADD',
      background: enabled ? AppColors.primary : AppColors.disabledBackground,
      foreground: enabled ? AppColors.ink : AppColors.disabledText,
      shadow: enabled,
      semanticLabel: enabled ? 'Add $name to cart' : '$name unavailable',
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onAdd();
            }
          : null,
    );
  }
}

class _ButtonShell extends StatelessWidget {
  const _ButtonShell({
    required this.label,
    required this.background,
    required this.foreground,
    required this.semanticLabel,
    this.shadow = false,
    this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final String semanticLabel;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: background,
        elevation: shadow ? 3 : 0,
        shadowColor: const Color(0x330B2E2C),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: _kButtonWidth,
            height: _kButtonHeight,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "-  1  +" control that replaces ADD in the same spot.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.name,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final String name;
  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      elevation: 3,
      shadowColor: const Color(0x330B2E2C),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _kButtonWidth,
        height: _kButtonHeight,
        child: Row(
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              label: 'Remove one $name',
              onTap: onRemove,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: '$quantity in cart',
                excludeSemantics: true,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              label: 'Add one more $name',
              onTap: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          width: 34,
          height: _kButtonHeight,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.inkSecondary : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
