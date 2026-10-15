import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/di/di_providers.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../account/address/address_form_logic.dart';
import '../../app_state/providers/location_providers.dart';
import '../../orders/providers/orders_providers.dart';
import '../providers/delivery_location.dart';

/// Asks only for what GPS cannot know, then saves the current location as a
/// delivery address.
///
/// The location itself - coordinates, area, city, state, pincode - is already
/// resolved and is attached unchanged: nothing here searches for an address, so
/// typing "House 42" can never move the pin. The customer supplies the door
/// (house / flat / floor), who receives the order, and an optional landmark.
Future<CustomerAddress?> showCompleteDeliveryAddressSheet(
  BuildContext context,
) {
  return showModalBottomSheet<CustomerAddress>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const CompleteDeliveryAddressSheet(),
    ),
  );
}

class CompleteDeliveryAddressSheet extends ConsumerStatefulWidget {
  const CompleteDeliveryAddressSheet({super.key});

  @override
  ConsumerState<CompleteDeliveryAddressSheet> createState() =>
      _CompleteDeliveryAddressSheetState();
}

class _CompleteDeliveryAddressSheetState
    extends ConsumerState<CompleteDeliveryAddressSheet> {
  static const _labels = ['Home', 'Work', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _house = TextEditingController();
  final _receiver = TextEditingController();
  final _landmark = TextEditingController();
  final _customLabel = TextEditingController();
  final _area = TextEditingController();
  final _pincode = TextEditingController();

  String _label = 'Home';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final place = ref.read(deliveryLocationViewProvider).placeAddress;
    _area.text = place?.area ?? '';
    _pincode.text = place?.postalCode ?? '';
    _prefillReceiver();
  }

  Future<void> _prefillReceiver() async {
    final name = await ref.read(authStorageProvider).readUserName();
    if (!mounted || _receiver.text.trim().isNotEmpty) return;
    if (name != null && name.trim().isNotEmpty) {
      _receiver.text = name.trim();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _house,
      _receiver,
      _landmark,
      _customLabel,
      _area,
      _pincode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _labelText =>
      _label == 'Other' ? _customLabel.text.trim() : _label;

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final view = ref.read(deliveryLocationViewProvider);
    final location = view.location;
    if (location == null ||
        !isValidCoordinate(location.latitude, location.longitude)) {
      setState(() => _error = 'Choose your delivery location first.');
      return;
    }
    final place = view.placeAddress;

    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = CustomerAddress(
      id: '',
      label: _labelText,
      addressLine1: _house.text.trim(),
      area: _area.text.trim().isNotEmpty
          ? _area.text.trim()
          : (place?.area ?? ''),
      landmark: _landmark.text.trim(),
      city: place?.city ?? location.city,
      state: place?.state ?? location.state,
      district: place?.district ?? location.district,
      pincode: _pincode.text.trim().isNotEmpty
          ? _pincode.text.trim()
          : (place?.postalCode ?? ''),
      isDefault: true,
      // The coordinates the customer is already being priced on: unchanged.
      latitude: location.latitude,
      longitude: location.longitude,
      receiverName: _receiver.text.trim(),
    );
    try {
      final saved = await ref
          .read(accountRepositoryProvider)
          .addAddress(payload)
          .timeout(const Duration(seconds: 25));
      // The saved address is now the default and carries the same pin, so the
      // canonical location is unchanged; just stop saying "current location".
      ref.read(useCurrentLocationProvider.notifier).choose(false);
      ref.invalidate(addressesProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = describeSaveError(error).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = ref.watch(deliveryLocationViewProvider);
    final place = view.placeAddress;
    final areaKnown = (place?.area ?? '').isNotEmpty;
    final pincodeKnown = isCompletePincode(place?.postalCode ?? '');
    final summary = [view.primary, view.secondary]
        .where((part) => part.trim().isNotEmpty && part != 'Finding your area…')
        .join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complete delivery address', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryVeryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primaryText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary.isEmpty ? 'Your current location' : summary,
                      key: const Key('complete-address-location'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('complete-address-house'),
              controller: _house,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'House / Flat / Floor *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => validateHouse(value ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('complete-address-receiver'),
              controller: _receiver,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Receiver name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Please enter who will receive the order.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('complete-address-landmark'),
              controller: _landmark,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Landmark (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            // Only when the geocoder could not supply them: never ask the
            // customer to retype geography the app already knows.
            if (!areaKnown) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('complete-address-area'),
                controller: _area,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Area / locality (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (!pincodeKnown) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('complete-address-pincode'),
                controller: _pincode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Pincode (optional)',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  return validatePincode(text);
                },
              ),
            ],
            const SizedBox(height: 16),
            Text('Save as', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final option in _labels)
                  ChoiceChip(
                    key: Key('complete-address-label-$option'),
                    label: Text(option),
                    selected: _label == option,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _label = option),
                  ),
              ],
            ),
            if (_label == 'Other') ...[
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('complete-address-custom-label'),
                controller: _customLabel,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => validateLabel(value ?? ''),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('complete-address-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('complete-address-save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save and continue'),
            ),
          ],
        ),
      ),
    );
  }
}
