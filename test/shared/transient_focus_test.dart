import 'package:flule34/shared/transient_focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('关闭非输入弹层后不会恢复原输入框焦点', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(focusNode: focusNode),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () async {
                    await runWithoutRestoringInputFocus(
                      context,
                      () => showModalBottomSheet<void>(
                        context: context,
                        requestFocus: false,
                        builder: (context) => TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('关闭'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });
}
