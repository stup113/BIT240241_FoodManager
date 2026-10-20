# BIT240000_FoodManager (Flutter)

Bài kiểm tra giữa kỳ - Phát triển ứng dụng di động - Đề tài Quản lý món ăn.
Công nghệ: **Flutter** · Lưu trữ: **SQLite (sqflite) + MockAPI** (offline-first, tự đồng bộ).

## 1. Cài đặt (làm theo thứ tự)

1. **Đổi MSSV**: mở `lib/config.dart`, sửa `kMssv = 'BIT240000'` thành MSSV của bạn.
   Toàn bộ tên project/table/field đều sinh từ hằng số này nên không thể sót tiền tố.
2. **Đổi tên thư mục** project thành `{MSSV}_FoodManager` (ví dụ `BIT240009_FoodManager`).
   Nếu cần, đổi cả `name:` trong `pubspec.yaml` (chữ thường, ví dụ `bit240009_foodmanager`).
3. Sinh thư mục nền tảng (Android/iOS) rồi cài thư viện:
   ```bash
   cd BIT240009_FoodManager
   flutter create --platforms=android,ios .
   flutter pub get
   ```
   Nếu có file `test/widget_test.dart` do `flutter create` sinh ra, hãy xóa nó (nó tham chiếu `MyApp`).
4. **Android - quyền mạng**: trong `android/app/src/main/AndroidManifest.xml`, ngay trên thẻ `<application>` thêm:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
   ```
5. Chạy: `flutter run` (máy thật hoặc emulator Android/iOS). **Không chạy trên Web** vì sqflite không hỗ trợ.

## 2. Cấu hình MockAPI (cho phần nâng cao 1,5đ)

1. Vào https://mockapi.io, tạo project, tạo **2 resource** có tên đúng như sau (thay `BIT240000` bằng MSSV):
   - `BIT240000_DishCategory` với field: `BIT240000_Name` (string), `BIT240000_Description` (string)
   - `BIT240000_Dish` với field: `BIT240000_Name` (string), `BIT240000_Price` (number),
     `BIT240000_PreparationTime` (number), `BIT240000_IsAvailable` (boolean),
     `BIT240000_Description` (string), `BIT240000_DishCategoryId` (string),
     `BIT240000_DishImage` (object/array - danh sách `{BIT240000_ImageUrl, BIT240000_IsThumbnail}`)
2. Copy base URL (dạng `https://xxxx.mockapi.io/api/v1`) dán vào `kApiBaseUrl` trong `lib/config.dart`.
3. Nếu để nguyên `YOUR_ID`, app vẫn chạy bình thường nhưng chỉ lưu local (có banner báo).

> Cột `id` của MockAPI do nền tảng tự sinh nên không có tiền tố; đây là id của server, app lưu ở cột local `{MSSV}_RemoteId`.
> Dữ liệu mẫu (3 loại, 6 món) được seed vào SQLite lần chạy đầu và tự đẩy lên MockAPI. Nên để MockAPI trống trước lần chạy đầu để tránh trùng với dữ liệu có sẵn.

## 3. Cấu trúc project

```
lib/
  config.dart               MSSV, tên Table/Field (tiền tố {MSSV}_), URL MockAPI
  main.dart                 Khởi tạo app + Provider
  models/                   DishCategory, Dish + DishImage, DishFilter
  data/repository.dart      SQLite: schema, seed, CRUD, validation, truy vấn lọc/sắp xếp
  data/api_client.dart      REST client MockAPI (timeout, xử lý lỗi)
  data/sync_service.dart    Đồng bộ push/pull local <-> MockAPI
  data/errors.dart          AppException, ValidationException, ApiException
  state/app_state.dart      Ngôn ngữ, bộ lọc, dữ liệu, phát hiện mạng, tự đồng bộ
  i18n/strings.dart         Chuỗi English / Tiếng Việt
  screens/                  Danh sách, chi tiết, thêm/sửa, quản lý loại món
  widgets/                  Ảnh có placeholder, nhãn Quick/Regular, banner mạng, dialog
```

## 4. Đối chiếu barem

