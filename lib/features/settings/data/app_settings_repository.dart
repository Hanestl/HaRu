import 'package:flutter/foundation.dart';

import '../../../core/models/content_source.dart';
import '../../../core/models/translation_models.dart';
import '../../../core/models/video_models.dart';
import '../domain/app_settings.dart';
import 'app_settings_store.dart';

final class AppSettingsRepository extends ChangeNotifier {
  AppSettingsRepository(this._store);

  static const _languageKey = 'flule34.settings.language';
  static const _themeKey = 'flule34.settings.theme';
  static const _playbackQualityKey = 'flule34.settings.playback_quality';
  static const _networkPlaybackPolicyKey =
      'flule34.settings.network_playback_policy';
  static const _autoplayKey = 'flule34.settings.autoplay';
  static const _loopPlaybackKey = 'flule34.settings.loop_playback';
  static const _videoPreviewEnabledKey =
      'flule34.settings.video_preview_enabled';
  static const _rememberPlaybackProgressKey =
      'flule34.settings.remember_playback_progress';
  static const _keepScreenAwakeKey = 'flule34.settings.keep_screen_awake';
  static const _backgroundPlaybackKey = 'flule34.settings.background_playback';
  static const _fullscreenOrientationKey =
      'flule34.settings.fullscreen_orientation';
  static const _defaultOrientationKey =
      'flule34.settings.default_content_orientation';
  static const _blurThumbnailsKey = 'flule34.settings.blur_thumbnails';
  static const _askDownloadQualityKey = 'flule34.settings.ask_download_quality';
  static const _downloadQualityKey = 'flule34.settings.download_quality';
  static const _wifiOnlyDownloadsKey = 'flule34.settings.wifi_only_downloads';
  static const _downloadConcurrentTasksKey =
      'flule34.settings.download_concurrent_tasks';
  static const _saveSearchHistoryKey = 'flule34.settings.save_search_history';
  static const _updateChannelKey = 'flule34.settings.update_channel';
  static const _videoLayoutKey = 'flule34.settings.video_layout';
  static const _legacyHomeVideoLayoutKey = 'flule34.settings.home_video_layout';
  static const _subscriptionLayoutKey = 'flule34.settings.subscription_layout';
  static const _translationEnabledKey = 'flule34.settings.translation_enabled';
  static const _translationDisplayModeKey =
      'flule34.settings.translation_display_mode';
  static const _translationDisplayModesKey =
      'flule34.settings.translation_display_modes';
  static const _automaticTranslationModeKey =
      'flule34.settings.automatic_translation_mode';
  static const _automaticTranslationTargetsKey =
      'flule34.settings.automatic_translation_targets';
  static const _translationTargetKey =
      'flule34.settings.translation_target_language';
  static const _activeSiteKey = 'flule34.settings.active_content_site';
  static const _hasUsedHanimeKey = 'flule34.settings.has_used_hanime';
  static const _navigationOrderKey = 'flule34.settings.navigation_order';
  static const _libraryScopeOrderKey = 'flule34.settings.library_scope_order';

