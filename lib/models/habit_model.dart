import 'package:flutter/material.dart';

class HabitModel {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;

  const HabitModel({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.completed = false,
  });
}

const List<HabitModel> mockHabits = [
  HabitModel(
    title: 'Treinar o corpo',
    subtitle: '45 min',
    icon: Icons.fitness_center_outlined,
    completed: true,
  ),
  HabitModel(
    title: 'Ler ou estudar',
    subtitle: '30 min',
    icon: Icons.menu_book_outlined,
    completed: true,
  ),
  HabitModel(
    title: 'Sem pornografia',
    subtitle: 'Meta do dia',
    icon: Icons.water_drop_outlined,
    completed: true,
  ),
  HabitModel(
    title: 'Meditar / Orar',
    subtitle: '10 min',
    icon: Icons.self_improvement_outlined,
    completed: true,
  ),
  HabitModel(
    title: 'Dormir cedo',
    subtitle: 'Meta: 22:30',
    icon: Icons.nightlight_outlined,
    completed: false,
  ),
];