| Yêu cầu | Nằm ở đâu |
|---|---|
| 02 model, ≥3 loại + ≥5 món, validation (0,75) | `models/`, `Repo._seed`, `Repo._validateDish` |
| List/detail/thêm/sửa/xóa + chọn loại (1,25) | `screens/dish_*_screen.dart` |
| Tìm kiếm, lọc nhiều điều kiện, sắp xếp, giữ bộ lọc (0,75) | `Repo.queryDishes`, `DishFilter` trong `AppState` |
| Nhiều ảnh, đổi ảnh đại diện, tối đa 1 thumbnail (0,5) | `Repo._insertImages`, `DishDetailScreen` |
| Quick/Regular, ràng buộc, xử lý lỗi (0,5) | `Dish.isQuick`, `Repo.deleteCategory`, empty/error states |
| Đa ngôn ngữ EN ↔ VI (0,75) | `i18n/strings.dart`, menu 🌐 trên màn hình danh sách |
| Offline lưu local (0,5) + tự đồng bộ (1,0) | `AppState` (connectivity), `SyncService` |

## 5. Kịch bản quay Video 1 (demo)

1. Mở app: chỉ vào tiêu đề có `{MSSV}_FoodManager` ở AppBar.
2. Danh sách → mở chi tiết (vuốt xem nhiều ảnh) → đổi ảnh đại diện → thêm ảnh bằng URL.
3. Thêm món (thử nhập sai để thấy validation, thử trùng tên cùng loại) → sửa món → xóa món (có hộp xác nhận).
4. Tìm theo tên, lọc loại + đang bán + khoảng giá cùng lúc, sắp xếp; vào chi tiết rồi quay lại: bộ lọc còn nguyên.
5. Thử xóa loại món đang dùng → báo lỗi.
6. Đổi ngôn ngữ English ↔ Tiếng Việt, chuyển màn hình: ngôn ngữ giữ nguyên.
7. **Offline**: tắt Wi-Fi/Data → thêm hoặc sửa món (banner vàng + biểu tượng đám mây cam) → bật mạng → banner "Syncing", biểu tượng cam biến mất, kiểm tra trên mockapi.io thấy bản ghi mới/đã sửa.

## 6. Ý chính cho Video 2 (thuyết minh)

- **Chỉ rõ đoạn code MSSV**: `lib/config.dart` (`kMssv`, `kProjectName`, class `Tbl`, class `Col`) và `Repo._createTables` (tên bảng/cột đều lấy từ `Tbl`/`Col`).
- **Quan hệ**: Dish N–1 DishCategory (`DishCategoryId`, kiểm tra trong `_validateDish`); Dish 1–N DishImage (FOREIGN KEY ... ON DELETE CASCADE).
- **Luồng đọc/ghi**: UI → `AppState` → `Repo` (SQLite) → `reload()` → `notifyListeners()`.
- **Offline-first**: mọi thao tác ghi vào SQLite trước, đánh dấu `SyncStatus` (0 đã đồng bộ, 1 chờ đẩy, 2 chờ xóa).
- **Phát hiện mạng**: `connectivity_plus` trong `AppState.init`; khi mạng trở lại gọi `sync()` tự động, ngoài ra có timer thử lại 30 giây.
- **Chống trùng**: bản ghi tạo offline có `RemoteId = null` → POST đúng một lần rồi lưu `RemoteId`; các lần sau PUT. Pull khớp theo `RemoteId`. Cột `UpdatedAt` bảo vệ trường hợp người dùng sửa giữa lúc đang đồng bộ.
- **Thứ tự đồng bộ**: push loại → push món → pull loại → pull món (món cần id loại trên server).
- **Xung đột**: bản ghi đang chờ đẩy thì giữ bản local khi pull (local thắng).

## 7. Giới hạn đã biết

- Nếu app bị tắt đúng lúc POST đã thành công nhưng chưa nhận phản hồi, lần đồng bộ sau có thể tạo một bản ghi trùng trên server (hiếm gặp, MockAPI không hỗ trợ idempotency key).
- Tìm theo tên không bỏ dấu tiếng Việt (gõ "pho" sẽ không ra "Phở").
