enum SortOption { none, priceAsc, priceDesc, timeAsc }

const Object _unset = Object();

/// Điều kiện tìm kiếm / lọc / sắp xếp. Được giữ trong AppState nên không bị
/// mất khi chuyển màn hình rồi quay lại danh sách.
class DishFilter {
  final String query;
  final int? categoryId;
  final bool onlyAvailable;
  final double? minPrice;
  final double? maxPrice;
  final SortOption sort;

  const DishFilter({
    this.query = '',
    this.categoryId,
    this.onlyAvailable = false,
    this.minPrice,
    this.maxPrice,
    this.sort = SortOption.none,
  });

  bool get isActive =>
      query.trim().isNotEmpty ||
      categoryId != null ||
      onlyAvailable ||
      minPrice != null ||
      maxPrice != null ||
      sort != SortOption.none;

  bool get hasPriceRange => minPrice != null || maxPrice != null;

  /// Với categoryId / minPrice / maxPrice: truyền null để xóa điều kiện,
  /// không truyền để giữ nguyên.
  DishFilter copyWith({
    String? query,
    Object? categoryId = _unset,
    bool? onlyAvailable,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    SortOption? sort,
  }) {
    return DishFilter(
      query: query ?? this.query,
      categoryId:
          identical(categoryId, _unset) ? this.categoryId : categoryId as int?,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
      minPrice:
          identical(minPrice, _unset) ? this.minPrice : minPrice as double?,
      maxPrice:
          identical(maxPrice, _unset) ? this.maxPrice : maxPrice as double?,
      sort: sort ?? this.sort,
    );
  }
}
