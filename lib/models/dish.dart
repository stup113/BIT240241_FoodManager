import '../config.dart';

class DishImage {
  final int? id;
  final int? dishId;
  final String imageUrl;
  final bool isThumbnail;

  const DishImage({
    this.id,
    this.dishId,
    required this.imageUrl,
    this.isThumbnail = false,
  });

  DishImage copyWith({bool? isThumbnail}) => DishImage(
        id: id,
        dishId: dishId,
        imageUrl: imageUrl,
        isThumbnail: isThumbnail ?? this.isThumbnail,
      );

  factory DishImage.fromMap(Map<String, Object?> m) => DishImage(
        id: m[Col.id] as int?,
        dishId: m[Col.dishId] as int?,
        imageUrl: m[Col.imageUrl] as String,
        isThumbnail: (m[Col.isThumbnail] ?? 0) == 1,
      );

  Map<String, Object?> toJson() => {
        Col.imageUrl: imageUrl,
        Col.isThumbnail: isThumbnail,
      };
}

class Dish {
  final int? id;
  final String name;
  final double price;
  final int preparationTime; // phút
  final bool isAvailable;
  final String description;
  final int dishCategoryId;
  final List<DishImage> images;
  final String? remoteId;
  final int syncStatus;
  final int updatedAt;

  const Dish({
    this.id,
    required this.name,
    required this.price,
    required this.preparationTime,
    this.isAvailable = true,
    this.description = '',
    required this.dishCategoryId,
    this.images = const [],
    this.remoteId,
    this.syncStatus = Sync.dirty,
    this.updatedAt = 0,
  });

  /// "Quick" khi PreparationTime <= 15 phút. Tính khi hiển thị, KHÔNG lưu DB.
  bool get isQuick => preparationTime <= 15;

  /// Ảnh đại diện; nếu chưa đặt thì lấy ảnh đầu tiên; không có ảnh -> null.
  DishImage? get thumbnail {
    for (final i in images) {
      if (i.isThumbnail) return i;
    }
    return images.isEmpty ? null : images.first;
  }

  factory Dish.fromMap(Map<String, Object?> m, List<DishImage> images) => Dish(
        id: m[Col.id] as int?,
        name: (m[Col.name] ?? '') as String,
        price: ((m[Col.price] ?? 0) as num).toDouble(),
        preparationTime: ((m[Col.preparationTime] ?? 0) as num).toInt(),
        isAvailable: (m[Col.isAvailable] ?? 1) == 1,
        description: (m[Col.description] ?? '') as String,
        dishCategoryId: m[Col.dishCategoryId] as int,
        images: images,
        remoteId: m[Col.remoteId] as String?,
        syncStatus: (m[Col.syncStatus] ?? Sync.dirty) as int,
        updatedAt: (m[Col.updatedAt] ?? 0) as int,
      );

  /// Dữ liệu gửi lên MockAPI. DishCategoryId là id của loại trên server.
  Map<String, Object?> toJson(String categoryRemoteId) => {
        Col.name: name,
        Col.price: price,
        Col.preparationTime: preparationTime,
        Col.isAvailable: isAvailable,
        Col.description: description,
        Col.dishCategoryId: categoryRemoteId,
        Col.dishImage: images.map((i) => i.toJson()).toList(),
      };
}
