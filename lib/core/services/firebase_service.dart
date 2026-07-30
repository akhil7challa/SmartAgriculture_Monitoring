import 'package:firebase_database/firebase_database.dart';

import '../../models/farm.dart';
import '../../models/device.dart';
import '../../models/telemetry.dart';
import '../../models/zone.dart';

enum GraphPeriod {
  day,
  week,
  month,
  year,
}

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

  Future<Farm?> getFarmById(String farmId) async {
    final snapshot = await farmsRef.child(farmId).get();

    if (!snapshot.exists) {
      return null;
    }

    return Farm.fromMap(
      farmId,
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
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

  Future<Device?> getDeviceById(String deviceId) async {
    final snapshot = await devicesRef.child(deviceId).get();

    if (!snapshot.exists) {
      return null;
    }

    return Device.fromMap(
      deviceId,
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
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

  DateTime getStartDateForPeriod(GraphPeriod period) {
    final now = DateTime.now();

    switch (period) {
      case GraphPeriod.day:
        return now.subtract(const Duration(days: 1));
      case GraphPeriod.week:
        return now.subtract(const Duration(days: 7));
      case GraphPeriod.month:
        return DateTime(
          now.year,
          now.month - 1,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
      case GraphPeriod.year:
        return DateTime(
          now.year - 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
    }
  }

  Stream<List<Telemetry>> getTelemetryHistoryByPeriodStream(
    String deviceId, {
    required GraphPeriod period,
    int limit = 5000,
  }) {
    final startDate = getStartDateForPeriod(period);
    final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;

    return telemetryRef
        .child(deviceId)
        .child("historydata")
        .orderByChild("lastSeen")
        .startAt(startTimestamp)
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

  Future<Zone?> getZoneById(String farmId, String zoneId) async {
    final snapshot =
        await farmsRef.child(farmId).child("zones").child(zoneId).get();

    if (!snapshot.exists) {
      return null;
    }

    return Zone.fromMap(
      zoneId,
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
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

  Future<void> cleanupOldTelemetryHistory(
    String deviceId, {
    int keepLatest = 1000,
  }) async {
    final historyRef = telemetryRef.child(deviceId).child("historydata");
    final snapshot = await historyRef.get();

    if (!snapshot.exists) {
      return;
    }

    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

    final entries = data.entries.map((entry) {
      final value = Map<dynamic, dynamic>.from(entry.value as Map);

      final lastSeen = value["lastSeen"] ?? value["lastseen"] ?? 0;

      return {
        "key": entry.key.toString(),
        "lastSeen": (lastSeen as num).toInt(),
      };
    }).toList();

    if (entries.length <= keepLatest) {
      return;
    }

    entries.sort((a, b) {
      return (a["lastSeen"] as int).compareTo(b["lastSeen"] as int);
    });

    final toDelete = entries.take(entries.length - keepLatest);

    for (final item in toDelete) {
      await historyRef.child(item["key"].toString()).remove();
    }
  }

  Future<void> saveZonePumpSchedule(
    String farmId,
    String zoneId,
    Map<String, dynamic> schedule,
  ) async {
    final cleanedSchedule = Map<String, dynamic>.from(schedule);
    cleanedSchedule.remove("turnOffAfterDuration");

    await farmsRef
        .child(farmId)
        .child("zones")
        .child(zoneId)
        .child("pumpSchedule")
        .set(cleanedSchedule);
  }

  Future<Map<String, dynamic>?> getZonePumpSchedule(
    String farmId,
    String zoneId,
  ) async {
    final snapshot = await farmsRef
        .child(farmId)
        .child("zones")
        .child(zoneId)
        .child("pumpSchedule")
        .get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final schedule = Map<String, dynamic>.from(snapshot.value as Map);
    schedule.remove("turnOffAfterDuration");
    return schedule;
  }

  Future<void> deleteZonePumpSchedule(
    String farmId,
    String zoneId,
  ) async {
    await farmsRef
        .child(farmId)
        .child("zones")
        .child(zoneId)
        .child("pumpSchedule")
        .remove();
  }

  Stream<Map<String, dynamic>?> getZonePumpScheduleStream(
    String farmId,
    String zoneId,
  ) {
    return farmsRef
        .child(farmId)
        .child("zones")
        .child(zoneId)
        .child("pumpSchedule")
        .onValue
        .map((event) {
      final data = event.snapshot.value;

      if (data == null) {
        return null;
      }

      final schedule = Map<String, dynamic>.from(data as Map);
      schedule.remove("turnOffAfterDuration");
      return schedule;
    });
  }

  Future<void> removeLegacyTurnOffAfterDuration(
    String farmId,
    String zoneId,
  ) async {
    await farmsRef
        .child(farmId)
        .child("zones")
        .child(zoneId)
        .child("pumpSchedule")
        .child("turnOffAfterDuration")
        .remove();
  }
}
