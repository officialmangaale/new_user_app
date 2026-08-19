import '../../catalog/domain/entities/catalog_entities.dart';

/// One configured cart entry: an item plus the exact options chosen.
///
/// Two entries of the same item with different options are different lines, so
/// the identity is [lineId] rather than the item id.
class CartSelection {
  const CartSelection({
    required this.item,
    this.variant,
    this.addons = const [],
  });

  final CatalogItem item;
  final MenuVariant? variant;
  final List<MenuAddon> addons;

  /// Stable, order-independent identity for this configuration.
  String get lineId {
    final addonIds = addons.map((addon) => addon.id).toList()..sort();
    return [item.id, variant?.id ?? '', addonIds.join('+')].join('|');
  }

  /// Unit price: the variant replaces the base price, addons add on top.
  int get unitPrice =>
      (variant?.price ?? item.price) +
      addons.fold(0, (sum, addon) => sum + addon.price);

  /// Human-readable option summary, e.g. "Large • Extra cheese".
  String get optionsLabel => [
    if (variant != null) variant!.name,
    ...addons.map((addon) => addon.name),
  ].join(' • ');
}

class CartLine {
  const CartLine({required this.selection, required this.quantity});

  final CartSelection selection;
  final int quantity;

  CatalogItem get item => selection.item;
  MenuVariant? get variant => selection.variant;
  List<MenuAddon> get addons => selection.addons;
  String get lineId => selection.lineId;
  String get optionsLabel => selection.optionsLabel;

  int get total => selection.unitPrice * quantity;
}
