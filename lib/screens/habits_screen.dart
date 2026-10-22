import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/feedback/tap_feedback.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/habit_model.dart';
import '../services/habit_service.dart';
import '../services/habit_reminder_service.dart';
import '../services/notification_push_service.dart';
import '../services/routine_local_notification_scheduler.dart';
import '../widgets/animated_entry.dart';
import '../widgets/habit_item_card.dart';
import '../widgets/habit_sync_notice.dart';
import '../widgets/pbh_app_drawer.dart';
import '../widgets/pbh_app_header.dart';
import '../widgets/pbh_bottom_nav.dart';

class HabitsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  final int currentIndex;
  final bool isAuthenticated;
  final bool isAdmin;
  final int unreadNotifications;
  final int notificationPulseKey;
  final VoidCallback? onLogoPressed;
  final VoidCallback? onAccountAction;
  final VoidCallback? onNotificationsChanged;
  final VoidCallback? onRequireLogin;

  const HabitsScreen({
    super.key,
    this.onNavigate,
    this.currentIndex = 0,
    this.isAuthenticated = false,
    this.isAdmin = false,
    this.unreadNotifications = 0,
    this.notificationPulseKey = 0,
    this.onLogoPressed,
    this.onAccountAction,
    this.onNotificationsChanged,
    this.onRequireLogin,
  });

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _service = HabitService();
  final _reminderService = HabitReminderService();
  late List<HabitModel> _habits;
  late int _selectedDay;
  List<int> _weekCounts = List.filled(7, 0);
  Set<String> _selectedHabitKeys = HabitService.habitKeys.toSet();
  int _streak = 0;
  bool _loading = true;
  int _pendingChanges = 0;
  int _loadVersion = 0;
  bool _reminderLoading = true;
  bool _reminderSaving = false;
  HabitReminderSettings _reminderSettings = const HabitReminderSettings();
  final Set<String> _saving = {};

  List<DateTime> get _currentWeek {
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    return List<DateTime>.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );
  }

  DateTime get _selectedDate => _currentWeek[_selectedDay];
  int get _completedCount => _habits.where((habit) => habit.completed).length;
  bool get _reminderNotificationsSupported => kIsWeb
      ? NotificationPushService.isSupported
      : RoutineLocalNotificationScheduler.isSupported;
  bool get _reminderNotificationsConfigured =>
      !kIsWeb || NotificationPushService.isConfigured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _habits = List.of(habitCatalog);
    _selectedDay = DateTime.now().weekday - 1;
    _load();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      if (mounted) setState(() => _reminderLoading = false);
      return;
    }
    try {
      final settings = await _reminderService.load();
      if (mounted) {
        setState(() {
          _reminderSettings = settings;
          _reminderLoading = false;
        });
        if (settings.enabled && !_loading) {
          unawaited(_synchronizeNativeReminder());
        }
      }
    } catch (_) {
      if (mounted) setState(() => _reminderLoading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  Future<void> _setReminderEnabled(bool enabled) async {
    if (_reminderSaving) return;
    if (enabled && !_reminderNotificationsSupported) {
      _showReminderMessage(
        'Este aparelho não oferece suporte a notificações locais.',
      );
      return;
    }
    if (enabled && !_reminderNotificationsConfigured) {
      _showReminderMessage(
        'As notificações ainda não foram configuradas para este site.',
      );
      return;
    }
    setState(() => _reminderSaving = true);
    try {
      if (enabled) {
        await _reminderService.enable(
          _reminderSettings.time,
          _selectedHabitKeys,
          pendingHabitKeys: _habits
              .where((habit) => !habit.completed)
              .map((habit) => habit.key)
              .toSet(),
        );
      } else {
        await _reminderService.save(
          enabled: false,
          time: _reminderSettings.time,
          selectedHabitKeys: _selectedHabitKeys,
        );
        await _reminderService.synchronizeLocalSchedule(
          enabled: false,
          time: _reminderSettings.time,
          selectedHabitKeys: _selectedHabitKeys,
          pendingHabitKeys: const {},
        );
      }
      if (!mounted) return;
      setState(
        () => _reminderSettings = _reminderSettings.copyWith(enabled: enabled),
      );
      final now = TimeOfDay.now();
      final selectedTimeHasPassed =
          _reminderSettings.time.hour < now.hour ||
          (_reminderSettings.time.hour == now.hour &&
              _reminderSettings.time.minute <= now.minute);
      _showReminderMessage(
        enabled
            ? selectedTimeHasPassed
                  ? 'Lembretes ativados. Esse horário já passou hoje; o próximo aviso será amanhã.'
                  : 'Lembretes da rotina ativados.'
            : 'Lembretes da rotina pausados.',
      );
    } catch (error) {
      if (mounted) _showReminderMessage(_friendlyReminderError(error));
    } finally {
      if (mounted) setState(() => _reminderSaving = false);
    }
  }

  Future<void> _chooseReminderTime() async {
    final now = DateTime.now();
    final initial = DateTime(
      now.year,
      now.month,
      now.day,
      _reminderSettings.time.hour,
      _reminderSettings.time.minute,
    );
    final time = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pbhColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var selected = initial;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: context.pbhColors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Horario dos lembretes',
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      Text(
                        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: context.pbhColors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 176,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Brightness.dark,
                        primaryColor: context.pbhColors.orange,
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: initial,
                        use24hFormat: true,
                        onDateTimeChanged: (value) =>
                            setSheetState(() => selected = value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            TimeOfDay(
                              hour: selected.hour,
                              minute: selected.minute,
                            ),
                          ),
                          child: const Text('Confirmar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (time == null || !mounted) return;
    if (_reminderSettings.enabled &&
        !kIsWeb &&
        !await RoutineLocalNotificationScheduler.requestPermission()) {
      _showReminderMessage(
        'Permita as notificações e “Alarmes e lembretes” do PBH para atualizar o horário.',
      );
      return;
    }
    final previousSettings = _reminderSettings;
    setState(() {
      _reminderSettings = _reminderSettings.copyWith(time: time);
      _reminderSaving = true;
    });
    try {
      await _reminderService.save(
        enabled: _reminderSettings.enabled,
        time: time,
        selectedHabitKeys: _selectedHabitKeys,
      );
      await _synchronizeNativeReminder(time: time);
    } catch (error) {
      if (mounted) {
        setState(() => _reminderSettings = previousSettings);
        _showReminderMessage(_friendlyReminderError(error));
      }
    } finally {
      if (mounted) setState(() => _reminderSaving = false);
    }
  }

  String _friendlyReminderError(Object error) {
    final message = error.toString();
    if (message.contains('habit_reminder_settings'))
      return 'Aplique a migration de lembretes no Supabase para ativar este recurso.';
    if (message.contains('Permissão') || message.contains('permission'))
      return 'Permita as notificações do PBH e o acesso a “Alarmes e lembretes” nas configurações do Android.';
    return 'Não foi possível salvar os lembretes. Confira sua conexão e tente de novo.';
  }

  void _showReminderMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _synchronizeNativeReminder({
    TimeOfDay? time,
    Set<String>? pendingHabitKeys,
  }) async {
    if (kIsWeb) return;
    try {
      await _reminderService.synchronizeLocalSchedule(
        enabled: _reminderSettings.enabled,
        time: time ?? _reminderSettings.time,
        selectedHabitKeys: _selectedHabitKeys,
        pendingHabitKeys:
            pendingHabitKeys ??
            _habits
                .where((habit) => !habit.completed)
                .map((habit) => habit.key)
                .toSet(),
      );
    } catch (error) {
      if (mounted) {
        debugPrint('Falha ao sincronizar lembretes locais: $error');
        _showReminderMessage(
          'Não foi possível agendar os lembretes. Confira as permissões de notificação e “Alarmes e lembretes” do PBH.',
        );
      }
    }
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    _service.resetReadStatus();
    try {
      await _service.syncPending();
      final selectedKeys = await _service.selectedHabitKeys();
      final values = await Future.wait([
        _service.completedOn(_selectedDate),
        _service.weekCounts(DateTime.now(), selectedHabits: selectedKeys),
        _service.streak(habitKeysForStreak: selectedKeys),
      ]);
      final pending = await _service.pendingChanges();
      if (!mounted || version != _loadVersion) return;
      final completed = values[0] as Set<String>;
      final currentUser = Supabase.instance.client.auth.currentUser;
      final isProjectLeader =
          currentUser?.email?.toLowerCase() == 'amaralaragao31@gmail.com';
      final today = DateTime.now();
      final projectDays =
          DateTime.utc(
            today.year,
            today.month,
            today.day,
          ).difference(DateTime.utc(2021, 1, 1)).inDays +
          1;
      setState(() {
        _selectedHabitKeys = selectedKeys;
        _habits = habitCatalog
            .where((habit) => selectedKeys.contains(habit.key))
            .map(
              (habit) =>
                  habit.copyWith(completed: completed.contains(habit.key)),
            )
            .toList();
        _weekCounts = values[1] as List<int>;
        _streak = currentUser == null
            ? 0
            : isProjectLeader
            ? projectDays
            : values[2] as int;
        _loading = false;
        _pendingChanges = pending;
      });
      if (_selectedDate.year == today.year &&
          _selectedDate.month == today.month &&
          _selectedDate.day == today.day) {
        unawaited(
          _synchronizeNativeReminder(
            pendingHabitKeys: _habits
                .where((habit) => !habit.completed)
                .map((habit) => habit.key)
                .toSet(),
          ),
        );
      }
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar sua rotina: $error'),
          ),
        );
      }
    }
  }

  Future<void> _chooseHabits() async {
    final selected = Set<String>.of(_selectedHabitKeys);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pbhColors.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monte sua rotina', style: AppTextStyles.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Escolha os compromissos que quer acompanhar. Você pode mudar isso quando precisar.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                ...habitCatalog.map(
                  (habit) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: context.pbhColors.orange,
                    title: Text(
                      habit.title,
                      style: AppTextStyles.titleMedium.copyWith(fontSize: 15),
                    ),
                    subtitle: Text(
                      habit.subtitle,
                      style: AppTextStyles.bodySmall,
                    ),
                    value: selected.contains(habit.key),
                    onChanged: (value) {
                      if (value == false && selected.length == 1) return;
                      setSheetState(() {
                        value == true
                            ? selected.add(habit.key)
                            : selected.remove(habit.key);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('Salvar rotina'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    await _service.saveSelectedHabitKeys(result);
    try {
      await _reminderService.syncSelectedHabits(result);
    } catch (_) {
      if (mounted)
        _showReminderMessage(
          'Rotina salva. Não foi possível atualizar as preferências dos lembretes.',
        );
    }
    if (mounted) {
      setState(() => _loading = true);
      await _load();
    }
  }

  Future<void> _toggleHabit(int index, bool value) async {
    final habit = _habits[index];
    final today = DateTime.now();
    final selected = _selectedDate;
    final selectedStart = DateTime(selected.year, selected.month, selected.day);
    final todayStart = DateTime(today.year, today.month, today.day);
    if (selectedStart.isAfter(todayStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não pode registrar um dia futuro.')),
      );
      return;
    }
    final completesRoutine =
        value && !habit.completed && _completedCount + 1 == _habits.length;
    setState(() {
      _habits[index] = habit.copyWith(completed: value);
      _saving.add(habit.key);
    });
    try {
      await _service.setCompleted(habit.key, selected, value);
      await _load();
      if (completesRoutine && mounted)
        _showRoutineCompleteToast(forToday: selectedStart == todayStart);
    } catch (error) {
      if (mounted) {
        setState(() => _habits[index] = habit.copyWith(completed: !value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar o hábito: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(habit.key));
    }
  }

  void _showRoutineCompleteToast({required bool forToday}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.pbhColors.surface,
        elevation: 12,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: context.pbhColors.orange.withOpacity(.55)),
        ),
        content: TweenAnimationBuilder<double>(
          tween: Tween(begin: .88, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.pbhColors.orangeDim,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: context.pbhColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rotina concluída!',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.pbhColors.orange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      forToday
                          ? 'Disciplina hoje. Liberdade amanhã.'
                          : 'Progresso registrado para este dia.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                color: context.pbhColors.orange,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareWeeklySummary() async {
    final completed = _weekCounts.fold<int>(0, (total, count) => total + count);
    final activeDays = _weekCounts.where((count) => count > 0).length;
    await Share.share(
      'Meu resumo da semana no PBH: $completed hábitos concluídos em $activeDays dias. '
      'Um compromisso de cada vez.',
      subject: 'Meu resumo semanal PBH',
    );
  }

  void _handleBottomTap(int index) {
    if (widget.onNavigate != null) {
      Navigator.of(context).pop();
      widget.onNavigate!(index);
    } else if (index == 0) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = _currentWeek;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.pbhColors.background,
      drawer: PbhAppDrawer(
        currentIndex: widget.currentIndex,
        onNavigate: _handleBottomTap,
        onOpenHabits: () {},
        onAccountAction: widget.onAccountAction ?? () {},
        isAuthenticated: widget.isAuthenticated,
        isOnHabits: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PbhAppHeader(
              currentSection: 'Rotina de hábitos',
              onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              onLogoPressed:
                  widget.onLogoPressed ??
                  () => Navigator.of(context).maybePop(),
              unreadNotifications: widget.unreadNotifications,
              notificationPulseKey: widget.notificationPulseKey,
              onNotificationsChanged: widget.onNotificationsChanged ?? () {},
              showNotifications: widget.isAuthenticated,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  HabitSyncNotice(
                    pending: _pendingChanges,
                    cached: _service.isUsingCachedData,
                    onRetry: _load,
                  ),
                  AnimatedEntry(
                    child: Text(
                      'Rotina de Hábitos',
                      style: AppTextStyles.brandHeadline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedEntry(
                    child: SizedBox(
                      height: 68,
                      child: Row(
                        children: List.generate(week.length, (index) {
                          final day = week[index];
                          final selected = index == _selectedDay;
                          final future = DateTime(
                            day.year,
                            day.month,
                            day.day,
                          ).isAfter(DateTime.now());
                          return Expanded(
                            child: GestureDetector(
                              onTap: future
                                  ? null
                                  : () {
                                      lightTapFeedback();
                                      setState(() {
                                        _selectedDay = index;
                                        _loading = true;
                                      });
                                      _load();
                                    },
                              child: Opacity(
                                opacity: future ? .4 : 1,
                                child: Column(
                                  children: [
                                    Text(
                                      const [
                                        'Seg',
                                        'Ter',
                                        'Qua',
                                        'Qui',
                                        'Sex',
                                        'Sáb',
                                        'Dom',
                                      ][index],
                                      style: AppTextStyles.statLabel.copyWith(
                                        fontSize: 10,
                                        color: selected
                                            ? context.pbhColors.textPrimary
                                            : context.pbhColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      width: selected ? 42 : 34,
                                      height: selected ? 42 : 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected
                                            ? context.pbhColors.orangeDim
                                            : context
                                                  .pbhColors
                                                  .backgroundElevated,
                                        border: Border.all(
                                          color: selected
                                              ? context.pbhColors.orange
                                              : context.pbhColors.borderSubtle,
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${day.day}',
                                        style: AppTextStyles.titleMedium
                                            .copyWith(
                                              fontSize: 14,
                                              color: selected
                                                  ? context.pbhColors.orange
                                                  : context
                                                        .pbhColors
                                                        .textPrimary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedEntry(
                    delayMs: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDay == DateTime.now().weekday - 1
                              ? 'Hoje'
                              : '${_selectedDate.day}/${_selectedDate.month}',
                          style: AppTextStyles.titleMedium,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              key: ValueKey('routine-count-$_completedCount'),
                              tween: Tween(begin: .78, end: 1),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              builder: (context, scale, child) =>
                                  Transform.scale(
                                    scale: scale,
                                    alignment: Alignment.centerRight,
                                    child: child,
                                  ),
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.bodySmall,
                                  children: [
                                    TextSpan(
                                      text:
                                          '$_completedCount/${_habits.length}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: context.pbhColors.orange,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const TextSpan(text: ' concluídos'),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Escolher hábitos da rotina',
                              onPressed: _chooseHabits,
                              icon: Icon(
                                Icons.tune_rounded,
                                color: context.pbhColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedEntry(delayMs: 75, child: _buildReminderCard()),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ...List.generate(_habits.length, (index) {
                      final habit = _habits[index];
                      return AnimatedEntry(
                        delayMs: 90 + index * 35,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: HabitItemCard(
                            habit: habit,
                            onToggle: _saving.contains(habit.key)
                                ? null
                                : (value) => _toggleHabit(index, value),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  AnimatedEntry(
                    delayMs: 270,
                    child: _WeeklySummaryCard(
                      counts: _weekCounts,
                      onShare: _shareWeeklySummary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (Supabase.instance.client.auth.currentUser != null)
                    AnimatedEntry(
                      delayMs: 300,
                      child: _StreakCard(
                        streak: _streak,
                        counts: _weekCounts,
                        habitTotal: _habits.length,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PbhBottomNav(
        currentIndex: widget.currentIndex,
        onTap: _handleBottomTap,
        isAdmin: widget.isAdmin,
      ),
    );
  }

  Widget _buildReminderCard() {
    final authenticated = Supabase.instance.client.auth.currentUser != null;
    final enabled = _reminderSettings.enabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pbhColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled
              ? context.pbhColors.orange.withOpacity(.55)
              : context.pbhColors.borderSubtle,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: context.pbhColors.orange.withOpacity(.08),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: _reminderLoading
          ? const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Carregando lembretes…'),
              ],
            )
          : !authenticated
          ? Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: context.pbhColors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lembretes no celular',
                        style: AppTextStyles.titleMedium.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Entre para receber um aviso quando houver tarefas pendentes.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onRequireLogin,
                  child: const Text('Entrar'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: enabled
                            ? context.pbhColors.orangeDim
                            : context.pbhColors.backgroundElevated,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        enabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: context.pbhColors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lembretes da rotina',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Um toque de disciplina nos dias corridos.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: enabled,
                      onChanged: _reminderSaving ? null : _setReminderEnabled,
                      activeColor: context.pbhColors.orange,
                    ),
                  ],
                ),
                if (enabled || _reminderNotificationsConfigured) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _reminderSaving ? null : _chooseReminderTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.pbhColors.backgroundElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: context.pbhColors.orange,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              enabled
                                  ? 'Avisar às ${_reminderSettings.time.format(context)} se ainda houver tarefas pendentes'
                                  : 'Escolha o horário do lembrete diário',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                          if (_reminderSaving)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 19,
                              color: context.pbhColors.textSecondary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (enabled) ...[
                  const SizedBox(height: 9),
                  Text(
                    'Cada tarefa tem um prazo automático: treino 20h, leitura e meditação 21h, foco 21h30 e descanso 22h. Seu horário escolhido continua como lembrete geral.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
                if (!_reminderNotificationsConfigured) ...[
                  const SizedBox(height: 9),
                  Text(
                    'As notificações precisam ser habilitadas na configuração do site.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({required this.counts, required this.onShare});
  final List<int> counts;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final completed = counts.fold<int>(0, (total, count) => total + count);
    final activeDays = counts.where((count) => count > 0).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.pbhColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.pbhColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.pbhColors.orangeDim,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.insights_rounded,
              color: context.pbhColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo da semana',
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed hábitos em $activeDays ${activeDays == 1 ? 'dia' : 'dias'}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Compartilhar resumo semanal',
            onPressed: onShare,
            icon: Icon(Icons.share_outlined, color: context.pbhColors.orange),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.streak,
    required this.counts,
    required this.habitTotal,
  });
  final int streak;
  final List<int> counts;
  final int habitTotal;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.pbhColors.surface.withOpacity(.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.pbhColors.borderSubtle),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sequência atual', style: AppTextStyles.statLabel),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: context.pbhColors.orange,
                    size: 22,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '$streak',
                    style: AppTextStyles.statNumber.copyWith(fontSize: 26),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    streak == 1 ? 'dia' : 'dias',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final fraction =
                    (habitTotal == 0
                            ? .08
                            : (counts[index] / habitTotal).clamp(.08, 1.0))
                        .toDouble();
                final date = monday.add(Duration(days: index));
                const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300 + index * 45),
                        width: 5,
                        height: 30 * fraction,
                        decoration: BoxDecoration(
                          color: context.pbhColors.orange.withOpacity(
                            .26 + .74 * fraction,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[date.weekday - 1],
                        style: AppTextStyles.statLabel.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
