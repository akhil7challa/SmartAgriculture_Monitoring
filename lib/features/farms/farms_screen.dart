import 'package:flutter/material.dart';

import '../../shared/services/firebase_service.dart';
import '../../models/farm.dart';

class FarmsScreen extends StatefulWidget {
  const FarmsScreen({super.key});

  @override
  State<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends State<FarmsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  late Future<List<Farm>> farmsFuture;

  @override
  void initState() {
    super.initState();
    farmsFuture = _firebaseService.getAllFarms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Farms")),
      body: FutureBuilder<List<Farm>>(
        future: farmsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final farms = snapshot.data ?? [];

          if (farms.isEmpty) {
            return const Center(child: Text("No farms found"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: farms.length,
            itemBuilder: (context, index) {
              final farm = farms[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.agriculture)),
                  title: Text(farm.name),
                  subtitle: Text(farm.location),
                  trailing: ElevatedButton(
                    onPressed: () {},
                    child: const Text("Open"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
