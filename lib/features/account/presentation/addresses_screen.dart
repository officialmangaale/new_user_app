import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../orders/providers/orders_providers.dart';
import '../address/address_form_logic.dart';
import '../address/address_form_sheet.dart';

/// Saved delivery addresses, backed by user-service:
///
///   GET    /customers/me/addresses
///   POST   /customers/me/addresses
///   PATCH  /customers/me/addresses/:id
///   DELETE /customers/me/addresses/:id
///   POST   /customers/me/addresses/:id/default
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
                  onPressed: () => _openEditor(context, ref, existing: address),
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
  } catch (error) {
    // Any failure, not only API errors, is shown.
    messenger.showSnackBar(
      SnackBar(content: Text(describeSaveError(error).message)),
    );
  }
}

/// Opens the address sheet and, after it closes with a saved address,
/// refreshes the list and confirms. The confirmation is shown here, on the
/// page, because a message raised from inside the sheet renders behind it.
Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref, {
  CustomerAddress? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showAddressFormSheet(context, existing: existing);
  if (saved == null) return;
  ref.invalidate(addressesProvider);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        existing == null
            ? (saved.isDefault
                  ? 'Address saved. Delivering here.'
                  : 'Address saved')
            : 'Address updated',
      ),
    ),
  );
}