  final AppSettingsStore _store;
  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final values = await Future.wait<Object?>([
      _readString(_themeKey),
      _readString(_playbackQualityKey),
      _readString(_networkPlaybackPolicyKey),
      _readBool(_autoplayKey),
      _readBool(_loopPlaybackKey),
      _readBool(_rememberPlaybackProgressKey),
      _readBool(_keepScreenAwakeKey),
      _readBool(_backgroundPlaybackKey),
      _readString(_fullscreenOrientationKey),
      _readString(_defaultOrientationKey),
      _readBool(_blurThumbnailsKey),
      _readBool(_askDownloadQualityKey),
      _readString(_downloadQualityKey),
      _readBool(_wifiOnlyDownloadsKey),
      _readString(_downloadConcurrentTasksKey),
      _readBool(_saveSearchHistoryKey),
      _readString(_updateChannelKey),
      _readString(_videoLayoutKey),
      _readString(_legacyHomeVideoLayoutKey),
      _readString(_subscriptionLayoutKey),
      _readBool(_videoPreviewEnabledKey),
      _readBool(_translationEnabledKey),
      _readString(_translationDisplayModeKey),
      _readString(_automaticTranslationModeKey),
      _readString(_automaticTranslationTargetsKey),
      _readString(_translationDisplayModesKey),
      _readString(_languageKey),
      _readString(_translationTargetKey),
      _readString(_activeSiteKey),
      _readBool(_hasUsedHanimeKey),
      _readString(_navigationOrderKey),
      _readString(_libraryScopeOrderKey),
    ]);
    final activeSite = ContentSite.fromId(values[28] as String?);
    _settings = AppSettings(
      language: _enumValue(
        AppLanguagePreference.values,
        values[26] as String?,
        AppSettings.defaults.language,
      ),
      theme: _themeValue(values[0] as String?),
      playbackQuality: _qualityValue(
        values[1] as String?,
        AppSettings.defaults.playbackQuality,
      ),
      networkPlaybackPolicy: _enumValue(
        NetworkPlaybackPolicy.values,
        values[2] as String?,
        AppSettings.defaults.networkPlaybackPolicy,
      ),
      autoplay: values[3] as bool? ?? AppSettings.defaults.autoplay,
      loopPlayback: values[4] as bool? ?? AppSettings.defaults.loopPlayback,
      videoPreviewEnabled:
          values[20] as bool? ?? AppSettings.defaults.videoPreviewEnabled,
      rememberPlaybackProgress:
          values[5] as bool? ?? AppSettings.defaults.rememberPlaybackProgress,
      keepScreenAwake:
          values[6] as bool? ?? AppSettings.defaults.keepScreenAwake,
      backgroundPlayback:
          values[7] as bool? ?? AppSettings.defaults.backgroundPlayback,
      fullscreenOrientation: _enumValue(
        FullscreenOrientationPreference.values,
        values[8] as String?,
        AppSettings.defaults.fullscreenOrientation,
      ),
      defaultOrientation: _enumValue(
        ContentOrientation.values,
        values[9] as String?,
        AppSettings.defaults.defaultOrientation,
      ),
      blurThumbnails:
          values[10] as bool? ?? AppSettings.defaults.blurThumbnails,
      askDownloadQuality:
          values[11] as bool? ?? AppSettings.defaults.askDownloadQuality,
      downloadQuality: _qualityValue(
        values[12] as String?,
        AppSettings.defaults.downloadQuality,
      ),
      wifiOnlyDownloads:
          values[13] as bool? ?? AppSettings.defaults.wifiOnlyDownloads,
      downloadConcurrentTasks:
          (int.tryParse(values[14] as String? ?? '') ??
                  AppSettings.defaults.downloadConcurrentTasks)
              .clamp(1, 4),
      saveSearchHistory:
          values[15] as bool? ?? AppSettings.defaults.saveSearchHistory,
      updateChannel: _enumValue(
        UpdateChannel.values,
        values[16] as String?,
        AppSettings.defaults.updateChannel,
      ),
      videoLayout: _enumValue(
        ContentLayout.values,
        (values[17] ?? values[18]) as String?,
        AppSettings.defaults.videoLayout,
      ),
      subscriptionLayout: _enumValue(
        ContentLayout.values,
        values[19] as String?,
        AppSettings.defaults.subscriptionLayout,
      ),
      titleTranslationDisplayMode: _translationDisplayModes(
        values[25] as String?,
        legacyValue: values[22] as String?,
        legacyEnabled: values[21] as bool?,
      ).$1,
      categoryTranslationDisplayMode: _translationDisplayModes(
        values[25] as String?,
        legacyValue: values[22] as String?,
        legacyEnabled: values[21] as bool?,
      ).$2,
      tagTranslationDisplayMode: _translationDisplayModes(
        values[25] as String?,
        legacyValue: values[22] as String?,
        legacyEnabled: values[21] as bool?,
      ).$3,
      translationTarget: _enumValue(
        TranslationTargetPreference.values,
        values[27] as String?,
        AppSettings.defaults.translationTarget,
      ),
      activeSite: activeSite,
      hasUsedHanime: values[29] as bool? ?? activeSite == ContentSite.hanime1,
      automaticTranslationTargets: _automaticTranslationTargets(
        values[24] as String?,
        legacyMode: values[23] as String?,
      ),
      navigationOrder: _enumOrder(
        AppDestination.values,
        values[30] as String?,
        AppSettings.defaults.navigationOrder,
      ),
      libraryScopeOrder: _enumOrder(
        LibraryScopePreference.values,
        values[31] as String?,
        AppSettings.defaults.libraryScopeOrder,
      ),
    );
    final legacyVideoLayout = values[18] as String?;
    if (values[17] == null && legacyVideoLayout != null) {
      await _store.writeString(_videoLayoutKey, legacyVideoLayout);
    }
    if (values[24] == null) {
      await _store.writeString(
        _automaticTranslationTargetsKey,
        _encodeAutomaticTranslationTargets(
          _settings.automaticTranslationTargets,
        ),
      );
    }
    if (values[25] == null) {
      await _store.writeString(
        _translationDisplayModesKey,
        _encodeTranslationDisplayModes(
          title: _settings.titleTranslationDisplayMode,
          category: _settings.categoryTranslationDisplayMode,
          tag: _settings.tagTranslationDisplayMode,
        ),
      );
    }
    if (values[21] == false) {
      await _store.writeString(
        _translationDisplayModeKey,
        TranslationDisplayMode.originalOnly.name,
      );
    }
    await _store.remove(_translationEnabledKey);
    await _store.remove(_automaticTranslationModeKey);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTheme(AppThemePreference value) async {
    await _store.writeString(_themeKey, value.name);
    _update(_settings.copyWith(theme: value));
  }

