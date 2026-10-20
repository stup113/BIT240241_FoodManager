import 'package:sqflite/sqflite.dart';

import '../config.dart';
import '../models/dish.dart';
import '../models/dish_category.dart';
import 'api_client.dart';
import 'errors.dart';
import 'repository.dart';

/// Đồng bộ hai chiều SQLite <-> MockAPI.
///
/// Mỗi bản ghi local có: RemoteId (id trên server, null nếu chưa lên server),
/// SyncStatus (0 đã đồng bộ / 1 chờ đẩy / 2 chờ xóa) và UpdatedAt.
///
/// Một lượt đồng bộ gồm:
///  1. PUSH loại món  -> 2. PUSH món   (loại trước vì món tham chiếu loại)
///  3. PULL loại món  -> 4. PULL món   -> 5. dọn loại đã bị xóa trên server
///
/// Chống trùng bản ghi: bản ghi tạo offline chỉ POST đúng một lần; ngay khi có
/// phản hồi, RemoteId được lưu lại nên các lần sau chỉ PUT. PULL luôn khớp theo
/// RemoteId nên không thêm bản ghi trùng.
class SyncService {
  SyncService(this._repo, this._api);

  final Repo _repo;
  final ApiClient _api;

  /// Gọi một lượt đồng bộ; ném [ApiException] nếu lỗi mạng (sẽ thử lại sau).
  Future<void> sync() async {
    final db = await _repo.db;
    await _pushCategories(db);
    await _pushDishes(db);
    final remoteCategoryIds = await _pullCategories(db);
    await _pullDishes(db);
    await _pruneCategories(db, remoteCategoryIds);
  }

  // ----------------------------------------------------------------- PUSH
  Future<void> _pushCategories(Database db) async {
    final rows = await db.query(Tbl.category,
        where: '${Col.syncStatus}<>?',
        whereArgs: [Sync.synced],
        orderBy: '${Col.id} ASC');
    for (final r in rows) {
      final id = r[Col.id] as int;
      final remoteId = r[Col.remoteId] as String?;
      final status = r[Col.syncStatus] as int;
      final stamp = r[Col.updatedAt] as int;

      if (status == Sync.deleted) {
        if (remoteId != null) await _api.delete(Tbl.category, remoteId);
        await db.delete(Tbl.category, where: '${Col.id}=?', whereArgs: [id]);
        continue;
      }
      final cat = DishCategory.fromMap(r);
      final String rid;
      if (remoteId == null) {
        final res = await _api.create(Tbl.category, cat.toJson());
        rid = res['id'].toString();
      } else {
        await _api.update(Tbl.category, remoteId, cat.toJson());
        rid = remoteId;
      }
      await _markPushed(db, Tbl.category, id, rid, stamp);
    }
  }

  Future<void> _pushDishes(Database db) async {
    final rows = await db.query(Tbl.dish,
        where: '${Col.syncStatus}<>?',
        whereArgs: [Sync.synced],
        orderBy: '${Col.id} ASC');
    for (final r in rows) {
      final id = r[Col.id] as int;
      final remoteId = r[Col.remoteId] as String?;
      final status = r[Col.syncStatus] as int;
      final stamp = r[Col.updatedAt] as int;

      if (status == Sync.deleted) {
        if (remoteId != null) await _api.delete(Tbl.dish, remoteId);
        await db.delete(Tbl.image, where: '${Col.dishId}=?', whereArgs: [id]);
        await db.delete(Tbl.dish, where: '${Col.id}=?', whereArgs: [id]);
        continue;
      }
      // Cần id của loại trên server.
      final catRows = await db.query(Tbl.category,
          columns: [Col.remoteId],
          where: '${Col.id}=?',
          whereArgs: [r[Col.dishCategoryId]]);
      final catRemote =
          catRows.isEmpty ? null : catRows.first[Col.remoteId] as String?;
      if (catRemote == null) {
        throw const ApiException('Category not synced yet');
      }
      final imgRows = await db.query(Tbl.image,
          where: '${Col.dishId}=?', whereArgs: [id], orderBy: '${Col.id} ASC');
      final dish = Dish.fromMap(r, imgRows.map(DishImage.fromMap).toList());

      final String rid;
      if (remoteId == null) {
        final res = await _api.create(Tbl.dish, dish.toJson(catRemote));
        rid = res['id'].toString();
      } else {
        await _api.update(Tbl.dish, remoteId, dish.toJson(catRemote));
        rid = remoteId;
      }
      await _markPushed(db, Tbl.dish, id, rid, stamp);
    }
  }

  /// Luôn lưu RemoteId (để lần sau chỉ PUT, không POST trùng). Chỉ chuyển về
  /// "đã đồng bộ" nếu bản ghi không bị người dùng sửa trong lúc đang đẩy.
  Future<void> _markPushed(
      Database db, String table, int id, String remoteId, int stamp) {
    return db.rawUpdate(
      'UPDATE $table SET ${Col.remoteId}=?, '
      '${Col.syncStatus}=CASE WHEN ${Col.updatedAt}=? THEN ? '
      'ELSE ${Col.syncStatus} END WHERE ${Col.id}=?',
      [remoteId, stamp, Sync.synced, id],
    );
  }

