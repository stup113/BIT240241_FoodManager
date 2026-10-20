import '../config.dart';

class DishCategory {
  final int? id;
  final String name;
  final String description;
  final String? remoteId;
  final int syncStatus;
  final int updatedAt;

  const DishCategory({
    this.id,
    required this.name,
    this.description = '',
    this.remoteId,
    this.syncStatus = Sync.dirty,
    this.updatedAt = 0,
  });

  factory DishCategory.fromMap(Map<String, Object?> m) => DishCategory(
        id: m[Col.id] as int?,
        name: (m[Col.name] ?? '') as String,
        description: (m[Col.description] ?? '') as String,
        remoteId: m[Col.remoteId] as String?,
        syncStatus: (m[Col.syncStatus] ?? Sync.dirty) as int,
        updatedAt: (m[Col.updatedAt] ?? 0) as int,
      );

  /// Dữ liệu gửi lên MockAPI.
  Map<String, Object?> toJson() => {
        Col.name: name,
        Col.description: description,
      };
}
