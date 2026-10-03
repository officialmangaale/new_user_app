class GoogleMapsConfig {
  const GoogleMapsConfig({
    this.enabled = false,
    this.customerMapPicker = false,
    this.customerPlaces = false,
    this.customerGeocoding = false,
  });

  static const environment = GoogleMapsConfig(
    enabled: bool.fromEnvironment('GOOGLE_MAPS_ENABLED'),
    customerMapPicker: bool.fromEnvironment('CUSTOMER_MAP_PICKER_ENABLED'),
    customerPlaces: bool.fromEnvironment('GOOGLE_PLACES_ENABLED'),
    customerGeocoding: bool.fromEnvironment('GOOGLE_GEOCODING_ENABLED'),
  );

  final bool enabled;
  final bool customerMapPicker;
  final bool customerPlaces;
  final bool customerGeocoding;
}
