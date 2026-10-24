import 'package:flule34/shared/scroll_to_top_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('滚动超过一屏后显示按钮并可平滑回到顶部', (tester) async {
    final scrollController = ScrollController();
    final overlayController = ScrollToTopController();
    addTearDown(scrollController.dispose);
    addTearDown(overlayController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOverlay(
          controller: overlayController,
          child: Scaffold(
            body: ListView.builder(
              controller: scrollController,
              itemExtent: 80,
              itemCount: 40,
              itemBuilder: (context, index) => Text('项目 $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    scrollController.jumpTo(800);
    await tester.pump();

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0);
  });

  testWidgets('全屏抑制状态会隐藏回到顶部按钮', (tester) async {
    final scrollController = ScrollController();
    final overlayController = ScrollToTopController();
    addTearDown(scrollController.dispose);
    addTearDown(overlayController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOverlay(
          controller: overlayController,
          child: Scaffold(
            body: ListView.builder(
              controller: scrollController,
              itemExtent: 80,
              itemCount: 40,
              itemBuilder: (context, index) => Text('项目 $index'),
            ),
          ),
        ),
      ),
    );
    scrollController.jumpTo(800);
    await tester.pump();
    overlayController.setSuppressed(true);
    await tester.pump();

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
  });

  testWidgets('输入框获得焦点时隐藏并阻止回到顶部按钮', (tester) async {
    final scrollController = ScrollController();
    final overlayController = ScrollToTopController();
    final textController = TextEditingController();
    addTearDown(scrollController.dispose);
    addTearDown(overlayController.dispose);
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOverlay(
          controller: overlayController,
          child: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemExtent: 80,
                    itemCount: 40,
                    itemBuilder: (context, index) => Text('项目 $index'),
                  ),
                ),
                TextField(controller: textController),
              ],
            ),
          ),
        ),
      ),
    );
    scrollController.jumpTo(800);
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
  });

  testWidgets('焦点输入框被移除后按钮恢复可用且不抛异常', (tester) async {
    final scrollController = ScrollController();
    final overlayController = ScrollToTopController();
    final textController = TextEditingController();
    addTearDown(scrollController.dispose);
    addTearDown(overlayController.dispose);
    addTearDown(textController.dispose);

    var showField = true;
    late StateSetter setPageState;

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOverlay(
          controller: overlayController,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setPageState = setState;
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemExtent: 80,
                        itemCount: 40,
                        itemBuilder: (context, index) => Text('项目 $index'),
                      ),
                    ),
                    if (showField) TextField(controller: textController),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    scrollController.jumpTo(800);
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    // 焦点控件被移除后，覆盖层不应再对已失活的 Element 查询祖先
    // （"Looking up a deactivated widget's ancestor is unsafe"），
    // 并且按钮要重新可用。
    setPageState(() => showField = false);
    await tester.pump();
    // 焦点管理器在帧末才重新分配主焦点，再推一帧让它把通知发出来。
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();
    expect(scrollController.offset, 0);
  });
}
