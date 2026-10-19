import 'package:flutter/material.dart';

class RoutineLocalReminder {
  const RoutineLocalReminder({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    this.skipToday = false,
  });

  final int id;
  final TimeOfDay time;
  final String title;
  final String body;
  final bool skipToday;
}
