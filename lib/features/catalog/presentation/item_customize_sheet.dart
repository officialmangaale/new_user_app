import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../shared/models/app_models.dart';

/// Lets the customer choose a size and extras before the item enters the cart.
///
/// Mirrors the web client's `ItemCustomizeModal`. This is what makes variants
/// and addons real: without it the cart would always take the base
/// configuration and the customer could never order a Large.
///
/// Returns the chosen [CartSelection], or null when dismissed.
Future<CartSelection?> showItemCustomizeSheet(
  BuildContext context,
  CatalogItem item,
) {
  return showModalBottomSheet<CartSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ItemCustomizeSheet(item: item),
  );
}

class _ItemCustomizeSheet extends StatefulWidget {
  const _ItemCustomizeSheet({required this.item});

  final CatalogItem item;

  @override
  State<_ItemCustomizeSheet> createState() => _ItemCustomizeSheetState();
}

class _ItemCustomizeSheetState extends State<_ItemCustomizeSheet> {
  MenuVariant? _variant;
  final Set<String> _addonIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Preselect the first available size so the primary action is never
    // blocked on a choice the customer did not know they had to make.
    final available = widget.item.variants
        .where((variant) => variant.isAvailable)
        .toList();
    if (available.isNotEmpty) _variant = available.first;
  }

  List<MenuAddon> get _selectedAddons => widget.item.addons
      .where((addon) => _addonIds.contains(addon.id))
      .toList(growable: false);

  CartSelection get _selection => CartSelection(
    item: widget.item,
    variant: _variant,
    addons: _selectedAddons,
  );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final variants = item.variants;
    final addons = item.addons;
    // Only block when the item genuinely has sizes but none is chosen.
    final ready = variants.isEmpty || _variant != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    item.isVeg ? Icons.eco_rounded : Icons.local_fire_department,
                    color: item.isVeg ? AppColors.success : AppColors.dark,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                children: [
                  if (variants.isNotEmpty) ...[
                    _SectionLabel(
                      title: 'Choose a size',
                      caption: 'Required',
                    ),
                    RadioGroup<String>(
                      groupValue: _variant?.id,
                      onChanged: (value) => setState(() {
                        _variant = variants.firstWhere(
                          (variant) => variant.id == value,
                        );
                      }),
                      child: Column(
                        children: [
                          for (final variant in variants)
                            RadioListTile<String>(
                              value: variant.id,
                              enabled: variant.isAvailable,
                              contentPadding: EdgeInsets.zero,
                              title: Text(variant.name),
                              secondary: Text(
                                '₹${variant.price}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: variant.isAvailable
                                  ? null
                                  : const Text('Unavailable'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (addons.isNotEmpty) ...[
                    _SectionLabel(
                      title: 'Add extras',
                      caption: 'Optional',
                    ),
                    for (final addon in addons)
                      CheckboxListTile(
                        value: _addonIds.contains(addon.id),
                        enabled: addon.isAvailable,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(addon.name),
                        subtitle: addon.isAvailable
                            ? null
                            : const Text('Unavailable'),
                        secondary: Text(
                          '+₹${addon.price}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _addonIds.add(addon.id);
                          } else {
                            _addonIds.remove(addon.id);
                          }
                        }),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  if (_selection.optionsLabel.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _selection.optionsLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppButton(
                    label: 'Add item • ₹${_selection.unitPrice}',
                    onPressed: ready
                        ? () => Navigator.pop(context, _selection)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Final price and taxes are confirmed at checkout.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          AppPill(label: caption),
        ],
      ),
    );
  }
}
