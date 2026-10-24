import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';

Future<TimeOfDay?> showScheduleTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) => showModalBottomSheet<TimeOfDay>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pbhColors.surface,
  constraints: const BoxConstraints(maxWidth: 460),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => ScheduleTimePicker(initialTime: initialTime),
);

class ScheduleTimePicker extends StatefulWidget {
  const ScheduleTimePicker({super.key, required this.initialTime});
  final TimeOfDay initialTime;

  @override
  State<ScheduleTimePicker> createState() => _ScheduleTimePickerState();
}

class _ScheduleTimePickerState extends State<ScheduleTimePicker> {
  final _form = GlobalKey<FormState>();
  late int _hour, _minute;
  late final FixedExtentScrollController _hours, _minutes;
  late final TextEditingController _hourText, _minuteText;
  bool _typing = false;

  String _digits(int value) => value.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hours = FixedExtentScrollController(initialItem: _hour);
    _minutes = FixedExtentScrollController(initialItem: _minute);
    _hourText = TextEditingController(text: _digits(_hour));
    _minuteText = TextEditingController(text: _digits(_minute));
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _hourText.dispose();
    _minuteText.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_typing) {
      if (!_form.currentState!.validate()) return;
      _hour = int.parse(_hourText.text);
      _minute = int.parse(_minuteText.text);
    }
    Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute));
  }

  void _toggleInput() {
    if (_typing) {
      if (!_form.currentState!.validate()) return;
      _hour = int.parse(_hourText.text);
      _minute = int.parse(_minuteText.text);
    } else {
      _hourText.text = _digits(_hour);
      _minuteText.text = _digits(_minute);
    }
    FocusScope.of(context).unfocus();
    setState(() => _typing = !_typing);
    if (!_typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hours.jumpToItem(_hour);
        _minutes.jumpToItem(_minute);
      });
    }
  }

  Widget _wheel(
    String label,
    int count,
    int selected,
    FixedExtentScrollController controller,
    ValueChanged<int> onChanged,
  ) {
    final colors = context.pbhColors;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 208,
            child: CupertinoPicker(
              scrollController: controller,
              itemExtent: 52,
              diameterRatio: 1.5,
              onSelectedItemChanged: onChanged,
              selectionOverlay: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.orangeDim,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.orange.withValues(alpha: .35),
                    ),
                  ),
                ),
              ),
              children: List.generate(
                count,
                (index) => Center(
                  child: Text(
                    _digits(index),
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: index == selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: index == selected
                          ? colors.orange
                          : colors.textTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, int maximum) =>
      Expanded(
        child: TextFormField(
          controller: controller,
          autofocus: label == 'Hora',
          keyboardType: TextInputType.number,
          textInputAction: label == 'Hora'
              ? TextInputAction.next
              : TextInputAction.done,
          onFieldSubmitted: label == 'Minuto' ? (_) => _confirm() : null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: context.pbhColors.orange,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            labelText: label,
            helperText: '00 a $maximum',
            filled: true,
            fillColor: context.pbhColors.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            return number == null || number < 0 || number > maximum
                ? 'Use 00 a $maximum'
                : null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.orangeDim,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.schedule_rounded, color: colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Horário do envio',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleInput,
                  tooltip: _typing ? 'Selecionar rolando' : 'Digitar horário',
                  icon: Icon(
                    _typing
                        ? Icons.swap_vert_rounded
                        : Icons.keyboard_alt_outlined,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _typing
                    ? 'Digite a hora e os minutos no formato 24 horas.'
                    : 'Deslize para escolher. Formato de 24 horas.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            if (_typing)
              Form(
                key: _form,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _input('Hora', _hourText, 23),
                    const SizedBox(width: 16),
                    _input('Minuto', _minuteText, 59),
                  ],
                ),
              )
            else
              Row(
                children: [
                  _wheel(
                    'Hora',
                    24,
                    _hour,
                    _hours,
                    (value) => setState(() => _hour = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 25, 12, 0),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 34,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  _wheel(
                    'Minuto',
                    60,
                    _minute,
                    _minutes,
                    (value) => setState(() => _minute = value),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