  Future<void> setLanguage(AppLanguagePreference value) async {
    await _store.writeString(_languageKey, value.name);
    _update(_settings.copyWith(language: value));
  }

  Future<void> setPlaybackQuality(VideoQualityPreference value) async {
    await _store.writeString(_playbackQualityKey, value.name);
    _update(_settings.copyWith(playbackQuality: value));
  }

  Future<void> setNetworkPlaybackPolicy(NetworkPlaybackPolicy value) async {
    await _store.writeString(_networkPlaybackPolicyKey, value.name);
    _update(_settings.copyWith(networkPlaybackPolicy: value));
  }

  Future<void> setAutoplay(bool value) async {
    await _store.writeBool(_autoplayKey, value);
    _update(_settings.copyWith(autoplay: value));
  }

  Future<void> setLoopPlayback(bool value) async {
    await _store.writeBool(_loopPlaybackKey, value);
    _update(_settings.copyWith(loopPlayback: value));
  }

  Future<void> setVideoPreviewEnabled(bool value) async {
    await _store.writeBool(_videoPreviewEnabledKey, value);
    _update(_settings.copyWith(videoPreviewEnabled: value));
  }

  Future<void> setRememberPlaybackProgress(bool value) async {
    await _store.writeBool(_rememberPlaybackProgressKey, value);
    _update(_settings.copyWith(rememberPlaybackProgress: value));
  }

  Future<void> setKeepScreenAwake(bool value) async {
    await _store.writeBool(_keepScreenAwakeKey, value);
    _update(_settings.copyWith(keepScreenAwake: value));
  }

  Future<void> setBackgroundPlayback(bool value) async {
    await _store.writeBool(_backgroundPlaybackKey, value);
    _update(_settings.copyWith(backgroundPlayback: value));
  }

  Future<void> setFullscreenOrientation(
    FullscreenOrientationPreference value,
  ) async {
    await _store.writeString(_fullscreenOrientationKey, value.name);
    _update(_settings.copyWith(fullscreenOrientation: value));
  }

  Future<void> setDefaultOrientation(ContentOrientation value) async {
    await _store.writeString(_defaultOrientationKey, value.name);
    _update(_settings.copyWith(defaultOrientation: value));
  }

  Future<void> setBlurThumbnails(bool value) async {
    await _store.writeBool(_blurThumbnailsKey, value);
    _update(_settings.copyWith(blurThumbnails: value));
  }

  Future<void> setAskDownloadQuality(bool value) async {
    await _store.writeBool(_askDownloadQualityKey, value);
    _update(_settings.copyWith(askDownloadQuality: value));
  }

  Future<void> setDownloadQuality(VideoQualityPreference value) async {
    await _store.writeString(_downloadQualityKey, value.name);
    _update(_settings.copyWith(downloadQuality: value));
  }

  Future<void> setDownloadQualityPreference({
    required bool askEveryTime,
    required VideoQualityPreference quality,
  }) async {
    await _store.writeString(_downloadQualityKey, quality.name);
    await _store.writeBool(_askDownloadQualityKey, askEveryTime);
    _update(
      _settings.copyWith(
        askDownloadQuality: askEveryTime,
        downloadQuality: quality,
      ),
    );
  }

  Future<void> setWifiOnlyDownloads(bool value) async {
    await _store.writeBool(_wifiOnlyDownloadsKey, value);
    _update(_settings.copyWith(wifiOnlyDownloads: value));
  }

