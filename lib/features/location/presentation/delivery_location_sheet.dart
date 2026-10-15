import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../account/address/address_form_sheet.dart';
import '../../app_state/providers/app_controller.dart';
import '../../app_state/providers/location_providers.dart';
import '../../cart/providers/delivery_location.dart';
import '../../orders/providers/orders_providers.dart';

/// Opens the delivery-location chooser: current location, saved addresses, or a
/// new address. Choosing re-points the canonical delivery location, so the
/// restaurant list, distances and the cart bill all follow.
Future<void> showDeliveryLocationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const DeliveryLocationSheet(),
  );
}

class DeliveryLocationSheet extends ConsumerStatefulWidget {
  const DeliveryLocationSheet({super.key});

  @override
  ConsumerState<DeliveryLocationSheet> createState() =>
      _DeliveryLocationSheetState();
}

class _DeliveryLocationSheetState extends ConsumerState<DeliveryLocationSheet> {
  bool _locating = false;
  String? _message;
  LocationFailure? _failure;
  String? _switchingTo;

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _message = null;
      _failure = null;
    });
    final fix = await ref.read(deviceFixProvider.notifier).refresh();
    if (!mounted) return;
    if (fix == null) {
      final state = ref.read(deviceFixStatusProvider);
      setState(() {
        _locating = false;
        _failure = state.failure;
        _message =
            state.failureMessage ??
            'Unable to determine your location. Try again, or choose a saved address.';
      });
      return;
    }
    ref.read(useCurrentLocationProvider.notifier).choose(true);
    // A fresh fix deserves a fresh attempt at its address.
    ref.invalidate(deviceAddressProvider);
    Navigator.of(context).pop();
  }

  Future<void> _useSavedAddress(CustomerAddress address) async {
    if (_switchingTo != null) return;
    setState(() {
      _switchingTo = address.id;
      _message = null;
    });
    try {
      if (!address.isDefault) {
        await ref.read(accountRepositoryProvider).setDefaultAddress(address.id);
      }
      ref.read(useCurrentLocationProvider.notifier).choose(false);
      ref.invalidate(addressesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _switchingTo = null;
        _message = 'We could not switch the address. Please try again.';
      });
    }
  }

  Future<void> _addAddress() async {
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    navigator.pop();
    final saved = await showAddressFormSheet(rootContext);
    if (saved == null) return;
    ref.read(useCurrentLocationProvider.notifier).choose(false);
    ref.invalidate(addressesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authenticated = ref.watch(
      appControllerProvider.select((s) => s.authenticated),
    );
    final view = ref.watch(deliveryLocationViewProvider);
    final addresses = authenticated
        ? ref.watch(addressesProvider).value ?? const <CustomerAddress>[]
        : const <CustomerAddress>[];
    final deviceState = ref.watch(deviceFixStatusProvider);
    final selectedSaved = view.location?.source ==
            DeliveryLocationSource.savedAddress
        ? view.location!.id
        : (view.address?.id ?? '');
    final usingCurrent = view.isCurrentLocation;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery location', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _OptionTile(
            key: const Key('location-option-current'),
            icon: Icons.my_location_rounded,
            title: 'Use current location',
            subtitle: usingCurrent
                ? [view.primary, view.secondary]
                      .where((part) => part.trim().isNotEmpty)
                      .join(' · ')
                : 'Find restaurants near where you are',
            selected: usingCurrent,
            busy: _locating || deviceState.locating && usingCurrent,
            trailingText: usingCurrent ? 'Refresh' : null,
            onTap: _useCurrentLocation,
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              key: const Key('location-sheet-message'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
            if (_failure == LocationFailure.permanentlyDenied)
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: const Text('Open app settings'),
              ),
            if (_failure == LocationFailure.serviceDisabled)
              TextButton(
                onPressed: Geolocator.openLocationSettings,
                child: const Text('Turn on location'),
              ),
          ],
          if (view.addressFailed && usingCurrent)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "We couldn't find a name for this spot, but delivery "
                      'distance and charges still use your exact position.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    key: const Key('location-retry-address'),
                    onPressed: () => ref.invalidate(deviceAddressProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (addresses.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Saved addresses', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final address in addresses)
              _OptionTile(
                key: Key('location-option-${address.id}'),
                icon: _iconFor(address.label),
                title: address.label.trim().isEmpty
                    ? 'Saved address'
                    : address.label.trim(),
                subtitle: address.hasPin
                    ? address.singleLine
                    : '${address.singleLine}\nLocation needs confirming',
                selected: !usingCurrent && selectedSaved == address.id,
                busy: _switchingTo == address.id,
                onTap: () => _useSavedAddress(address),
              ),
          ],
          const SizedBox(height: 12),
          if (authenticated)
            OutlinedButton.icon(
              key: const Key('location-add-address'),
              onPressed: _addAddress,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add new address'),
            )
          else
            Text(
              'Log in to save addresses for faster checkout.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String label) {
    switch (label.trim().toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'work':
        return Icons.work_outline_rounded;
      default:
        return Icons.location_on_outlined;
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.busy = false,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.primaryVeryLight : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle.trim().isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (trailingText != null)
                  Text(
                    trailingText!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  )
                else if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
