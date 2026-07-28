import 'package:firebase_database/firebase_database.dart';

import '../../models/farm.dart';
import '../../models/device.dart';
import '../../models/telemetry.dart';
import '../../models/zone.dart';

class FirebaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  DatabaseReference get farmsRef => _database.ref("farms");
  DatabaseReference get devicesRef => _database.ref("devices");
  DatabaseReference get telemetryRef => _database.ref("telemetry");
  DatabaseReference get commandsRef => _database.ref("commands");

  Future<List<Farm>> getAllFarms() async {
    final snapshot = await farmsRef.get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> data =
        Map<dynamic, dynamic>.from(snapshot.value as Map);

    return data.entries
        .map((entry) => Farm.fromMap(entry.key, entry.value))
        .toList();
  }

  Future<List<Device>> getAllDevices() async {
    final snapshot = await devicesRef.get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> data =
        Map<dynamic, dynamic>.from(snapshot.value as Map);

    return data.entries
        .map((entry) => Device.fromMap(entry.key, entry.value))
        .toList();
  }

  Future<Telemetry?> getTelemetry(String deviceId) async {
    final snapshot = await telemetryRef.child(deviceId).child("livedata").get();

    if (!snapshot.exists) {
      return null;
    }

    return Telemetry.fromMap(
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
  }

  Stream<Telemetry?> getTelemetryStream(String deviceId) {
    return telemetryRef.child(deviceId).child("livedata").onValue.map((event) {
      final data = event.snapshot.value;

      if (data == null) {
        return null;
      }

      return Telemetry.fromMap(
        Map<dynamic, dynamic>.from(data as Map),
      );
    });
  }

  Stream<List<Telemetry>> getTelemetryHistoryStream(
    String deviceId, {
    int limit = 1000,
  }) {
    return telemetryRef
        .child(deviceId)
        .child("historydata")
        .orderByChild("lastSeen")
        .limitToLast(limit)
        .onValue
        .map((event) {
      final data = event.snapshot.value;

      if (data == null) {
        return <Telemetry>[];
      }

      final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(data as Map);

      final list = map.entries.map((entry) {
        final value = Map<dynamic, dynamic>.from(entry.value as Map);

        if (!value.containsKey("lastSeen") && value.containsKey("lastseen")) {
          value["lastSeen"] = value["lastseen"];
        }

        return Telemetry.fromMap(value);
      }).toList();

      list.sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
      return list;
    });
  }

  Future<void> setPumpCommand(String deviceId, String command) async {
    await commandsRef.child(deviceId).update({"pump": command});
  }

  Future<void> setMode(String deviceId, String mode) async {
    await commandsRef.child(deviceId).update({"mode": mode});
  }

  Future<List<Zone>> getZones(String farmId) async {
    final snapshot = await farmsRef.child(farmId).child("zones").get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> data =
        Map<dynamic, dynamic>.from(snapshot.value as Map);

    return data.entries
        .map((entry) => Zone.fromMap(entry.key, entry.value))
        .toList();
  }

  Future<List<Device>> getDevicesByFarm(String farmId) async {
    final snapshot = await devicesRef.get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> data =
        Map<dynamic, dynamic>.from(snapshot.value as Map);

    return data.entries
        .map((entry) => Device.fromMap(entry.key, entry.value))
        .where((device) => device.farmId == farmId)
        .toList();
  }

  Future<List<Device>> getDevicesByFarmAndZone(
    String farmId,
    String zoneId,
  ) async {
    final snapshot = await devicesRef.get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> data =
        Map<dynamic, dynamic>.from(snapshot.value as Map);

    return data.entries
        .map((entry) => Device.fromMap(entry.key, entry.value))
        .where((device) => device.farmId == farmId && device.zoneId == zoneId)
        .toList();
  }

  Stream<Map<String, dynamic>?> getCommandStream(String deviceId) {
    return commandsRef.child(deviceId).onValue.map((event) {
      final data = event.snapshot.value;

      if (data == null) {
        return null;
      }

      return Map<String, dynamic>.from(data as Map);
    });
  }
}
