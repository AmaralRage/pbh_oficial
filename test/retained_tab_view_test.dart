import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/retained_tab_view.dart';

class Probe extends StatefulWidget {
  const Probe(this.name, this.created, {super.key});
  final String name;
  final List<String> created;
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  int count = 0;
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.name);
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('${widget.name}:$count:${TickerMode.of(context)}'),
  );
}

void main() {
  testWidgets(
    'tabs initialize lazily and preserve state while hidden tickers are disabled',
    (tester) async {
      final created = <String>[];
      Widget app(int index, {String account = 'a'}) => MaterialApp(
        home: RetainedTabView(
          key: ValueKey(account),
          index: index,
          children: [Probe('first', created), Probe('second', created)],
        ),
      );
      await tester.pumpWidget(app(0));
      expect(created, ['first']);
      await tester.tap(find.text('first:0:true'));
      await tester.pumpWidget(app(1));
      expect(created, ['first', 'second']);
      expect(find.text('first:1:false', skipOffstage: false), findsOneWidget);
      await tester.pumpWidget(app(0));
      expect(find.text('first:1:true'), findsOneWidget);
      expect(created.length, 2);
      await tester.pumpWidget(app(0, account: 'b'));
      expect(find.text('first:0:true'), findsOneWidget);
      expect(created.length, 3);
    },
  );
}
