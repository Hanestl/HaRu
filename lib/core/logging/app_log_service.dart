import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../security/error_redaction.dart';

String logExportFileName(DateTime now) =>
    'HaRu-logs-${now.year.toString().padLeft(4, '0')}'
    '${now.month.toString().padLeft(2, '0')}'
    '${now.day.toString().padLeft(2, '0')}'
    '${now.hour.toString().padLeft(2, '0')}'
    '${now.minute.toString().padLeft(2, '0')}.txt';

final class AppLogService {
  AppLogService._(
    this._noop, {
    Future<Directory> Function()? supportDirectory,
    DateTime Function()? clock,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  static final AppLogService instance = AppLogService._(
    // 测试环境（flutter test）下全局单例直接跳过磁盘写入：真实文件 IO
    // 在 testWidgets 的 FakeAsync 时钟下永远不会完成，会挂起所有经过日志
    // 点的网络调用。日志功能本身的测试走 [AppLogService.forTesting]。
    Platform.environment.containsKey('FLUTTER_TEST'),
  );

  AppLogService.forTesting({
    required Future<Directory> Function() supportDirectory,
    DateTime Function()? clock,
  }) : this._(false, supportDirectory: supportDirectory, clock: clock);

  static const _directoryName = 'flule34_logs';
  static const _exportDirectoryName = 'flule34_log_exports';
  static const _filePrefix = 'flule34-';
  static const _fileSuffix = '.log';
  static const _retentionDays = 7;
  static const _maxFileBytes = 8 * 1024 * 1024;
  static const _maxTotalBytes = 48 * 1024 * 1024;

  Future<Directory>? _directoryFuture;
  Future<void> _writeChain = Future<void>.value();
  var _cleared = false;
  String? _lastPurgeDateKey;
  int? _approximateTotalBytes;
  // 同一天的连续写入复用同一个目标文件与其已知大小，避免每条日志都做
  // create/exists/length 三次系统调用。所有写入都串在 [_writeChain] 上，
  // 因此这份缓存不需要加锁。
  String? _currentFileDateKey;
  File? _currentFile;
  int _currentFileBytes = 0;
  final Future<Directory> Function() _supportDirectory;
  final DateTime Function() _clock;
  // 测试环境（flutter test）下全局单例直接跳过磁盘写入：真实文件 IO
  // 在 testWidgets 的 FakeAsync 时钟下永远不会完成，会挂起所有经过日志
  // 点的网络调用。日志功能本身的测试走 [AppLogService.forTesting]（noop=false）。
  final bool _noop;

  Future<Directory> _directory() {
    return _directoryFuture ??= _supportDirectory().then((root) {
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}$_directoryName',
      );
      return directory;
    });
  }

  Future<void> initialize() async {
    try {
      final directory = await _directory();
      await directory.create(recursive: true);
      await _purge(directory);
      _lastPurgeDateKey = _dateKey(_clock());
      await _clearExportFiles();
    } on Object {
      // 日志不能阻止应用启动。
    }
  }

  Future<void> info(String message, {String component = 'app'}) =>
      _append('INFO', message, component: component);

  Future<void> warning(String message, {String component = 'app'}) =>
      _append('WARN', message, component: component);

  Future<void> error(
    Object error,
    StackTrace stackTrace, {
    String component = 'app',
  }) {
    final safeError = redactSensitiveText(error, maxLength: 4000);
    final safeStack = redactSensitiveText(stackTrace, maxLength: 12000);
    return _append(
      'ERROR',
      '$safeError\n$safeStack',
      component: component,
      maxMessageLength: 16000,
    );
  }

  Future<void> _append(
    String level,
    String message, {
    required String component,
    int maxMessageLength = 2000,
  }) {
    if (_noop) {
      return Future<void>.value();
    }
    final operation = _writeChain = _writeChain.then((_) async {
      try {
        if (_cleared) {
          _cleared = false;
          _lastPurgeDateKey = null;
          _approximateTotalBytes = null;
          _resetCurrentFile();
        }
        final directory = await _directory();
        final now = _clock();
        final currentDateKey = _dateKey(now);
        if (_approximateTotalBytes == null ||
            _lastPurgeDateKey != currentDateKey) {
          await _purge(directory);
          _lastPurgeDateKey = currentDateKey;
        }
        final targetFile = await _resolveTargetFile(directory, currentDateKey);
        final safeMessage = redactSensitiveText(
          message,
          maxLength: maxMessageLength,
        ).replaceAll('\r', '');
        final line =
            '${now.toIso8601String()} [$level] [$component] '
            '${safeMessage.replaceAll('\n', '\\n')}\n';
        final lineBytes = utf8.encode(line).length;
        await targetFile.writeAsString(
          line,
          mode: FileMode.append,
          encoding: utf8,
        );
        _currentFileBytes += lineBytes;
        _approximateTotalBytes = (_approximateTotalBytes ?? 0) + lineBytes;
        if (_approximateTotalBytes! > _maxTotalBytes) {
          await _purge(directory);
        }
      } on Object {
        // 记录失败不能影响业务流程。
      }
    });
    return operation;
  }

