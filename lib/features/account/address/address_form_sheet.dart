import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../orders/providers/orders_providers.dart';
import 'address_form_logic.dart';
import 'address_location_capture.dart';
import 'address_providers.dart';
import 'pincode_lookup.dart';

/// Opens the Add / Edit address sheet. Resolves to the saved address, or
/// null if the customer closed the sheet without saving.
///
/// The caller shows any success message *after* the sheet closes. Messages
/// shown from inside a sheet through the page's ScaffoldMessenger render
/// behind the sheet, which is how save failures used to go unseen.
Future<CustomerAddress?> showAddressFormSheet(
  BuildContext context, {
  CustomerAddress? existing,
  bool deliverHereByDefault = true,
}) {
  return showModalBottomSheet<CustomerAddress>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AddressFormSheet(
        existing: existing,
        deliverHereByDefault: deliverHereByDefault,
      ),
    ),
  );
}

enum _LocationState { none, capturing, captured, failed }

enum _PincodeState { idle, loading, found, notFound, failed }

class AddressFormSheet extends ConsumerStatefulWidget {
  const AddressFormSheet({
    super.key,
    this.existing,
    this.deliverHereByDefault = true,
  });

  final CustomerAddress? existing;
  final bool deliverHereByDefault;

  @override
  ConsumerState<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<AddressFormSheet> {
  static const _presetLabels = ['Home', 'Work'];
  static const _saveTimeout = Duration(seconds: 25);
  static const _pincodeDebounce = Duration(milliseconds: 400);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customLabel;
  late final TextEditingController _house;
  late final TextEditingController _street;
  late final TextEditingController _area;
  late final TextEditingController _landmark;
  late final TextEditingController _pincode;
  late final TextEditingController _city;
  late final TextEditingController _state;

  late String _labelChoice; // 'Home', 'Work' or 'Other'
  late bool _deliverHere;

  bool _saving = false;
  AddressSaveError? _saveError;
  bool _submitted = false;

  _LocationState _locationState = _LocationState.none;
  LocationCaptureFailure? _locationFailure;
  double? _latitude;
  double? _longitude;
  double? _accuracy;

  _PincodeState _pincodeState = _PincodeState.idle;
  PincodeDetails? _pincodeDetails;
  String? _selectedPostOffice;
  String? _autoCity;
  String? _autoState;
  String _district = '';
  Timer? _pincodeTimer;
  int _lookupSeq = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final label = existing?.label.trim() ?? '';
    _labelChoice = label.isEmpty
        ? 'Home'
        : (_presetLabels.contains(label) ? label : 'Other');
    _customLabel = TextEditingController(
      text: _labelChoice == 'Other' ? label : '',
    );
    _house = TextEditingController(text: existing?.addressLine1 ?? '');
    _street = TextEditingController();
    _area = TextEditingController(text: existing?.area ?? '');
    _landmark = TextEditingController(text: existing?.landmark ?? '');
    _pincode = TextEditingController(text: existing?.pincode ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _state = TextEditingController(text: existing?.state ?? '');
    _district = existing?.district ?? '';
    _deliverHere = existing?.isDefault ?? widget.deliverHereByDefault;
    if (existing != null && existing.hasPin) {
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _accuracy = existing.locationAccuracyMeters;
      _locationState = _LocationState.captured;
    }
    _log('address_add_opened edit=$_isEdit');
  }

  @override
  void dispose() {
    _pincodeTimer?.cancel();
    for (final controller in [
      _customLabel,
      _house,
      _street,
      _area,
      _landmark,
      _pincode,
      _city,
      _state,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _label =>
      _labelChoice == 'Other' ? _customLabel.text.trim() : _labelChoice;

  // --- location ------------------------------------------------------------

  Future<void> _captureLocation() async {
    if (_locationState == _LocationState.capturing) return;
    setState(() {
      _locationState = _LocationState.capturing;
      _locationFailure = null;
      _clearSaveErrorFor(AddressField.location);
    });
    final result = await ref.read(addressLocationCaptureProvider).capture();
    if (!mounted) return;
    setState(() {
      final location = result.location;
      if (location != null) {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _accuracy = location.accuracyMeters;
        _locationState = _LocationState.captured;
      } else {
        _locationFailure = result.failure;
        // Keep a pin captured earlier; only a first attempt shows as failed.
        _locationState = _latitude != null
            ? _LocationState.captured
            : _LocationState.failed;
      }
    });
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _accuracy = null;
      _locationFailure = null;
      _locationState = _LocationState.none;
      _clearSaveErrorFor(AddressField.location);
    });
  }

  // --- pincode --------------------------------------------------------------

  void _onPincodeChanged(String value) {
    _clearSaveErrorFor(AddressField.pincode);
    _pincodeTimer?.cancel();
    final pin = value.trim();
    if (!isCompletePincode(pin)) {
      // Any result for a previous PIN is now stale.
      _lookupSeq++;
      if (_pincodeState != _PincodeState.idle || _pincodeDetails != null) {
        setState(() {
          _pincodeState = _PincodeState.idle;
          _pincodeDetails = null;
          _selectedPostOffice = null;
        });
      }
      return;
    }
    _pincodeTimer = Timer(_pincodeDebounce, () => _lookupPincode(pin));
  }

  Future<void> _lookupPincode(String pin) async {
    final seq = ++_lookupSeq;
    setState(() => _pincodeState = _PincodeState.loading);
    final result = await ref.read(pincodeLookupProvider).lookup(pin);
    // Ignore a result for a PIN the customer has since changed.
    if (!mounted || seq != _lookupSeq || _pincode.text.trim() != pin) return;
    setState(() {
      switch (result.status) {
        case PincodeLookupStatus.found:
          final details = result.details!;
          _pincodeDetails = details;
          _pincodeState = _PincodeState.found;
          _district = details.district;
          final plan = planPincodeAutofill(
            currentCity: _city.text,
            currentState: _state.text,
            lastAutoCity: _autoCity,
            lastAutoState: _autoState,
            suggestedCity: details.district,
            suggestedState: details.state,
          );
          if (plan.city != null) {
            _city.text = plan.city!;
            _autoCity = plan.city;
          }
          if (plan.state != null) {
            _state.text = plan.state!;
            _autoState = plan.state;
          }
          if (details.postOffices.length == 1) {
            _choosePostOffice(details.postOffices.single.name);
          }
        case PincodeLookupStatus.notFound:
          _pincodeDetails = null;
          _pincodeState = _PincodeState.notFound;
        case PincodeLookupStatus.failed:
          _pincodeDetails = null;
          _pincodeState = _PincodeState.failed;
      }
    });
  }

  void _choosePostOffice(String name) {
    _selectedPostOffice = name;
    // A post office name is a good locality suggestion, never an override.
    if (_area.text.trim().isEmpty) {
      _area.text = name;
    }
  }

  // --- save -----------------------------------------------------------------

  void _clearSaveErrorFor(AddressField field) {
    if (_saveError?.field == field) {
      _saveError = null;
    }
  }

  Future<void> _save() async {
    // A second tap while a save is in flight must not send a second request.
    if (_saving) return;
    setState(() {
      _submitted = true;
      _saveError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(accountRepositoryProvider);
    final existing = widget.existing;
    final hasPin = isValidCoordinate(_latitude, _longitude);
    final payload = CustomerAddress(
      id: existing?.id ?? '',
      label: _label,
      addressLine1: composeAddressLine1(
        house: _house.text,
        street: _street.text,
      ),
      area: _area.text.trim(),
      landmark: _landmark.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      district: _district,
      pincode: _pincode.text.trim(),
      isDefault: _deliverHere,
      latitude: hasPin ? _latitude : null,
      longitude: hasPin ? _longitude : null,
      locationAccuracyMeters: hasPin ? _accuracy : null,
    );

    try {
      final saved =
          await (existing == null
                  ? repository.addAddress(payload)
                  : repository.updateAddress(existing.id, payload))
              .timeout(_saveTimeout);
      _log('address_save_success edit=$_isEdit pinned=$hasPin');
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      // Every failure is shown, inside the sheet where it can be seen.
      final described = describeSaveError(error);
      _log('address_save_failed field=${described.field.name}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = described;
      });
    }
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pincodeServerError = _saveError?.field == AddressField.pincode
        ? _saveError!.message
        : null;
    final houseServerError = _saveError?.field == AddressField.house
        ? _saveError!.message
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit address' : 'Add address',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            _LocationCard(
              state: _locationState,
              failure: _locationFailure,
              accuracy: _accuracy,
              error: _saveError?.field == AddressField.location
                  ? _saveError!.message
                  : null,
              onCapture: _saving ? null : _captureLocation,
              onRemove: _saving ? null : _removeLocation,
              onOpenAppSettings: () =>
                  ref.read(addressLocationCaptureProvider).openAppSettings(),
              onOpenLocationSettings: () => ref
                  .read(addressLocationCaptureProvider)
                  .openLocationSettings(),
            ),
            const SizedBox(height: 16),
            Text('Save as', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final option in const ['Home', 'Work', 'Other'])
                  ChoiceChip(
                    key: Key('address-label-$option'),
                    label: Text(option),
                    selected: _labelChoice == option,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _labelChoice = option),
                  ),
              ],
            ),
            if (_labelChoice == 'Other')
              _field(
                key: const Key('address-custom-label'),
                controller: _customLabel,
                label: 'Label (e.g. Mom\'s place)',
                validator: validateLabel,
                textCapitalization: TextCapitalization.words,
              ),
            const SizedBox(height: 10),
            _field(
              key: const Key('address-house'),
              controller: _house,
              label: 'House / flat / floor',
              validator: validateHouse,
              serverError: houseServerError,
              onChanged: (_) => _clearSaveErrorFor(AddressField.house),
            ),
            _field(
              key: const Key('address-street'),
              controller: _street,
              label: 'Street / building (optional)',
            ),
            _field(
              key: const Key('address-area'),
              controller: _area,
              label: 'Area / locality',
              validator: validateArea,
              textCapitalization: TextCapitalization.words,
            ),
            _field(
              key: const Key('address-landmark'),
              controller: _landmark,
              label: 'Landmark (optional)',
            ),
            _field(
              key: const Key('address-pincode'),
              controller: _pincode,
              label: 'Pincode',
              validator: validatePincode,
              serverError: pincodeServerError,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: _onPincodeChanged,
            ),
            _PincodeHelper(
              state: _pincodeState,
              details: _pincodeDetails,
              selectedPostOffice: _selectedPostOffice,
              onSelectPostOffice: (name) =>
                  setState(() => _choosePostOffice(name)),
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    key: const Key('address-city'),
                    controller: _city,
                    label: 'City',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    key: const Key('address-state'),
                    controller: _state,
                    label: 'State',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const Key('address-deliver-here'),
              contentPadding: EdgeInsets.zero,
              value: _deliverHere,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _deliverHere = value),
              title: const Text('Deliver my orders here'),
              subtitle: const Text('Use this address at checkout'),
            ),
            if (_saveError != null &&
                _saveError!.field == AddressField.general) ...[
              _ErrorBanner(message: _saveError!.message),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('address-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Saving…'),
                        ],
                      )
                    : Text(_isEdit ? 'Update address' : 'Save address'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? Function(String value)? validator,
    String? serverError,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: key,
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        onChanged: (value) {
          onChanged?.call(value);
          if (serverError != null) setState(() {});
        },
        validator: validator == null ? null : (value) => validator(value ?? ''),
        decoration: InputDecoration(
          labelText: label,
          errorText: serverError,
          errorMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _log(String event) {
    assert(() {
      debugPrint('[Address] $event');
      return true;
    }());
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.state,
    required this.failure,
    required this.accuracy,
    required this.error,
    required this.onCapture,
    required this.onRemove,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
  });

  final _LocationState state;
  final LocationCaptureFailure? failure;
  final double? accuracy;
  final String? error;
  final VoidCallback? onCapture;
  final VoidCallback? onRemove;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String title, String? detail) = switch (state) {
      _LocationState.none => (
        Icons.my_location,
        'Pin your location (optional)',
        'Helps your rider find the door. You still enter the full address below.',
      ),
      _LocationState.capturing => (
        Icons.my_location,
        'Getting your current location…',
        null,
      ),
      _LocationState.captured => (
        Icons.location_on,
        'Location pinned',
        accuracy == null
            ? 'Please confirm the house and area below.'
            : 'Accurate to about ${accuracy!.round()} m. Please confirm the house and area below.',
      ),
      _LocationState.failed => (
        Icons.location_off_outlined,
        'Location not added',
        _failureMessage(failure),
      ),
    };

    // A failed refresh keeps the old pin; still say why the refresh failed.
    final refreshFailure = state == _LocationState.captured && failure != null
        ? _failureMessage(failure)
        : null;

    return Container(
      key: const Key('address-location-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              state == _LocationState.capturing
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: AppColors.dark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (detail != null)
                      Text(detail, style: theme.textTheme.bodySmall),
                    if (refreshFailure != null)
                      Text(
                        refreshFailure,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (state != _LocationState.capturing)
                OutlinedButton.icon(
                  key: const Key('address-use-location'),
                  onPressed: onCapture,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(
                    state == _LocationState.captured
                        ? 'Refresh location'
                        : 'Use current location',
                  ),
                ),
              if (state == _LocationState.captured)
                TextButton(
                  onPressed: onRemove,
                  child: const Text('Remove pin'),
                ),
              if (failure == LocationCaptureFailure.permissionDeniedForever)
                TextButton(
                  onPressed: onOpenAppSettings,
                  child: const Text('Open settings'),
                ),
              if (failure == LocationCaptureFailure.serviceDisabled)
                TextButton(
                  onPressed: onOpenLocationSettings,
                  child: const Text('Turn on location'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _failureMessage(LocationCaptureFailure? failure) {
    return switch (failure) {
      LocationCaptureFailure.permissionDenied => AddressCopy.locationDenied,
      LocationCaptureFailure.permissionDeniedForever =>
        AddressCopy.locationDeniedForever,
      LocationCaptureFailure.serviceDisabled => AddressCopy.gpsOff,
      _ => AddressCopy.locationUnavailable,
    };
  }
}

class _PincodeHelper extends StatelessWidget {
  const _PincodeHelper({
    required this.state,
    required this.details,
    required this.selectedPostOffice,
    required this.onSelectPostOffice,
  });

  final _PincodeState state;
  final PincodeDetails? details;
  final String? selectedPostOffice;
  final ValueChanged<String> onSelectPostOffice;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final Widget? child = switch (state) {
      _PincodeState.idle => null,
      _PincodeState.loading => Row(
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Looking up pincode…', style: small),
        ],
      ),
      _PincodeState.notFound => Text(AddressCopy.pincodeNotFound, style: small),
      _PincodeState.failed => Text(
        AddressCopy.pincodeLookupFailed,
        style: small,
      ),
      _PincodeState.found => _found(context, details!),
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(
      key: const Key('address-pincode-helper'),
      padding: const EdgeInsets.only(bottom: 10),
      child: child,
    );
  }

  Widget _found(BuildContext context, PincodeDetails details) {
    final small = Theme.of(context).textTheme.bodySmall;
    final place = [
      details.district,
      details.state,
    ].where((part) => part.isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(place.isEmpty ? 'Pincode found' : place, style: small),
        if (details.postOffices.length > 1) ...[
          const SizedBox(height: 6),
          Text('Select your post office (optional)', style: small),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final office in details.postOffices.take(12))
                ChoiceChip(
                  label: Text(office.name),
                  selected: selectedPostOffice == office.name,
                  onSelected: (_) => onSelectPostOffice(office.name),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('address-save-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