  // ----------------------------------------------------------------- PULL
  /// Trả về tập RemoteId hiện có trên server.
  Future<Set<String>> _pullCategories(Database db) async {
    final remote = await _api.list(Tbl.category);
    final local = await db.query(Tbl.category);
    final byRemote = <String, Map<String, Object?>>{
      for (final r in local)
        if (r[Col.remoteId] != null) r[Col.remoteId] as String: r,
    };
    final seen = <String>{};
    await db.transaction((txn) async {
      for (final item in remote) {
        final rid = item['id'].toString();
        seen.add(rid);
        final name = (item[Col.name] ?? '').toString().trim();
        if (name.isEmpty) continue; // dữ liệu server không hợp lệ -> bỏ qua
        final desc = (item[Col.description] ?? '').toString();
        final existing = byRemote[rid];
        if (existing == null) {
          await txn.insert(Tbl.category, {
            Col.name: name,
            Col.description: desc,
            Col.remoteId: rid,
            Col.syncStatus: Sync.synced,
            Col.updatedAt: DateTime.now().microsecondsSinceEpoch,
          });
        } else if (existing[Col.syncStatus] == Sync.synced) {
          await txn.update(
              Tbl.category, {Col.name: name, Col.description: desc},
              where: '${Col.id}=?', whereArgs: [existing[Col.id]]);
        } // đang có thay đổi local chưa đẩy -> giữ bản local
      }
    });
    return seen;
  }

  Future<void> _pullDishes(Database db) async {
    final remote = await _api.list(Tbl.dish);
    final cats = await db.query(Tbl.category,
        columns: [Col.id, Col.remoteId],
        where: '${Col.remoteId} IS NOT NULL');
    final catByRemote = <String, int>{
      for (final c in cats) c[Col.remoteId] as String: c[Col.id] as int,
    };
    final local = await db.query(Tbl.dish);
    final byRemote = <String, Map<String, Object?>>{
      for (final r in local)
        if (r[Col.remoteId] != null) r[Col.remoteId] as String: r,
    };
    final seen = <String>{};

    await db.transaction((txn) async {
      for (final item in remote) {
        final rid = item['id'].toString();
        seen.add(rid);
        final localCat = catByRemote[item[Col.dishCategoryId]?.toString()];
        final name = (item[Col.name] ?? '').toString().trim();
        final price = num.tryParse('${item[Col.price]}')?.toDouble();
        final time = num.tryParse('${item[Col.preparationTime]}')?.toInt();
        if (localCat == null ||
            name.isEmpty ||
            price == null ||
            !(price > 0) ||
            time == null ||
            time <= 0) {
          continue; // dữ liệu server không hợp lệ -> bỏ qua
        }
        final avail = _toBool(item[Col.isAvailable]);
        final values = <String, Object?>{
          Col.name: name,
          Col.price: price,
          Col.preparationTime: time,
          Col.isAvailable: avail ? 1 : 0,
          Col.description: (item[Col.description] ?? '').toString(),
          Col.dishCategoryId: localCat,
        };
        final images = _parseImages(item[Col.dishImage]);
        final existing = byRemote[rid];

        int? dishId;
        if (existing == null) {
          dishId = await txn.insert(Tbl.dish, {
            ...values,
            Col.remoteId: rid,
            Col.syncStatus: Sync.synced,
            Col.updatedAt: DateTime.now().microsecondsSinceEpoch,
          });
        } else if (existing[Col.syncStatus] == Sync.synced) {
          dishId = existing[Col.id] as int;
          await txn.update(Tbl.dish, values,
              where: '${Col.id}=?', whereArgs: [dishId]);
          await txn.delete(Tbl.image,
              where: '${Col.dishId}=?', whereArgs: [dishId]);
        }
        if (dishId != null) {
          for (final img in images) {
            await txn.insert(Tbl.image, {
              Col.dishId: dishId,
              Col.imageUrl: img.imageUrl,
              Col.isThumbnail: img.isThumbnail ? 1 : 0,
            });
          }
        }
      }
      // Món đã đồng bộ nhưng không còn trên server -> đã bị xóa ở nơi khác.
      for (final r in local) {
        final rid = r[Col.remoteId] as String?;
        if (rid != null &&
            r[Col.syncStatus] == Sync.synced &&
            !seen.contains(rid)) {
          await txn.delete(Tbl.image,
              where: '${Col.dishId}=?', whereArgs: [r[Col.id]]);
          await txn.delete(Tbl.dish,
              where: '${Col.id}=?', whereArgs: [r[Col.id]]);
        }
      }
    });
  }

  /// Xóa loại món đã đồng bộ nhưng không còn trên server (và không còn món dùng).
  Future<void> _pruneCategories(Database db, Set<String> remoteIds) async {
    final local = await db.query(Tbl.category,
        where: '${Col.remoteId} IS NOT NULL AND ${Col.syncStatus}=?',
        whereArgs: [Sync.synced]);
    for (final r in local) {
      if (remoteIds.contains(r[Col.remoteId])) continue;
      final used = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM ${Tbl.dish} WHERE ${Col.dishCategoryId}=?',
              [r[Col.id]])) ??
          0;
      if (used == 0) {
        await db.delete(Tbl.category,
            where: '${Col.id}=?', whereArgs: [r[Col.id]]);
      }
    }
  }

  bool _toBool(Object? v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';

  List<DishImage> _parseImages(Object? raw) {
    if (raw is! List) return const [];
    final out = <DishImage>[];
    var thumbUsed = false;
    for (final e in raw) {
      if (e is! Map) continue;
      final url = (e[Col.imageUrl] ?? '').toString().trim();
      if (url.isEmpty) continue;
      final thumb = _toBool(e[Col.isThumbnail]) && !thumbUsed;
      if (thumb) thumbUsed = true;
      out.add(DishImage(imageUrl: url, isThumbnail: thumb));
    }
    if (out.isNotEmpty && !thumbUsed) out[0] = out[0].copyWith(isThumbnail: true);
    return out;
  }
}
