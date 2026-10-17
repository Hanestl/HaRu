import 'package:flule34/core/api/parse_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

// 顶层可变变量：闭包引用它不会形成不可发送的捕获，因此即使闭包被送进后台
// Isolate，也不会因为捕获测试局部变量而失败；后台 Isolate 的写入不会回传主 Isolate。
int _syncRuns = 0;

void main() {
  test('小于阈值的小页面同步解析，不引入 Isolate 往返开销', () async {
    _syncRuns = 0;
    final future = parseHtmlOffThread('small-body', () {
      _syncRuns += 1;
      return 1;
    });

    expect(_syncRuns, 1, reason: '小页面应在主 Isolate 同步解析');
    expect(await future, 1);
  });

  test('达到阈值的大页面下放到后台 Isolate 解析', () async {
    _syncRuns = 0;
    final body = 'x' * htmlIsolateThreshold;

    final length = await parseHtmlOffThread(body, () {
      _syncRuns += 1;
      return body.length;
    });

    expect(length, htmlIsolateThreshold);
    expect(_syncRuns, 0, reason: '达到阈值时应由后台 Isolate 解析，主 Isolate 不执行');
  });

  test('后台 Isolate 中的解析异常按原类型与原文回传', () async {
    await expectLater(
      parseHtmlOffThread(
        'y' * htmlIsolateThreshold,
        () => throw const FormatException('解析失败'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '解析失败',
        ),
      ),
    );
  });
}
