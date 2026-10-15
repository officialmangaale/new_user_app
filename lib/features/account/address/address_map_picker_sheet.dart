import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/repositories/account_repository.dart';
import '../../app_state/providers/location_providers.dart';

import 'address_form_logic.dart';

class AddressMapPickerResult {
  const AddressMapPickerResult({
    required this.latitude,
    required this.longitude,
    this.resolved,
  });

  final double latitude;
  final double longitude;
  final ResolvedCustomerLocation? resolved;
}

Future<AddressMapPickerResult?> showAddressMapPickerSheet(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String? initialAddress,
}) {
  return showModalBottomSheet<AddressMapPickerResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: AddressMapPickerSheet(
        latitude: latitude,
        longitude: longitude,
        initialAddress: initialAddress,
      ),
    ),
  );
}

class AddressMapPickerSheet extends ConsumerStatefulWidget {
  const AddressMapPickerSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.initialAddress,
  });

  final double latitude;
  final double longitude;

  /// The address Google returned for the place the customer chose, shown only
  /// while the pin has not been moved. Never invented: null when unknown.
  final String? initialAddress;

  @override
  ConsumerState<AddressMapPickerSheet> createState() =>
      _AddressMapPickerSheetState();
}

class _AddressMapPickerSheetState
    extends ConsumerState<AddressMapPickerSheet> {
  static const _reverseDebounce = Duration(milliseconds: 650);

  late LatLng _selected;
  GoogleMapController? _controller;
  Timer? _reverseTimer;
  int _reverseSeq = 0;
  bool _resolving = false;
  ResolvedCustomerLocation? _resolved;
  String? _error;

  /// Becomes true once the pin has moved away from where the sheet opened, so
  /// the address Google returned for the original place is no longer shown.
  bool _pinMoved = false;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(widget.latitude, widget.longitude);
    _scheduleReverse();
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    _selected = position.target;
    // About 5 m; ignores the sub-metre jitter of a camera settling.
    if (!_pinMoved &&
        ((position.target.latitude - widget.latitude).abs() > 0.00005 ||
            (position.target.longitude - widget.longitude).abs() > 0.00005)) {
      _pinMoved = true;
    }
  }

  void _onCameraIdle() {
    _scheduleReverse();
  }

  void _scheduleReverse() {
    _reverseTimer?.cancel();
    _reverseTimer = Timer(_reverseDebounce, _reverseCurrentSelection);
  }

  Future<void> _reverseCurrentSelection() async {
    final latitude = _selected.latitude;
    final longitude = _selected.longitude;
    if (!isValidCoordinate(latitude, longitude)) return;
    final seq = ++_reverseSeq;
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      // The device geocoder: no API key, and not the Geocoding API.
      final place = await ref
          .read(reverseGeocoderProvider)
          .reverse(latitude, longitude)
          .timeout(const Duration(seconds: 10));
      if (!mounted || seq != _reverseSeq) return;
      setState(() {
        _resolved = place != null && place.isMeaningful
            ? ResolvedCustomerLocation(
                area: place.area,
                city: place.city,
                district: place.district,
                state: place.state,
                pincode: place.postalCode,
                latitude: latitude,
                longitude: longitude,
                formattedAddress: place.formatted,
              )
            : null;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted || seq != _reverseSeq) return;
      setState(() {
        _resolving = false;
        _error = 'Address lookup failed. You can still confirm this pin.';
      });
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      AddressMapPickerResult(
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        resolved: _resolved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = _pinMoved ? null : widget.initialAddress;
    final address = _resolved?.formattedAddress.isNotEmpty == true
        ? _resolved!.formattedAddress
        : (_resolved?.addressLine1.isNotEmpty == true
              ? _resolved!.addressLine1
              : (initial?.isNotEmpty == true ? initial : null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Confirm location', style: theme.textTheme.titleLarge),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selected,
                  zoom: 17,
                ),
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (controller) => _controller = controller,
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
              ),
              const IgnorePointer(
                child: Icon(Icons.location_pin, size: 44, color: Colors.red),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_resolving)
                const LinearProgressIndicator(minHeight: 2)
              else
                const SizedBox(height: 2),
              const SizedBox(height: 10),
              Text(
                address?.isNotEmpty == true
                    ? address!
                    : 'Pin selected. Add address details manually below.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('address-map-confirm'),
                onPressed: _confirm,
                child: const Text('Confirm location'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
