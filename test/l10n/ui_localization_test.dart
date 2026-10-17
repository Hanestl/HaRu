import 'package:flule34/l10n/ui_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('四种界面语言使用各自文案', () {
    expect(localizeUiText(const Locale('zh'), '媒体库'), '媒体库');
    expect(localizeUiText(const Locale('en'), '媒体库'), 'Library');
    expect(localizeUiText(const Locale('ja'), '媒体库'), 'ライブラリ');
    expect(localizeUiText(const Locale('ko'), '媒体库'), '라이브러리');
  });

  test('不支持的系统语言回退到简体中文', () {
    expect(localizeUiText(const Locale('fr'), '翻译设置'), '翻译设置');
  });

  test('动态文案模板保留插值内容', () {
    expect(localizeUiText(const Locale('en'), '已选择 12 项'), contains('12'));
    expect(localizeUiText(const Locale('ja'), '已选择 12 项'), contains('12'));
    expect(localizeUiText(const Locale('ko'), '已选择 12 项'), contains('12'));
  });

  test('关键页面文案均有英日韩译文', () {
    const sources = [
      '内容取向',
      '时长',
      '发布时间',
      '排序',
      '必须同时包含',
      '尚未选择标签',
      '按标签和内容主题探索',
      '本地分类库',
      '视频保存路径：Download/Flule34',
      '当前开发构建未配置更新源',
      '此构建未配置 GitHub Releases 更新源。',
      '艺术家',
      '分类',
      '标签',
    ];
    for (final source in sources) {
      expect(localizeUiText(const Locale('en'), source), isNot(source));
      expect(localizeUiText(const Locale('ja'), source), isNot(source));
      expect(localizeUiText(const Locale('ko'), source), isNot(source));
    }
  });

  test('翻译库完整统计模板不会遗留中文片段', () {
    const source = '共 10101 条 · 内置 9990 · API 100 · 用户 11';
    expect(
      localizeUiText(const Locale('en'), source),
      'Total 10101 items · Built-in 9990 · API 100 · User 11',
    );
    expect(localizeUiText(const Locale('ja'), source), isNot(contains('共')));
    expect(localizeUiText(const Locale('ko'), source), isNot(contains('用户')));
  });

  test('动态异常消息在三语下不再残留中文原文', () {
    // 这些消息的插值里嵌套了字符串字面量，曾因字面量正则被内层引号截断而
    // 永远进不了词表，英文界面下呈中英混排。
    const samples = <String>[
      'Hanime 登录请求失败：未知错误',
      'Hanime 网络请求失败：未知错误',
      '无法识别这个订阅，请从相关视频详情页订阅。',
      '无法识别这个订阅，请从相关视频详情页取消。',
    ];
    const markers = <String>['登录请求失败', '网络请求失败', '无法识别这个订阅', '未知错误'];
    final han = RegExp(r'[\u3400-\u9fff]');
    for (final language in const ['en', 'ko']) {
      final locale = Locale(language);
      for (final sample in samples) {
        final rendered = localizeUiText(locale, sample);
        expect(
          han.hasMatch(rendered),
          isFalse,
          reason: '$language: 「$sample」-> 「$rendered」',
        );
      }
    }
    for (final language in const ['en', 'ja', 'ko']) {
      final locale = Locale(language);
      for (final sample in samples) {
        final rendered = localizeUiText(locale, sample);
        for (final marker in markers) {
          expect(
            rendered.contains(marker),
            isFalse,
            reason: '$language: 「$sample」-> 「$rendered」仍含「$marker」',
          );
        }
      }
    }
  });
}
