import 'package:flutter/material.dart';

class NutritionTargetField extends StatelessWidget {
  const NutritionTargetField(
      {super.key, required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()));
}
