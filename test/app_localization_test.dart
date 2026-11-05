import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/core/config/app_localization.dart';

void main() {
  testWidgets(
    'standard navigation and editing labels stay Portuguese on an English device',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale(
        'en',
        'US',
      );
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      late MaterialLocalizations labels;
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocalization.locale,
          supportedLocales: AppLocalization.supportedLocales,
          localizationsDelegates: AppLocalization.delegates,
          home: Builder(
            builder: (context) {
              labels = MaterialLocalizations.of(context);
              return const Scaffold(
                body: Row(children: [BackButton(), CloseButton()]),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Voltar'), findsOneWidget);
      expect(find.byTooltip('Fechar'), findsOneWidget);
      expect(labels.copyButtonLabel, 'Copiar');
      expect(labels.pasteButtonLabel, 'Colar');
      expect(labels.cutButtonLabel, 'Cortar');
      expect(labels.selectAllButtonLabel, 'Selecionar tudo');
      expect(labels.cancelButtonLabel.toLowerCase(), 'cancelar');
      expect(labels.showMenuTooltip.toLowerCase(), 'mostrar menu');
      expect(tester.takeException(), isNull);
    },
  );
}