  Future<void> setDownloadConcurrentTasks(int value) async {
    final normalized = value.clamp(1, 4);
    await _store.writeString(
      _downloadConcurrentTasksKey,
      normalized.toString(),
    );
    _update(_settings.copyWith(downloadConcurrentTasks: normalized));
  }

  Future<void> setSaveSearchHistory(bool value) async {
    await _store.writeBool(_saveSearchHistoryKey, value);
    _update(_settings.copyWith(saveSearchHistory: value));
  }

  Future<void> setUpdateChannel(UpdateChannel value) async {
    await _store.writeString(_updateChannelKey, value.name);
    _update(_settings.copyWith(updateChannel: value));
  }

  Future<void> setVideoLayout(ContentLayout value) async {
    await _store.writeString(_videoLayoutKey, value.name);
    _update(_settings.copyWith(videoLayout: value));
  }

  Future<void> setSubscriptionLayout(ContentLayout value) async {
    await _store.writeString(_subscriptionLayoutKey, value.name);
    _update(_settings.copyWith(subscriptionLayout: value));
  }

  Future<void> setTranslationDisplayMode(TranslationDisplayMode value) async {
    await _store.writeString(_translationDisplayModeKey, value.name);
    await setTranslationDisplayModes(
      title: value,
      category: value,
      tag: value,
      writeLegacy: false,
    );
  }

  Future<void> setTranslationDisplayModeFor(
    TranslationDisplayTarget target,
    TranslationDisplayMode value,
  ) async {
    final next = switch (target) {
      TranslationDisplayTarget.title => _settings.copyWith(
        titleTranslationDisplayMode: value,
      ),
      TranslationDisplayTarget.category => _settings.copyWith(
        categoryTranslationDisplayMode: value,
      ),
      TranslationDisplayTarget.tag => _settings.copyWith(
        tagTranslationDisplayMode: value,
      ),
    };
    await _store.writeString(
      _translationDisplayModesKey,
      _encodeTranslationDisplayModes(
        title: next.titleTranslationDisplayMode,
        category: next.categoryTranslationDisplayMode,
        tag: next.tagTranslationDisplayMode,
      ),
    );
    _update(next);
  }

  Future<void> setTranslationDisplayModes({
    required TranslationDisplayMode title,
    required TranslationDisplayMode category,
    required TranslationDisplayMode tag,
    bool writeLegacy = true,
  }) async {
    if (writeLegacy) {
      await _store.writeString(_translationDisplayModeKey, title.name);
    }
    await _store.writeString(
      _translationDisplayModesKey,
      _encodeTranslationDisplayModes(
        title: title,
        category: category,
        tag: tag,
      ),
    );
    _update(
      _settings.copyWith(
        titleTranslationDisplayMode: title,
        categoryTranslationDisplayMode: category,
        tagTranslationDisplayMode: tag,
      ),
    );
  }

  Future<void> setAutomaticTranslationTargets(
    Set<AutomaticTranslationTarget> value,
  ) async {
    final normalized = Set<AutomaticTranslationTarget>.unmodifiable(value);
    await _store.writeString(
      _automaticTranslationTargetsKey,
      _encodeAutomaticTranslationTargets(normalized),
    );
    _update(_settings.copyWith(automaticTranslationTargets: normalized));
  }

  Future<void> setTranslationTarget(TranslationTargetPreference value) async {
    await _store.writeString(_translationTargetKey, value.name);
    _update(_settings.copyWith(translationTarget: value));
  }

  Future<void> setActiveSite(ContentSite value) async {
    await _store.writeString(_activeSiteKey, value.id);
    if (value == ContentSite.hanime1 && !_settings.hasUsedHanime) {
      await _store.writeBool(_hasUsedHanimeKey, true);
    }
    _update(
      _settings.copyWith(
        activeSite: value,
        hasUsedHanime: _settings.hasUsedHanime || value == ContentSite.hanime1,
      ),
    );
  }

  Future<void> setNavigationOrder(List<AppDestination> value) async {
    final normalized = _normalizeOrder(AppDestination.values, value);
    await _store.writeString(
      _navigationOrderKey,
      normalized.map((item) => item.name).join(','),
    );
    _update(_settings.copyWith(navigationOrder: normalized));
  }

