import 'package:flutter/material.dart';

class HabitModel {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;

  const HabitModel({required this.key, required this.title, required this.subtitle, required this.icon, this.completed = false});

  HabitModel copyWith({bool? completed}) => HabitModel(key: key, title: title, subtitle: subtitle, icon: icon, completed: completed ?? this.completed);
}

const List<HabitModel> habitCatalog = [
  HabitModel(key: 'train', title: 'Treinar o corpo', subtitle: '45 min', icon: Icons.fitness_center_outlined),
  HabitModel(key: 'read', title: 'Ler ou estudar', subtitle: '30 min', icon: Icons.menu_book_outlined),
  HabitModel(key: 'digital_fast', title: 'Sem pornografia', subtitle: 'Meta do dia', icon: Icons.water_drop_outlined),
  HabitModel(key: 'meditate', title: 'Meditar / Orar', subtitle: '10 min', icon: Icons.self_improvement_outlined),
  HabitModel(key: 'sleep_early', title: 'Dormir cedo', subtitle: 'Meta: 22:30', icon: Icons.nightlight_outlined),
];
