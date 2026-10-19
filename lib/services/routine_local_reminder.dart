import 'package:flutter/material.dart';

class RoutineLocalReminder {
  const RoutineLocalReminder({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    this.largeIconResource = 'pbh_notification_large',
    this.skipToday = false,
  });

  final int id;
  final TimeOfDay time;
  final String title;
  final String body;
  final String largeIconResource;
  final bool skipToday;
}
