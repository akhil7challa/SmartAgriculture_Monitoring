class Zone {
  final String id;
  final String name;

  Zone({required this.id, required this.name});

  factory Zone.fromMap(String id, Map<dynamic, dynamic> data) {
    return Zone(id: id, name: data["name"] ?? "");
  }
}
