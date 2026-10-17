import 'dart:io';

import 'package:flule34/core/logging/app_log_service.dart';
import 'package:flule34/core/security/error_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hanime 用户路径和用户字段会被脱敏', () {
    final result = redactSensitiveText(
      'GET /user/123456/playlists；用户=PrivateName；userId=123456',
    );
    expect(result, isNot(contains('123456')));
    expect(result, isNot(contains('PrivateName')));
    expect(result, contains('/user/<redacted>/playlists'));
  });

  test('日志导出文件名精确到分钟', () {
    expect(
      logExportFileName(DateTime(2026, 8, 10, 20, 6, 59)),
      'HaRu-logs-202608102006.txt',
    );
  });

  test('日志自动脱敏、按七天保留并支持清除', () async {
    final root = await Directory.systemTemp.createTemp('flule34-app-log-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final now = DateTime(2026, 8, 7, 12);
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}flule34_logs',
    )..createSync(recursive: true);
    await File(
      '${directory.path}${Platform.pathSeparator}flule34-2026-07-31.log',
    ).writeAsString('old');
    final service = AppLogService.forTesting(
      supportDirectory: () async => root,
      clock: () => now,
    );

    await service.initialize();
    await service.error(
      StateError('password=secret-value'),
      StackTrace.current,
      component: 'test',
    );

    final text = await service.readAll();
    expect(text, contains('[ERROR] [test]'));
    expect(text, isNot(contains('secret-value')));
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}flule34-2026-07-31.log',
      ).exists(),
      isFalse,
    );
    expect((await service.storageInfo()).fileCount, 1);

    await service.clear();
    expect((await service.storageInfo()).fileCount, 0);
  });

  test('错误日志会保留足够长的调用栈用于符号化', () async {
    final root = await Directory.systemTemp.createTemp('flule34-stack-log-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final service = AppLogService.forTesting(
      supportDirectory: () async => root,
      clock: () => DateTime(2026, 8, 8, 12),
    );
    await service.initialize();
    final stack = StackTrace.fromString(
      '${List.generate(180, (index) => '#$index frame-$index').join('\n')}\n'
      'tail-symbolization-marker',
    );
    await service.error(
      StateError('player failure'),
      stack,
      component: 'video',
    );

    final text = await service.readAll();
    expect(text, contains('tail-symbolization-marker'));
    expect(text, contains('\n#1 frame-1'));
    expect(text, isNot(contains(r'\n#1 frame-1')));
    expect(text.length, greaterThan(2000));
  });

  test('单日持续写入若突破 48MiB 硬上限会触发旧文件淘汰', () async {
    final root = await Directory.systemTemp.createTemp('flule34-cap-log-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final logDir = Directory(
      '${root.path}${Platform.pathSeparator}flule34_logs',
    )..createSync(recursive: true);

    // 构造 5 天历史日志（各 8MB = 40MB）与今天已有日志（接近 8MB），且均在 7 天保留期内
    final dates = [
      '2026-08-02',
      '2026-08-03',
      '2026-08-04',
      '2026-08-05',
      '2026-08-06',
    ];
    for (final date in dates) {
      final file = File(
        '${logDir.path}${Platform.pathSeparator}flule34-$date.log',
      );
      final raf = await file.open(mode: FileMode.write);
      await raf.truncate(8 * 1024 * 1024);
      await raf.close();
    }
    // 今天已有日志：8MB - 50 字节，此时总大小为 48MB - 50 字节
    final todayFile = File(
      '${logDir.path}${Platform.pathSeparator}flule34-2026-08-07.log',
    );
    final todayRaf = await todayFile.open(mode: FileMode.write);
    await todayRaf.truncate(8 * 1024 * 1024 - 50);
    await todayRaf.close();

    final today = DateTime(2026, 8, 7, 12);
    final service = AppLogService.forTesting(
      supportDirectory: () async => root,
      clock: () => today,
    );

    final initialInfo = await service.storageInfo();
    expect(initialInfo.fileCount, 6);
    expect(initialInfo.bytes, 48 * 1024 * 1024 - 50);

    // 追加一条今天的日志（> 50 字节），突破 48MB
    await service.info(
      'continuous single-day write overflow trigger message',
      component: 'test',
    );

    final updatedInfo = await service.storageInfo();
    // 最老的文件 2026-08-02 应该被淘汰
    expect(
      await File(
        '${logDir.path}${Platform.pathSeparator}flule34-2026-08-02.log',
      ).exists(),
      isFalse,
    );
    // 今天的日志依然保留
    expect(await todayFile.exists(), isTrue);
    // 并且总大小重新受控在 48MiB 硬上限之内
    expect(updatedInfo.bytes, lessThanOrEqualTo(48 * 1024 * 1024));
  });

  test('单日日志文件满 8MiB 后自动轮转为 .1 文件，且内容完整写入', () async {
    final root = await Directory.systemTemp.createTemp('flule34-rotate-log-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final logDir = Directory(
      '${root.path}${Platform.pathSeparator}flule34_logs',
    )..createSync(recursive: true);

    // 构造当天主日志文件满 8MB
    final todayFile = File(
      '${logDir.path}${Platform.pathSeparator}flule34-2026-08-07.log',
    );
    final raf = await todayFile.open(mode: FileMode.write);
    await raf.truncate(8 * 1024 * 1024);
    await raf.close();

    final today = DateTime(2026, 8, 7, 14);
    final service = AppLogService.forTesting(
      supportDirectory: () async => root,
      clock: () => today,
    );

    // 写入新日志
    await service.info('hello after 8mb limit', component: 'rotate_test');

    final rotatedFile = File(
      '${logDir.path}${Platform.pathSeparator}flule34-2026-08-07.1.log',
    );
    expect(await rotatedFile.exists(), isTrue);
    final content = await rotatedFile.readAsString();
    expect(content, contains('hello after 8mb limit'));
  });

  test('R3-7: 多轮转日志按数值排序 (.log -> .2 -> .10)，且 readAll 与超量回收顺序正确', () async {
    final root = await Directory.systemTemp.createTemp('flule34-order-log-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final logDir = Directory(
      '${root.path}${Platform.pathSeparator}flule34_logs',
    )..createSync(recursive: true);

    final f0 = File(
      '${logDir.path}${Platform.pathSeparator}flule34-2026-08-07.log',
    );
    final f2 = File(
      '${logDir.path}${Platform.pathSeparator}flule34-2026-08-07.2.log',
    );
    final f10 = File(
      '${logDir.path}${Platform.pathSeparator}flule34-2026-08-07.10.log',
    );

    await f0.writeAsString('CHUNK_0\n');
    await f2.writeAsString('CHUNK_2\n');
    await f10.writeAsString('CHUNK_10\n');

    final service = AppLogService.forTesting(
      supportDirectory: () async => root,
      clock: () => DateTime(2026, 8, 7, 15),
    );

    final readText = await service.readAll();
    final idx0 = readText.indexOf('CHUNK_0');
    final idx2 = readText.indexOf('CHUNK_2');
    final idx10 = readText.indexOf('CHUNK_10');

    expect(idx0, isNot(-1));
    expect(idx2, isNot(-1));
    expect(idx10, isNot(-1));
    expect(idx0, lessThan(idx2));
    expect(idx2, lessThan(idx10));

    // 验证超量淘汰顺序：创建旧轮转文件 f1 并扩充至 25MB，f2 扩充至 25MB（合计 > 48MB）
    final f1 = File(
      '${logDir.path}${Platform.pathSeparator}flule34-2026-08-07.1.log',
    );
    final raf1 = await f1.open(mode: FileMode.write);
    await raf1.truncate(25 * 1024 * 1024);
    await raf1.close();

    final raf2 = await f2.open(mode: FileMode.write);
    await raf2.truncate(25 * 1024 * 1024);
    await raf2.close();

    await service.info('TRIGGER_PURGE', component: 'purge_test');

    // 较旧的轮转文件 f1 (.1.log) 应被超量淘汰删除，而较新的 f2 (.2.log) 与 f10 (.10.log) 应被保留
    expect(await f1.exists(), isFalse);
    expect(await f2.exists(), isTrue);
    expect(await f10.exists(), isTrue);
  });
}