  Future<void> setLibraryScopeOrder(List<LibraryScopePreference> value) async {
    final normalized = _normalizeOrder(LibraryScopePreference.values, value);
    await _store.writeString(
      _libraryScopeOrderKey,
      normalized.map((item) => item.name).join(','),
    );
    _update(_settings.copyWith(libraryScopeOrder: normalized));
  }

  void _update(AppSettings value) {
    if (identical(value, _settings)) {
      return;
    }
    _settings = value;
    notifyListeners();
  }

  Future<String?> _readString(String key) async {
    try {
      return await _store.readString(key);
    } on TypeError {
      return null;
    }
  }

  Future<bool?> _readBool(String key) async {
    try {
      return await _store.readBool(key);
    } on TypeError {
      return null;
    }
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  static List<T> _enumOrder<T extends Enum>(
    List<T> values,
    String? encoded,
    List<T> fallback,
  ) {
    if (encoded == null || encoded.trim().isEmpty) {
      return List.unmodifiable(fallback);
    }
    final names = encoded.split(',').map((item) => item.trim()).toList();
    final decoded = <T>[];
    for (final name in names) {
      final match = values.where((value) => value.name == name).firstOrNull;
      if (match != null && !decoded.contains(match)) decoded.add(match);
    }
    return List.unmodifiable(_normalizeOrder(values, decoded));
  }

  static List<T> _normalizeOrder<T>(List<T> values, Iterable<T> requested) {
    final result = <T>[];
    for (final item in requested) {
      if (values.contains(item) && !result.contains(item)) result.add(item);
    }
    for (final item in values) {
      if (!result.contains(item)) result.add(item);
    }
    return result;
  }

  VideoQualityPreference _qualityValue(
    String? name,
    VideoQualityPreference fallback,
  ) {
    // 1.2.0 以前的“自动”实际等同于 1080p，保留无感迁移。
    if (name == 'automatic') {
      return VideoQualityPreference.p1080;
    }
    return _enumValue(VideoQualityPreference.values, name, fallback);
  }

  AppThemePreference _themeValue(String? name) {
    if (name == 'amoled') {
      return AppThemePreference.dark;
    }
    return _enumValue(
      AppThemePreference.values,
      name,
      AppSettings.defaults.theme,
    );
  }

  static (
    TranslationDisplayMode,
    TranslationDisplayMode,
    TranslationDisplayMode,
  )
  _translationDisplayModes(
    String? encoded, {
    required String? legacyValue,
    required bool? legacyEnabled,
  }) {
    if (encoded != null && encoded.trim().isNotEmpty) {
      final values = <String, TranslationDisplayMode>{};
      for (final part in encoded.split(',')) {
        final pieces = part.split(':');
        if (pieces.length != 2) continue;
        values[pieces[0].trim()] = _enumValue(
          TranslationDisplayMode.values,
          pieces[1].trim(),
          TranslationDisplayMode.bilingual,
        );
      }
      return (
        values['title'] ?? TranslationDisplayMode.bilingual,
        values['category'] ?? TranslationDisplayMode.bilingual,
        values['tag'] ?? TranslationDisplayMode.bilingual,
      );
    }
    final legacy = legacyEnabled == false
        ? TranslationDisplayMode.originalOnly
        : legacyValue == 'englishOnly'
        ? TranslationDisplayMode.originalOnly
        : _enumValue(
            TranslationDisplayMode.values,
            legacyValue,
            AppSettings.defaults.translationDisplayMode,
          );
    return (legacy, legacy, legacy);
  }

  static Set<AutomaticTranslationTarget> _automaticTranslationTargets(
    String? value, {
    required String? legacyMode,
  }) {
    final names = value
        ?.split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (names != null) {
      return Set.unmodifiable(
        AutomaticTranslationTarget.values.where(
          (target) => names.contains(target.name),
        ),
      );
    }
    return switch (legacyMode) {
      'titlesOnly' => const {AutomaticTranslationTarget.title},
      'allMissing' => const {
        AutomaticTranslationTarget.title,
        AutomaticTranslationTarget.category,
        AutomaticTranslationTarget.tag,
      },
      _ => const {},
    };
  }

  static String _encodeAutomaticTranslationTargets(
    Set<AutomaticTranslationTarget> value,
  ) => value.map((item) => item.name).join(',');

  static String _encodeTranslationDisplayModes({
    required TranslationDisplayMode title,
    required TranslationDisplayMode category,
    required TranslationDisplayMode tag,
  }) => 'title:${title.name},category:${category.name},tag:${tag.name}';
}
