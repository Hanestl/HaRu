# ADR-0019：Drift Schema v14 演进与 Video ID 复合索引优化

- 状态：已接受
- 日期：2026-10-16
- 相关：ADR-0003, ADR-0008, ADR-0010

## 背景

在多站点（Rule34Video / Hanime1）双核心架构下，本地媒体库、播放历史、下载项以及精选媒体库（Curated Library）均依赖视频标识符进行精准检索与状态跟踪。

随着本地数据量增长（特别是用户保存的媒体库视频数量达到数百乃至数千条），本地媒体库关联表 `LocalLibraryVideos`（`local_library_videos`）在没有针对 `videoId` 显式建索引的情况下，按视频 ID 查询所在库或校验视频存在性会退化为全表扫描。此外，`CuratedLibrarySeeder` 在应用启动时进行存在性判定，原先将整表读入 Dart 内存并执行 `where` 匹配，在老用户大数据库场景下带来不必要的 I/O 峰值与内存抖动。

## 决策

1. **Schema 演进升级**：
   - 将 Drift 数据库 Schema 版本从 v13 升至 v14（`app_database.dart` 中的 `schemaVersion`）。
2. **Video ID 索引加速**：
   - 在 `LocalLibraryVideos` 表显式增加索引 `@TableIndex(name: 'idx_local_library_videos_video_id', columns: {#videoId})`，使基于 `videoId` 的查询、存在性判断和批量插入校验达到近乎 O(1) 检索性能。
   - 在 `lib/core/database/app_database.dart` 的迁移步骤 `from13To14`（由 `migrations.stepByStep` 驱动并在 `onUpgrade` 中应用）执行 `migrator.createIndex(schema.idxLocalLibraryVideosVideoId)`。
3. **Seeder 检索下推与内存哈希**：
   - 将 `CuratedLibrarySeeder` 的视频匹配条件从 Dart 内存全表扫描下推至 SQL `where` 子句（`tbl.seedKey`、`tbl.normalizedName` 与前缀匹配）。
   - 将库名存在性判断提升至内存，通过预加载的 `Set<String>` 进行 O(1) 计算，彻底消除逐条查询数据库的开销。
4. **自动化版本迁移保障**：
   - 通过 `drift_dev make-migrations` 生成严格的 `schema_v14.dart` 与 JSON 快照文件。
   - 在 `migration_test.dart` 中建立全链路版本迁移金标准测试，覆盖所有历史版本到 v14 的连续迁移与数据完整性校验。

## 结果

- 单条视频详情进入、本地库归属查询耗时大幅降低，彻底消除长列表数据库锁占与卡顿。
- 应用冷启动时 Seeder 数据库往返次数与内存占用显著降低。
- 迁移测试 100% 自动化覆盖，保障老用户升级至最新架构时平滑过渡且数据零损坏。