  /// 解析当天要写入的日志文件，并在同一天的连续写入之间复用结果。
  Future<File> _resolveTargetFile(Directory directory, String dateKey) async {
    final cached = _currentFile;
    if (cached != null &&
        _currentFileDateKey == dateKey &&
        _currentFileBytes < _maxFileBytes) {
      return cached;
    }
    await directory.create(recursive: true);
    final separator = Platform.pathSeparator;
    var targetFile = File(
      '${directory.path}$separator$_filePrefix$dateKey$_fileSuffix',
    );
    var size = await targetFile.exists() ? await targetFile.length() : 0;
    if (size >= _maxFileBytes) {
      var index = 1;
      while (true) {
        final nextFile = File(
          '${directory.path}$separator$_filePrefix$dateKey.$index$_fileSuffix',
        );
        final nextSize = await nextFile.exists() ? await nextFile.length() : 0;
        if (nextSize < _maxFileBytes) {
          targetFile = nextFile;
          size = nextSize;
          break;
        }
        index++;
      }
    }
    _currentFileDateKey = dateKey;
    _currentFile = targetFile;
    _currentFileBytes = size;
    return targetFile;
  }

  void _resetCurrentFile() {
    _currentFileDateKey = null;
    _currentFile = null;
    _currentFileBytes = 0;
  }

  Future<List<File>> _logFiles() async {
    final directory = await _directory();
    if (!await directory.exists()) {
      return const <File>[];
    }
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          entity.path.endsWith(_fileSuffix) &&
          entity.path.contains(_filePrefix)) {
        files.add(entity);
      }
    }
    files.sort((left, right) {
      final leftKey = _fileSortKey(left.path);
      final rightKey = _fileSortKey(right.path);
      if (leftKey != null && rightKey != null) {
        final dateComp = leftKey.$1.compareTo(rightKey.$1);
        if (dateComp != 0) return dateComp;
        return leftKey.$2.compareTo(rightKey.$2);
      }
      return left.path.compareTo(right.path);
    });
    return files;
  }

  Future<void> _purge(Directory directory) async {
    final files = await _logFiles();
    final cutoff = _clock().subtract(const Duration(days: _retentionDays - 1));
    for (final file in files) {
      final key = _dateFromFile(file.path);
      if (key == null ||
          key.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) {
        try {
          await file.delete();
        } on Object {
          // 单个旧日志删除失败不影响其他文件清理。
        }
      }
    }
    final remaining = await _logFiles();
    var totalBytes = 0;
    for (final file in remaining.reversed) {
      final length = await file.length();
      if (totalBytes + length > _maxTotalBytes) {
        try {
          await file.delete();
        } on Object {
          // 单个日志删除失败不影响后续清理。
        }
      } else {
        totalBytes += length;
      }
    }
    _approximateTotalBytes = totalBytes;
    _resetCurrentFile();
  }

  Future<LogStorageInfo> storageInfo() async {
    try {
      final files = await _logFiles();
      var bytes = 0;
      for (final file in files) {
        bytes += await file.length();
      }
      return LogStorageInfo(fileCount: files.length, bytes: bytes);
    } on Object {
      return const LogStorageInfo(fileCount: 0, bytes: 0);
    }
  }

  Future<String> readAll() async {
    await _writeChain;
    final files = await _logFiles();
    final buffer = StringBuffer();
    for (final file in files) {
      buffer.writeln('===== ${file.uri.pathSegments.last} =====');
      final stored = await file.readAsString(encoding: utf8);
      final restored = stored.replaceAll(r'\n', '\n');
      buffer.write(restored);
      if (!restored.endsWith('\n')) {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  Future<File> createExportFile(String content, {String? fileName}) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$_exportDirectoryName',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    final now = _clock();
    final resolvedName = fileName ?? logExportFileName(now);
    final file = File(
      '${directory.path}${Platform.pathSeparator}$resolvedName',
    );
    await file.writeAsString(content, encoding: utf8, flush: true);
    return file;
  }

  Future<void> clear() async {
    await _writeChain;
    final directory = await _directory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await _clearExportFiles();
    _cleared = true;
    _approximateTotalBytes = 0;
    _resetCurrentFile();
  }

  Future<void> _clearExportFiles() async {
    try {
      final root = await getTemporaryDirectory();
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}$_exportDirectoryName',
      );
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on Object {
      // 临时导出文件清理失败不能影响日志记录和应用启动。
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  (DateTime, int)? _fileSortKey(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final match = RegExp(
      '^${RegExp.escape(_filePrefix)}(\\d{4})-(\\d{2})-(\\d{2})(?:\\.(\\d+))?${RegExp.escape(_fileSuffix)}\$',
    ).firstMatch(name);
    if (match == null) {
      return null;
    }
    final date = DateTime.tryParse(
      '${match.group(1)}-${match.group(2)}-${match.group(3)}',
    );
    if (date == null) {
      return null;
    }
    final index = int.tryParse(match.group(4) ?? '0') ?? 0;
    return (date, index);
  }

  DateTime? _dateFromFile(String path) => _fileSortKey(path)?.$1;
}

final class LogStorageInfo {
  const LogStorageInfo({required this.fileCount, required this.bytes});

  final int fileCount;
  final int bytes;

  String get formattedSize {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
