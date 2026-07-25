import 'package:firebase_database/firebase_database.dart';
import '../../models/farm.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Read all farms
  Future<List<Farm>> getAllFarms() async {
    final snapshot = await _db.child("farms").get();

    List<Farm> farms = [];

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        farms.add(Farm.fromMap(key.toString(), value));
      });
    }

    return farms;
  }

  /// Create a new farm
  Future<void> createFarm({
    required String name,
    required String location,
  }) async {
    final farmRef = _db.child("farms").push();

    await farmRef.set({"name": name, "location": location, "zones": {}});
  }

  /// Delete a farm
  Future<void> deleteFarm(String farmId) async {
    await _db.child("farms").child(farmId).remove();
  }
}
