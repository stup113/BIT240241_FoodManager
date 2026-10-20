import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/api_client.dart';
import '../data/errors.dart';
import '../data/repository.dart';
import '../data/sync_service.dart';
import '../i18n/strings.dart';
import '../models/dish.dart';
import '../models/dish_category.dart';
import '../models/dish_filter.dart';

/// Trạng thái toàn cục: ngôn ngữ, bộ lọc (giữ khi chuyển màn hình), dữ liệu,
/// tình trạng mạng và đồng bộ tự động.
class AppState extends ChangeNotifier {
  final Repo repo = Repo.instance;
  late final SyncService _sync = SyncService(repo, ApiClient());

  // ngôn ngữ
  String lang = 'en';

  // dữ liệu + bộ lọc
  DishFilter filter = const DishFilter();
  List<Dish> dishes = [];
  List<DishCategory> categories = [];
  bool loading = true;
  String? loadError;

  // mạng + đồng bộ
  bool isOnline = true;
  bool syncing = false;
  int pending = 0;
  String? syncError;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _retryTimer;
  bool _syncRunning = false;
  bool _syncAgain = false;
  bool _disposed = false;

  String t(String key, [Map<String, String>? args]) =>
      Strings.tr(lang, key, args);

  /// Chuyển mọi lỗi thành thông báo đã dịch.
  String msg(Object e) {
    if (e is AppException) return t(e.key);
    if (e is ValidationException) return t(e.errors.values.first);
    if (e is ApiException) return t('err_api', {'msg': e.message});
    return t('err_unknown');
  }

  // ----------------------------------------------------------------- init
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    lang = prefs.getString('lang') ?? 'en';
    await reload();

    final conn = Connectivity();
    isOnline = _hasNetwork(await conn.checkConnectivity());
    // Tự động đồng bộ ngay khi mạng trở lại - không cần nút "Đồng bộ".
    _connSub = conn.onConnectivityChanged.listen((results) {
      final online = _hasNetwork(results);
      final regained = online && !isOnline;
      isOnline = online;
      notifyListeners();
      if (regained) sync();
    });
    // Thử lại định kỳ nếu còn bản ghi chờ (ví dụ MockAPI lỗi tạm thời).
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isOnline && pending > 0) sync();
    });
    if (isOnline) sync();
  }

  bool _hasNetwork(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- language
  Future<void> setLang(String code) async {
    if (code == lang) return;
    lang = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', code);
  }

  // ----------------------------------------------------------------- data
  Future<void> reload() async {
    try {
      categories = await repo.getCategories();
      dishes = await repo.queryDishes(filter);
      pending = await repo.pendingCount();
      loadError = null;
    } catch (e) {
      loadError = t('err_load');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setFilter(DishFilter f) async {
    filter = f;
    await reload();
  }

  Future<void> clearFilters() => setFilter(const DishFilter());

  /// Kéo để làm mới: đồng bộ (nếu có mạng) rồi tải lại.
  Future<void> refresh() async {
    await sync();
    await reload();
  }

  // ------------------------------------------------------------ mutations
  Future<int> saveDish(Dish d) async {
    final id = await repo.saveDish(d);
    await reload();
    _kick();
    return id;
  }

  Future<void> deleteDish(int id) async {
    await repo.deleteDish(id);
    await reload();
    _kick();
  }

  Future<void> updateImages(int dishId, List<DishImage> images) async {
    await repo.updateImages(dishId, images);
    await reload();
    _kick();
  }

  Future<void> saveCategory(DishCategory c) async {
    await repo.saveCategory(c);
    await reload();
    _kick();
  }

  Future<void> deleteCategory(int id) async {
    await repo.deleteCategory(id);
    // Nếu đang lọc theo loại vừa xóa thì bỏ điều kiện lọc.
    if (filter.categoryId == id) filter = filter.copyWith(categoryId: null);
    await reload();
    _kick();
  }

  // ----------------------------------------------------------------- sync
  void _kick() {
    if (isOnline) unawaited(sync());
  }

  Future<void> sync() async {
    if (!kApiConfigured || !isOnline) return;
    if (_syncRunning) {
      _syncAgain = true; // có thay đổi mới trong lúc đang đồng bộ -> chạy lại
      return;
    }
    _syncRunning = true;
    syncing = true;
    notifyListeners();
    try {
      do {
        _syncAgain = false;
        try {
          await _sync.sync();
          syncError = null;
        } catch (e) {
          syncError = e is ApiException ? e.message : e.toString();
          break;
        }
      } while (_syncAgain);
    } finally {
      _syncRunning = false;
      syncing = false;
    }
    await reload();
  }
}
