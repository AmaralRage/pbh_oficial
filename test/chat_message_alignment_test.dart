import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/chat_message_frame.dart';

void main() {
  for (final scale in [1.0, 1.8]) {
    for (final message in [
      'Suave',
      'Primeira linha\nSegunda linha com uma mensagem maior para testar o alinhamento.',
    ]) {
      testWidgets('text and footer fit at scale $scale: $message', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 700),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 300,
                    child: ChatMessageFrame(
                      mine: true,
                      grouped: false,
                      time: '21:54',
                      read: true,
                      text: message,
                      fontSize: 20,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final text = tester.getRect(find.byType(RichText).first);
        final time = tester.getRect(find.text('21:54'));
        final checks = tester.getRect(find.byIcon(Icons.done_all));
        expect(time.right, lessThanOrEqualTo(text.right));
        expect(checks.right, lessThanOrEqualTo(text.right + .01));
        expect(time.bottom, lessThanOrEqualTo(text.bottom + .01));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
