import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/content_source.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/auth/login_sheet.dart';

import '../../helpers/test_session_harness.dart';

class _FakeLoginApi extends Rule34VideoApi {
  _FakeLoginApi(SessionStore sessionStore) : super(sessionStore: sessionStore);
}

void main() {
  testWidgets('Hanime 模式下不显示忘记密码并展示网页/Google账号登入', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = _FakeLoginApi(harness.sessionStore);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showLoginSheet(context, api, site: ContentSite.hanime1),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('登录 Hanime'), findsOneWidget);
    expect(find.text('网页 / Google 账号登入'), findsOneWidget);
    expect(find.text('忘记密码'), findsNothing);
    expect(find.text('注册账号'), findsOneWidget);
  });

  testWidgets('Rule34Video 模式下显示忘记密码且不展示网页/Google账号登入', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = _FakeLoginApi(harness.sessionStore);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showLoginSheet(context, api, site: ContentSite.rule34video),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('登录 Rule34Video'), findsOneWidget);
    expect(find.text('忘记密码'), findsOneWidget);
    expect(find.text('网页 / Google 账号登入'), findsNothing);
    expect(find.text('注册账号'), findsOneWidget);
  });
}
