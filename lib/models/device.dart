class Device {
  final String id;
  final String name;
  final String farmId;
  final String zoneId;
  final String type;
  final String status;

  Device({
    required this.id,
    required this.name,
    required this.farmId,
    required this.zoneId,
    required this.type,
    required this.status,
  });

  factory Device.fromMap(String id, Map<dynamic, dynamic> data) {
    return Device(
      id: id,
      name: data["name"] ?? "",
      farmId: data["farmId"] ?? "",
      zoneId: data["zoneId"] ?? "",
      type: data["type"] ?? "",
      status: data["status"] ?? "offline",
    );
  }
}
