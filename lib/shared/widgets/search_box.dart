import 'package:flutter/material.dart';

class SearchBox extends StatelessWidget {
  final TextEditingController controller;

  const SearchBox({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,

      child: TextField(
        controller: controller,

        decoration: InputDecoration(
          hintText: "Search farms...",

          prefixIcon: const Icon(Icons.search),

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

          filled: true,
        ),
      ),
    );
  }
}
