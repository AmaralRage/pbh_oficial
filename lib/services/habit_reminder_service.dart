import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_time_zone.dart';
import 'notification_push_service.dart';
import 'routine_local_notification_scheduler.dart';

class HabitReminderSettings {
  const HabitReminderSettings({
    this.enabled = false,
    this.time = const TimeOfDay(hour: 20, minute: 0),
  });

  final bool enabled;
  final TimeOfDay time;

  HabitReminderSettings copyWith({bool? enabled, TimeOfDay? time}) =>
      HabitReminderSettings(
          enabled: enabled ?? this.enabled, time: time ?? this.time);
}

class HabitReminderService {
  HabitReminderService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static String get _deliveryMode => kIsWeb ? 'web' : 'native';

  static const _habitReminders = <String, _HabitReminderCopy>{
    'train': _HabitReminderCopy(
        label: 'Treinar o corpo',
        largeIconResource: 'notification_habit_train',
        deadline: TimeOfDay(hour: 20, minute: 0),
        title: '🏋️ Seu treino ainda cabe no dia',
        body:
            '45 minutos para cumprir o compromisso que você assumiu consigo.'),
    'read': _HabitReminderCopy(
        label: 'Ler ou estudar',
        largeIconResource: 'notification_habit_read',
        deadline: TimeOfDay(hour: 21, minute: 0),
        title: '📚 Alimente sua mente hoje',
        body:
            'Separe 30 minutos para ler ou estudar. Um pouco todos os dias transforma o futuro.'),
    'digital_fast': _HabitReminderCopy(
        label: 'Sem pornografia',
        largeIconResource: 'notification_habit_focus',
        deadline: TimeOfDay(hour: 21, minute: 30),
        title: '🧭 Proteja o foco que você construiu',
        body:
            'Sua meta de hoje continua em andamento. Escolha o que fortalece sua liberdade.'),
    'meditate': _HabitReminderCopy(
        label: 'Meditar / Orar',
        largeIconResource: 'notification_habit_meditate',
        deadline: TimeOfDay(hour: 21, minute: 0),
        title: '🧘 Reserve um momento para se alinhar',
        body:
            'Dez minutos de silêncio, meditação ou oração também fazem parte da disciplina.'),
    'sleep_early': _HabitReminderCopy(
        label: 'Dormir cedo',
        largeIconResource: 'notification_habit_sleep',
        deadline: TimeOfDay(hour: 22, minute: 0),
        title: '🌙 Prepare-se para descansar',
        body:
            'Desacelere agora para proteger sua meta de dormir cedo e recomeçar bem amanhã.'),
  };

  Future<HabitReminderSettings> load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const HabitReminderSettings();
    final row = await _client
        .from('habit_reminder_settings')
        .select('enabled, reminder_time')
        .eq('user_id', userId)
        .eq('delivery_mode', _deliveryMode)
        .maybeSingle();
    if (row == null) return const HabitReminderSettings();
    final parts = (row['reminder_time'] as String).split(':');
    return HabitReminderSettings(
      enabled: row['enabled'] as bool? ?? false,
      time: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
  }

  Future<void> save(
      {required bool enabled,
      required TimeOfDay time,
      required Set<String> selectedHabitKeys}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null)
      throw StateError('Entre na sua conta para configurar lembretes.');
    if (selectedHabitKeys.isEmpty)
      throw ArgumentError('Selecione pelo menos um hábito.');
    final zone = await DeviceTimeZone.current();
    await _client.from('habit_reminder_settings').upsert({
      'user_id': userId,
      'delivery_mode': _deliveryMode,
      'enabled': enabled,
      'reminder_time':
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
      'time_zone': zone,
      'selected_habit_keys': selectedHabitKeys.toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,delivery_mode');
  }

  Future<void> syncSelectedHabits(Set<String> keys) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final row = await _client
        .from('habit_reminder_settings')
        .select('enabled, reminder_time')
        .eq('user_id', userId)
        .eq('delivery_mode', _deliveryMode)
        .maybeSingle();
    if (row == null) return;
    final parts = (row['reminder_time'] as String).split(':');
    await save(
      enabled: row['enabled'] as bool? ?? false,
      time: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      selectedHabitKeys: keys,
    );
  }

  Future<void> enable(
    TimeOfDay time,
    Set<String> selectedHabitKeys, {
    Set<String> pendingHabitKeys = const {},
  }) async {
    if (kIsWeb) {
      await NotificationPushService.subscribe();
    } else if (!await RoutineLocalNotificationScheduler.requestPermission()) {
      throw StateError(
          'Permissão de notificações ou Alarmes e lembretes não concedida.');
    }
    await save(enabled: true, time: time, selectedHabitKeys: selectedHabitKeys);
    await synchronizeLocalSchedule(
      enabled: true,
      time: time,
      selectedHabitKeys: selectedHabitKeys,
      pendingHabitKeys: pendingHabitKeys,
    );
  }

  Future<void> synchronizeLocalSchedule({
    required bool enabled,
    required TimeOfDay time,
    required Set<String> selectedHabitKeys,
    required Set<String> pendingHabitKeys,
  }) async {
    if (kIsWeb) return;
    if (!enabled) {
      await RoutineLocalNotificationScheduler.cancel();
      return;
    }

    final now = TimeOfDay.now();
    final todayPending = selectedHabitKeys.intersection(pendingHabitKeys);
    final reminders = <RoutineLocalReminder>[];
    for (final entry in _habitReminders.entries) {
      if (!selectedHabitKeys.contains(entry.key)) continue;
      final copy = entry.value;
      reminders.add(RoutineLocalReminder(
        id: 47101 + _habitReminders.keys.toList().indexOf(entry.key),
        time: copy.deadline,
        title: copy.title,
        body: copy.body,
        largeIconResource: copy.largeIconResource,
        skipToday: !todayPending.contains(entry.key) ||
            _hasReached(now, copy.deadline),
      ));
    }
    final pendingCopies = todayPending
        .map((key) => _habitReminders[key])
        .whereType<_HabitReminderCopy>()
        .toList();
    final selectedReminderCopy =
        pendingCopies.isEmpty ? null : pendingCopies.first;
    reminders.add(RoutineLocalReminder(
      id: 47001,
      time: time,
      title: selectedReminderCopy?.title ?? 'Sua rotina recomeça amanhã',
      body: selectedReminderCopy == null
          ? 'Escolha um novo passo e mantenha a disciplina. O progresso se constrói um dia de cada vez.'
          : '${selectedReminderCopy.label} ainda está pendente. ${selectedReminderCopy.body}',
      largeIconResource:
          selectedReminderCopy?.largeIconResource ?? 'pbh_notification_large',
      skipToday: _hasReached(now, time) || pendingCopies.isEmpty,
    ));
    await RoutineLocalNotificationScheduler.scheduleDaily(reminders);
  }

  bool _hasReached(TimeOfDay now, TimeOfDay target) =>
      now.hour > target.hour ||
      (now.hour == target.hour && now.minute >= target.minute);
}

class _HabitReminderCopy {
  const _HabitReminderCopy(
      {required this.label,
      required this.largeIconResource,
      required this.deadline,
      required this.title,
      required this.body});
  final String label;
  final String largeIconResource;
  final TimeOfDay deadline;
  final String title;
  final String body;
}
