class Farm {
  final String id;
  final String name;
  final String location;

  Farm({required this.id, required this.name, required this.location});

  factory Farm.fromMap(String id, Map<dynamic, dynamic> data) {
    return Farm(
      id: id,
      name: data["name"] ?? "",
      location: data["location"] ?? "",
    );
  }
}
