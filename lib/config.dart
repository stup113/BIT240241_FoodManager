// ============================================================================
// CẤU HÌNH TRUNG TÂM - ĐỔI MSSV Ở ĐÂY (DUY NHẤT MỘT CHỖ)
// Mọi tên Table / Field trong SQLite và MockAPI đều được sinh ra từ kMssv,
// nên không thể quên tiền tố {MSSV}_ ở bất kỳ đâu.
// ============================================================================

/// MSSV của bạn. Ví dụ: 'BIT240009'.
const String kMssv = 'BIT240241';

/// Tên project theo mẫu {MSSV}_FoodManager.
const String kProjectName = '${kMssv}_FoodManager';

/// Base URL của MockAPI (https://mockapi.io), ví dụ:
/// 'https://6543abcd1234.mockapi.io/api/v1'
/// Để nguyên 'YOUR_ID' nếu chưa tạo MockAPI -> app chạy thuần local (SQLite).
const String kApiBaseUrl = 'https://6ad74ca295e98f36aef23f3f.mockapi.io';

bool get kApiConfigured => !kApiBaseUrl.contains('240241');

String _p(String name) => '${kMssv}_$name';

/// Tên bảng (SQLite) và cũng là tên resource trên MockAPI.
class Tbl {
  static final String category = _p('DishCategory');
  static final String dish = _p('Dish');
  static final String image = _p('DishImage');
}

/// Tên trường dữ liệu (SQLite column và key JSON trên MockAPI).
class Col {
  static final String id = _p('Id');
  static final String name = _p('Name');
  static final String description = _p('Description');
  static final String price = _p('Price');
  static final String preparationTime = _p('PreparationTime');
  static final String isAvailable = _p('IsAvailable');
  static final String dishCategoryId = _p('DishCategoryId');
  static final String dishImage = _p('DishImage'); // danh sách ảnh (JSON)
  static final String imageUrl = _p('ImageUrl');
  static final String isThumbnail = _p('IsThumbnail');
  static final String dishId = _p('DishId');

  // Cột phục vụ đồng bộ (chỉ lưu local, không gửi lên MockAPI).
  static final String remoteId = _p('RemoteId');
  static final String syncStatus = _p('SyncStatus');
  static final String updatedAt = _p('UpdatedAt');
}

/// Trạng thái đồng bộ của một bản ghi local.
class Sync {
  static const int synced = 0; // đã khớp với MockAPI
  static const int dirty = 1; // chờ đẩy lên (tạo mới hoặc sửa)
  static const int deleted = 2; // đã xóa local, chờ xóa trên MockAPI
}
