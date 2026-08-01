class Farm {
  final String id;
  final String name;
  final String location;
  final double latitude;
  final double longitude;

  Farm({
    required this.id,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  factory Farm.fromMap(String id, Map<dynamic, dynamic> data) {
    return Farm(
      id: id,
      name: data["name"] ?? "",
      location: data["location"] ?? "",
      latitude: (data["latitude"] ?? 0).toDouble(),
      longitude: (data["longitude"] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "location": location,
      "latitude": latitude,
      "longitude": longitude,
    };
  }
}
