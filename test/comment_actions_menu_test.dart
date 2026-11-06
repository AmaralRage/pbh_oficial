import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/core/theme/pbh_palette.dart';
import 'package:pbh_oficial/widgets/comment_actions_menu.dart';

void main() {
  testWidgets(
    'comment actions respect ownership and dispatch the selected action',
    (tester) async {
      String? action;
      Future<void> open(bool own) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CommentActionsMenu(
                isOwn: own,
                enabled: true,
                onSelected: (value) => action = value,
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Opções do comentário'));
        await tester.pumpAndSettle();
      }

      await open(false);
      expect(find.text('Responder'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Excluir'), findsNothing);
      await tester.tap(find.text('Responder'));
      await tester.pumpAndSettle();
      expect(action, 'reply');
      await open(true);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(action, 'delete');
    },
  );

  testWidgets(
    'themed menu remains readable with enlarged text on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final palette = PbhPalette.catalog.firstWhere((p) => p.id == 'founder');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [palette]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: CommentActionsMenu(
                isOwn: true,
                enabled: true,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Opções do comentário'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Responder'), findsOneWidget);
      final replyIcon = tester.widget<Icon>(find.byIcon(Icons.reply_rounded));
      expect(replyIcon.color, palette.accent);
      expect(
        tester.getSize(find.byType(PopupMenuItem<String>).first).height,
        greaterThanOrEqualTo(48),
      );
    },
  );
}
