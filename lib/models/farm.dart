class Farm {
  final String id;
  final String name;
  final String location;

  const Farm({required this.id, required this.name, required this.location});

  factory Farm.fromMap(String id, Map<dynamic, dynamic> map) {
    return Farm(
      id: id,
      name: map["name"] ?? "",
      location: map["location"] ?? "",
    );
  }
}
