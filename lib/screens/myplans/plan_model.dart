import 'package:flutter/material.dart';

class Plan {
  final String title;
  final String date;
  final String location;
  final String status;
  final Color statusColor;
  final String imagePath;

  Plan({
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.statusColor,
    required this.imagePath,
  });
}
