/// A location the app can show air quality for. Used both for geocoding
/// search results and for the persisted "last location".
class Place {
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? admin1; // state / region

  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.admin1,
  });

  /// A nice one-line label, e.g. "Surat, Gujarat, India".
  String get label {
    final parts = [name, admin1, country]
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>()
        .toList();
    return parts.join(', ');
  }

  factory Place.fromGeocoding(Map<String, dynamic> json) => Place(
        name: (json['name'] as String?) ?? 'Unknown',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        country: json['country'] as String?,
        admin1: json['admin1'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'country': country,
        'admin1': admin1,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        name: (json['name'] as String?) ?? 'Unknown',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        country: json['country'] as String?,
        admin1: json['admin1'] as String?,
      );
}
