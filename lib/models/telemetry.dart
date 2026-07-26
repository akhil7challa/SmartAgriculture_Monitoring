class Telemetry {
  final double temperature;
  final double humidity;
  final int soilMoisture;
  final String pumpStatus;
  final int lastSeen;

  Telemetry({
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.pumpStatus,
    required this.lastSeen,
  });

  factory Telemetry.fromMap(Map<dynamic, dynamic> data) {
    return Telemetry(
      temperature: (data["temperature"] ?? 0).toDouble(),
      humidity: (data["humidity"] ?? 0).toDouble(),
      soilMoisture: data["soilMoisture"] ?? 0,
      pumpStatus: data["pumpStatus"] ?? "OFF",
      lastSeen: data["lastSeen"] ?? 0,
    );
  }
}
