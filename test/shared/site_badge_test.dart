import 'package:flule34/core/models/content_source.dart';
import 'package:flule34/shared/site_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiteBadge', () {
    testWidgets('渲染站点首字母', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              SiteBadge(site: ContentSite.rule34video),
              SiteBadge(site: ContentSite.hanime1),
            ],
          ),
        ),
      );

      expect(find.text('R'), findsOneWidget);
      expect(find.text('H'), findsOneWidget);
    });

    testWidgets('选中态与非选中态视觉样式区分', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                SiteBadge(site: ContentSite.rule34video, isSelected: true),
                SiteBadge(site: ContentSite.hanime1, isSelected: false),
              ],
            ),
          ),
        ),
      );

      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .toList();
      expect(containers.length, greaterThanOrEqualTo(2));

      final selectedBox = containers[0].decoration as BoxDecoration?;
      final unselectedBox = containers[1].decoration as BoxDecoration?;

      expect(selectedBox?.color, Colors.red.shade600);
      expect(selectedBox?.border, isNull);

      expect(unselectedBox?.color, isNull);
      expect(unselectedBox?.border, isNotNull);
    });
  });
}
