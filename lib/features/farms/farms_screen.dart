import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../models/farm.dart';
import '../../shared/widgets/farm_card.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/search_box.dart';
import '../../shared/widgets/summary_card.dart';
import 'farm_details_screen.dart';

class FarmsScreen extends StatefulWidget {
  const FarmsScreen({super.key});

  @override
  State<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends State<FarmsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  late Future<List<Farm>> farmsFuture;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    farmsFuture = _firebaseService.getAllFarms();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Farm>>(
      future: farmsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        List<Farm> farms = snapshot.data ?? [];

        // Search Filter
        if (searchController.text.isNotEmpty) {
          farms = farms.where((farm) {
            return farm.name.toLowerCase().contains(
                  searchController.text.toLowerCase(),
                ) ||
                farm.location.toLowerCase().contains(
                  searchController.text.toLowerCase(),
                );
          }).toList();
        }

        return Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: "Farms",
                subtitle: "Manage all your farms from one place.",
                action: ElevatedButton.icon(
                  onPressed: () {
                    // We'll implement this in the next step
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("New Farm"),
                ),
              ),

              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.4,
                children: [
                  SummaryCard(
                    title: "Farms",
                    value: farms.length.toString(),
                    icon: Icons.agriculture,
                    color: Colors.green,
                  ),
                  const SummaryCard(
                    title: "Zones",
                    value: "1",
                    icon: Icons.map,
                    color: Colors.blue,
                  ),
                  const SummaryCard(
                    title: "Devices",
                    value: "1",
                    icon: Icons.memory,
                    color: Colors.orange,
                  ),
                  const SummaryCard(
                    title: "Online",
                    value: "1",
                    icon: Icons.wifi,
                    color: Colors.teal,
                  ),
                ],
              ),

              const SizedBox(height: 30),

              SearchBox(controller: searchController),

              const SizedBox(height: 30),

              Expanded(
                child: farms.isEmpty
                    ? const Center(
                        child: Text(
                          "No farms found",
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 1;

                          if (constraints.maxWidth > 700) {
                            crossAxisCount = 2;
                          }

                          if (constraints.maxWidth > 1100) {
                            crossAxisCount = 3;
                          }

                          if (constraints.maxWidth > 1500) {
                            crossAxisCount = 4;
                          }

                          return GridView.builder(
                            itemCount: farms.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 1.25,
                                ),
                            itemBuilder: (context, index) {
                              final farm = farms[index];

                              return FarmCard(
                                farm: farm,
                                onOpen: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FarmDetailsScreen(farm: farm),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
