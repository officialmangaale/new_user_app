import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/api_exception.dart';
import '../../../core/nature/widgets/nature_refresh_indicator.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../orders/providers/orders_providers.dart';

/// Saved delivery addresses, backed by the existing customer address CRUD on
/// restaurant-service:
///
///   GET    /customer-web/addresses
///   POST   /customer-web/addresses
///   PATCH  /customer-web/addresses/:id
///   DELETE /customer-web/addresses/:id
///   PATCH  /customer-web/addresses/:id/default
///
/// Checkout reads the default address (`CheckoutViewModel._readDefaultAddress`),
/// so "Set as delivery address" here is what actually selects the address the
/// order is placed against.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: AsyncListView<CustomerAddress>(
        value: addresses,
        onRetry: () => ref.invalidate(addressesProvider),
        empty: const EmptyState(
          icon: Icons.location_off_outlined,
          title: 'No saved addresses',
          message:
              'Add an address so checkout knows where to deliver your order.',
        ),
        builder: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(addressesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _AddressTile(address: items[index]),
          ),
        ),
      ),
    );
  }
}

class _AddressTile extends ConsumerWidget {
  const _AddressTile({required this.address});

  final CustomerAddress address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = address.label.trim().isEmpty ? 'Address' : address.label;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.dark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (address.isDefault)
                  const AppPill(label: 'Delivering here', icon: Icons.check),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address.singleLine,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Row(
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: () => _run(
                      context,
                      ref,
                      () => ref
                          .read(accountRepositoryProvider)
                          .setDefaultAddress(address.id),
                      'Delivering to $label',
                    ),
                    child: const Text('Set as delivery address'),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      _openEditor(context, ref, existing: address),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => _confirmDelete(context, ref, address),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  CustomerAddress address,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete address?'),
      content: Text('${address.singleLine} will be removed from your account.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await _run(
    context,
    ref,
    () => ref.read(accountRepositoryProvider).deleteAddress(address.id),
    'Address deleted',
  );
}

/// Runs a write, then refreshes the list so the screen reflects the server
/// rather than an optimistic guess.
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
  String successMessage,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    ref.invalidate(addressesProvider);
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  } on ApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref, {
  CustomerAddress? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddressEditor(existing: existing),
    ),
  );
}

class _AddressEditor extends ConsumerStatefulWidget {
  const _AddressEditor({this.existing});

  final CustomerAddress? existing;

  @override
  ConsumerState<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends ConsumerState<_AddressEditor> {
  late final TextEditingController _label;
  late final TextEditingController _line1;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _pincode;
  late bool _isDefault;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.label ?? 'Home');
    _line1 = TextEditingController(text: existing?.addressLine1 ?? '');
    _area = TextEditingController(text: existing?.area ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _pincode = TextEditingController(text: existing?.pincode ?? '');
    _isDefault = existing?.isDefault ?? true;
  }

  @override
  void dispose() {
    for (final controller in [_label, _line1, _area, _city, _pincode]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_line1.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the house / street details.')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(accountRepositoryProvider);
    final existing = widget.existing;
    
    UserLocation? loc;
    if (existing == null) {
      try {
        loc = await const LocationService().current();
      } catch (_) {
        // Fall back to no coordinates if permission denied
      }
    }

    // Coordinates are preserved on edit; the delivery lat/lng the order is
    // placed with comes from the device when available.
    final payload = CustomerAddress(
      id: existing?.id ?? '',
      label: _label.text.trim(),
      addressLine1: _line1.text.trim(),
      area: _area.text.trim(),
      city: _city.text.trim(),
      pincode: _pincode.text.trim(),
      isDefault: _isDefault,
      latitude: existing?.latitude ?? loc?.latitude,
      longitude: existing?.longitude ?? loc?.longitude,
    );
    try {
      if (existing == null) {
        await repository.addAddress(payload);
      } else {
        await repository.updateAddress(existing.id, payload);
      }
      ref.invalidate(addressesProvider);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Address saved' : 'Address updated'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Add address' : 'Edit address',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _field(_label, 'Label (Home, Work…)'),
          _field(_line1, 'House / flat / street'),
          _field(_area, 'Area / locality'),
          _field(_city, 'City'),
          _field(_pincode, 'Pincode', keyboard: TextInputType.number),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isDefault,
            onChanged: (value) => setState(() => _isDefault = value),
            title: const Text('Deliver my orders here'),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: widget.existing == null ? 'Save address' : 'Update address',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
