import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config.dart';
import '../models/dish.dart';
import '../models/dish_category.dart';
import '../models/dish_filter.dart';
import '../utils.dart';
import 'errors.dart';

/// Tầng lưu/đọc SQLite. Mọi thay đổi đều đánh dấu bản ghi `dirty`
/// (hoặc `deleted`) để SyncService tự động đẩy lên MockAPI khi có mạng.
class Repo {
  Repo._();
  static final Repo instance = Repo._();

  Future<Database>? _dbFuture;
  Future<Database> get db => _dbFuture ??= _open();

  int _now() => DateTime.now().microsecondsSinceEpoch;

  // ---------------------------------------------------------------- setup
  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), '${kMssv}_food_manager.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await _createTables(d);
        await _seed(d);
      },
    );
  }

  Future<void> _createTables(Database d) async {
    await d.execute('''
      CREATE TABLE ${Tbl.category} (
        ${Col.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${Col.name} TEXT NOT NULL,
        ${Col.description} TEXT NOT NULL DEFAULT '',
        ${Col.remoteId} TEXT,
        ${Col.syncStatus} INTEGER NOT NULL DEFAULT ${Sync.dirty},
        ${Col.updatedAt} INTEGER NOT NULL DEFAULT 0
      )''');
    // DishCategoryId được kiểm tra hợp lệ trong code (validateDish) thay vì
    // FOREIGN KEY, để việc xóa/đồng bộ offline không bị khóa ngoại chặn.
    await d.execute('''
      CREATE TABLE ${Tbl.dish} (
        ${Col.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${Col.name} TEXT NOT NULL,
        ${Col.price} REAL NOT NULL,
        ${Col.preparationTime} INTEGER NOT NULL,
        ${Col.isAvailable} INTEGER NOT NULL DEFAULT 1,
        ${Col.description} TEXT NOT NULL DEFAULT '',
        ${Col.dishCategoryId} INTEGER NOT NULL,
        ${Col.remoteId} TEXT,
        ${Col.syncStatus} INTEGER NOT NULL DEFAULT ${Sync.dirty},
        ${Col.updatedAt} INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE ${Tbl.image} (
        ${Col.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${Col.dishId} INTEGER NOT NULL
          REFERENCES ${Tbl.dish}(${Col.id}) ON DELETE CASCADE,
        ${Col.imageUrl} TEXT NOT NULL,
        ${Col.isThumbnail} INTEGER NOT NULL DEFAULT 0
      )''');
  }

  /// Dữ liệu mẫu: 3 loại món, 6 món, có món nhiều ảnh, có món ngừng bán.
  Future<void> _seed(Database d) async {
    final now = _now();
    String img(String s) => 'https://picsum.photos/seed/$s/600/400';

    Future<int> cat(String name, String desc) => d.insert(Tbl.category, {
          Col.name: name,
          Col.description: desc,
          Col.syncStatus: Sync.dirty,
          Col.updatedAt: now,
        });

    Future<void> dish(String name, double price, int time, bool avail,
        String desc, int catId, List<String> imgs) async {
      final id = await d.insert(Tbl.dish, {
        Col.name: name,
        Col.price: price,
        Col.preparationTime: time,
        Col.isAvailable: avail ? 1 : 0,
        Col.description: desc,
        Col.dishCategoryId: catId,
        Col.syncStatus: Sync.dirty,
        Col.updatedAt: now,
      });
      for (var i = 0; i < imgs.length; i++) {
        await d.insert(Tbl.image, {
          Col.dishId: id,
          Col.imageUrl: imgs[i],
          Col.isThumbnail: i == 0 ? 1 : 0,
        });
      }
    }

    final main = await cat('Main Course', 'Rice, noodles and other main dishes');
    final drinks = await cat('Drinks', 'Coffee, juice and soft drinks');
    final desserts = await cat('Desserts', 'Sweet dishes and puddings');

    await dish('Beef Pho', 45000, 20, true, 'Traditional Hanoi beef noodle soup',
        main, ['https://www.recipetineats.com/tachyon/2019/04/Beef-Pho_6.jpg?resize=900%2C1260&zoom=1']);
    await dish('Banh Mi', 25000, 10, true, 'Crispy baguette with pork and herbs',
        main, ['https://www.allrecipes.com/thmb/ieRkFw0X8NX5nzZcOVSPHL2ElOU=/750x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/roasted-pork-banh-mi-vietnamese-sandwitch-ddmfs-3X4-0332-cfb4d2e149e7476ab2a2b4030c543f1b.jpg']);
    await dish('Bun Cha', 50000, 25, true, 'Grilled pork with rice vermicelli',
        main, ['https://www.recipetineats.com/tachyon/2019/01/Vietnamese-Pork-Meatballs_6.jpg?resize=900%2C1260&zoom=1']);
    await dish('Iced Coffee', 20000, 5, true, 'Vietnamese coffee with milk',
        drinks, ['https://f5cafe.com/wp-content/uploads/2020/06/ca_phe_sua_da.jpg']);
    await dish('Orange Juice', 30000, 10, false, 'Freshly squeezed orange juice',
        drinks, ['https://banhtrangphucuong.vn/wp-content/uploads/2022/10/Nuoc-cam-ep.jpg']);
    await dish('Yogurt', 15000, 5, true,
        'Sweet', desserts, ['https://www.cookingclassy.com/wp-content/uploads/2025/08/homemade-yogurt-15-1365x2048.jpg']);
  }

  // ----------------------------------------------------------- categories
  Future<List<DishCategory>> getCategories() async {
    final d = await db;
    final rows = await d.query(
      Tbl.category,
      where: '${Col.syncStatus}<>?',
      whereArgs: [Sync.deleted],
      orderBy: '${Col.name} COLLATE NOCASE ASC',
    );
    return rows.map(DishCategory.fromMap).toList();
  }

  Future<int> saveCategory(DishCategory c) async {
    final d = await db;
    return d.transaction((txn) async {
      final name = c.name.trim();
      if (name.isEmpty) {
        throw const ValidationException({'name': 'err_name_required'});
      }
      final others = await txn.query(
        Tbl.category,
        columns: [Col.id, Col.name],
        where: '${Col.syncStatus}<>?',
        whereArgs: [Sync.deleted],
      );
      final lower = name.toLowerCase();
      if (others.any((r) =>
          r[Col.id] != c.id &&
          (r[Col.name] as String).trim().toLowerCase() == lower)) {
        throw const ValidationException({'name': 'err_category_duplicate'});
      }
      final values = {
        Col.name: name,
        Col.description: c.description.trim(),
        Col.syncStatus: Sync.dirty,
        Col.updatedAt: _now(),
      };
      if (c.id == null) return txn.insert(Tbl.category, values);
      final n = await txn.update(Tbl.category, values,
          where: '${Col.id}=? AND ${Col.syncStatus}<>?',
          whereArgs: [c.id, Sync.deleted]);
      if (n == 0) throw const AppException('err_not_found');
      return c.id!;
    });
  }

  /// Không cho xóa loại món đang có món sử dụng.
  Future<void> deleteCategory(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      final rows = await txn.query(Tbl.category,
          where: '${Col.id}=? AND ${Col.syncStatus}<>?',
          whereArgs: [id, Sync.deleted]);
      if (rows.isEmpty) throw const AppException('err_not_found');
      final used = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM ${Tbl.dish} '
              'WHERE ${Col.dishCategoryId}=? AND ${Col.syncStatus}<>?',
              [id, Sync.deleted])) ??
          0;
      if (used > 0) throw const AppException('err_category_in_use');
      if (rows.first[Col.remoteId] == null) {
        await txn.delete(Tbl.category,
            where: '${Col.id}=?', whereArgs: [id]);
      } else {
        await txn.update(
            Tbl.category, {Col.syncStatus: Sync.deleted, Col.updatedAt: _now()},
            where: '${Col.id}=?', whereArgs: [id]);
      }
    });
  }

  // --------------------------------------------------------------- dishes
  Future<List<Dish>> queryDishes(DishFilter f) async {
    final d = await db;
    final where = <String>['${Col.syncStatus}<>?'];
    final args = <Object?>[Sync.deleted];
    if (f.categoryId != null) {
      where.add('${Col.dishCategoryId}=?');
      args.add(f.categoryId);
    }
    if (f.onlyAvailable) where.add('${Col.isAvailable}=1');
    if (f.minPrice != null) {
      where.add('${Col.price}>=?');
      args.add(f.minPrice);
    }
    if (f.maxPrice != null) {
      where.add('${Col.price}<=?');
      args.add(f.maxPrice);
    }
    final order = switch (f.sort) {
      SortOption.priceAsc => '${Col.price} ASC, ${Col.id} ASC',
      SortOption.priceDesc => '${Col.price} DESC, ${Col.id} ASC',
      SortOption.timeAsc => '${Col.preparationTime} ASC, ${Col.id} ASC',
      SortOption.none => '${Col.id} ASC',
    };
    final rows = await d.query(Tbl.dish,
        where: where.join(' AND '), whereArgs: args, orderBy: order);
    var dishes = await _withImages(d, rows);
    // Tìm theo một phần tên (không phân biệt hoa/thường, hỗ trợ Unicode).
    final q = f.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      dishes = dishes.where((x) => x.name.toLowerCase().contains(q)).toList();
    }
    return dishes;
  }

  Future<Dish?> getDish(int id) async {
    final d = await db;
    final rows = await d.query(Tbl.dish,
        where: '${Col.id}=? AND ${Col.syncStatus}<>?',
        whereArgs: [id, Sync.deleted]);
    if (rows.isEmpty) return null;
    return (await _withImages(d, rows)).first;
  }

  Future<List<Dish>> _withImages(
      DatabaseExecutor d, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r[Col.id] as int).toList();
    final marks = List.filled(ids.length, '?').join(',');
    final imgRows = await d.query(Tbl.image,
        where: '${Col.dishId} IN ($marks)',
        whereArgs: ids,
        orderBy: '${Col.id} ASC');
    final byDish = <int, List<DishImage>>{};
    for (final r in imgRows) {
      final img = DishImage.fromMap(r);
      byDish.putIfAbsent(img.dishId!, () => []).add(img);
    }
    return rows
        .map((r) => Dish.fromMap(r, byDish[r[Col.id] as int] ?? const []))
        .toList();
  }

  /// Kiểm tra: Name không rỗng; Price > 0; PreparationTime > 0;
  /// DishCategoryId hợp lệ; tên không trùng trong cùng một loại.
  Future<void> _validateDish(DatabaseExecutor ex, Dish d) async {
    final errors = <String, String>{};
    final name = d.name.trim();
    if (name.isEmpty) errors['name'] = 'err_name_required';
    if (!(d.price.isFinite && d.price > 0)) errors['price'] = 'err_price_invalid';
    if (d.preparationTime <= 0) errors['time'] = 'err_time_invalid';

    final cat = await ex.query(Tbl.category,
        where: '${Col.id}=? AND ${Col.syncStatus}<>?',
        whereArgs: [d.dishCategoryId, Sync.deleted]);
    if (cat.isEmpty) {
      errors['category'] = 'err_category_invalid';
    } else if (name.isNotEmpty) {
      final same = await ex.query(Tbl.dish,
          columns: [Col.id, Col.name],
          where: '${Col.dishCategoryId}=? AND ${Col.syncStatus}<>?',
          whereArgs: [d.dishCategoryId, Sync.deleted]);
      final lower = name.toLowerCase();
      if (same.any((r) =>
          r[Col.id] != d.id &&
          (r[Col.name] as String).trim().toLowerCase() == lower)) {
        errors['name'] = 'err_dish_duplicate';
      }
    }
    if (d.images.any((i) => !isHttpUrl(i.imageUrl))) {
      errors['images'] = 'err_image_url';
    }
    if (errors.isNotEmpty) throw ValidationException(errors);
  }

  /// Thêm hoặc sửa món (kèm danh sách ảnh) trong một transaction.
  Future<int> saveDish(Dish dish) async {
    final d = await db;
    return d.transaction((txn) async {
      await _validateDish(txn, dish);
      final values = {
        Col.name: dish.name.trim(),
        Col.price: dish.price,
        Col.preparationTime: dish.preparationTime,
        Col.isAvailable: dish.isAvailable ? 1 : 0,
        Col.description: dish.description.trim(),
        Col.dishCategoryId: dish.dishCategoryId,
        Col.syncStatus: Sync.dirty,
        Col.updatedAt: _now(),
      };
      final int id;
      if (dish.id == null) {
        id = await txn.insert(Tbl.dish, values);
      } else {
        final n = await txn.update(Tbl.dish, values,
            where: '${Col.id}=? AND ${Col.syncStatus}<>?',
            whereArgs: [dish.id, Sync.deleted]);
        if (n == 0) throw const AppException('err_not_found');
        id = dish.id!;
        await txn.delete(Tbl.image,
            where: '${Col.dishId}=?', whereArgs: [id]);
      }
      await _insertImages(txn, id, dish.images);
      return id;
    });
  }

  Future<void> deleteDish(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      final rows = await txn.query(Tbl.dish,
          where: '${Col.id}=? AND ${Col.syncStatus}<>?',
          whereArgs: [id, Sync.deleted]);
      if (rows.isEmpty) throw const AppException('err_not_found');
      if (rows.first[Col.remoteId] == null) {
        // Chưa từng lên server -> xóa hẳn.
        await txn.delete(Tbl.image, where: '${Col.dishId}=?', whereArgs: [id]);
        await txn.delete(Tbl.dish, where: '${Col.id}=?', whereArgs: [id]);
      } else {
        // Đã có trên server -> đánh dấu để đồng bộ xóa sau.
        await txn.update(
            Tbl.dish, {Col.syncStatus: Sync.deleted, Col.updatedAt: _now()},
            where: '${Col.id}=?', whereArgs: [id]);
      }
    });
  }

  /// Thay toàn bộ danh sách ảnh của món (thêm ảnh / đổi ảnh đại diện / xóa ảnh).
  Future<void> updateImages(int dishId, List<DishImage> images) async {
    if (images.any((i) => !isHttpUrl(i.imageUrl))) {
      throw const ValidationException({'images': 'err_image_url'});
    }
    final d = await db;
    await d.transaction((txn) async {
      final n = await txn.update(Tbl.dish,
          {Col.syncStatus: Sync.dirty, Col.updatedAt: _now()},
          where: '${Col.id}=? AND ${Col.syncStatus}<>?',
          whereArgs: [dishId, Sync.deleted]);
      if (n == 0) throw const AppException('err_not_found');
      await txn.delete(Tbl.image,
          where: '${Col.dishId}=?', whereArgs: [dishId]);
      await _insertImages(txn, dishId, images);
    });
  }

  /// Bảo đảm mỗi món có tối đa 01 ảnh IsThumbnail = true; nếu có ảnh mà chưa
  /// đặt thì ảnh đầu tiên làm ảnh đại diện.
  Future<void> _insertImages(
      DatabaseExecutor ex, int dishId, List<DishImage> imgs) async {
    var used = false;
    final list = <DishImage>[];
    for (final i in imgs) {
      final thumb = i.isThumbnail && !used;
      if (thumb) used = true;
      list.add(i.copyWith(isThumbnail: thumb));
    }
    if (list.isNotEmpty && !used) list[0] = list[0].copyWith(isThumbnail: true);
    for (final i in list) {
      await ex.insert(Tbl.image, {
        Col.dishId: dishId,
        Col.imageUrl: i.imageUrl.trim(),
        Col.isThumbnail: i.isThumbnail ? 1 : 0,
      });
    }
  }

  // ----------------------------------------------------------------- sync
  /// Số bản ghi đang chờ đồng bộ (loại + món).
  Future<int> pendingCount() async {
    final d = await db;
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(await d.rawQuery(
            'SELECT COUNT(*) FROM $table WHERE ${Col.syncStatus}<>?',
            [Sync.synced])) ??
        0;
    return await count(Tbl.category) + await count(Tbl.dish);
  }
}
