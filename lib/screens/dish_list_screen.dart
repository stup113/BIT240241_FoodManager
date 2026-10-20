import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/dish.dart';
import '../models/dish_filter.dart';
import '../state/app_state.dart';
import '../utils.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';
import 'dish_detail_screen.dart';
import 'dish_form_screen.dart';

class DishListScreen extends StatefulWidget {
  const DishListScreen({super.key});

  @override
  State<DishListScreen> createState() => _DishListScreenState();
}

class _DishListScreenState extends State<DishListScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // Khôi phục từ khóa đã nhập (bộ lọc được giữ trong AppState).
    _search = TextEditingController(text: context.read<AppState>().filter.query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _sortLabel(AppState s, SortOption o) => switch (o) {
        SortOption.none => s.t('sort_none'),
        SortOption.priceAsc => s.t('sort_price_asc'),
        SortOption.priceDesc => s.t('sort_price_desc'),
        SortOption.timeAsc => s.t('sort_time_asc'),
      };

  Future<void> _openPriceSheet(AppState s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PriceSheet(initial: s.filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.filter;
    final scheme = Theme.of(context).colorScheme;
    final catValue = s.categories.any((c) => c.id == f.categoryId)
        ? f.categoryId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('app_title')),
            Text(kProjectName,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.outline)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.t('manage_categories'),
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          PopupMenuButton<String>(
            tooltip: s.t('language'),
            icon: const Icon(Icons.language),
            onSelected: s.setLang,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: 'en',
                  checked: s.lang == 'en',
                  child: Text(s.t('english'))),
              CheckedPopupMenuItem(
                  value: 'vi',
                  checked: s.lang == 'vi',
                  child: Text(s.t('vietnamese'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(s.t('add_dish')),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DishFormScreen())),
      ),
      body: Column(
        children: [
          const StatusBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: s.t('search_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          s.setFilter(f.copyWith(query: ''));
                        },
                      ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                isDense: true,
              ),
              onChanged: (v) => s.setFilter(f.copyWith(query: v)),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // Lọc theo loại
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: catValue,
                      items: [
                        DropdownMenuItem<int?>(
                            value: null, child: Text(s.t('all_categories'))),
                        for (final c in s.categories)
                          DropdownMenuItem<int?>(
                              value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => s.setFilter(f.copyWith(categoryId: v)),
                    ),
                  ),
                ),
                // Lọc đang bán
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s.t('only_available')),
                    selected: f.onlyAvailable,
                    onSelected: (v) => s.setFilter(f.copyWith(onlyAvailable: v)),
                  ),
                ),
                // Lọc khoảng giá
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    backgroundColor:
                        f.hasPriceRange ? scheme.secondaryContainer : null,
                    label: Text(f.hasPriceRange
                        ? '${f.minPrice == null ? '0' : formatPrice(f.minPrice!)} - ${f.maxPrice == null ? '∞' : formatPrice(f.maxPrice!)}'
                        : s.t('price_range')),
                    onPressed: () => _openPriceSheet(s),
                  ),
                ),
                // Sắp xếp
                PopupMenuButton<SortOption>(
                  tooltip: s.t('sort'),
                  onSelected: (v) => s.setFilter(f.copyWith(sort: v)),
                  itemBuilder: (_) => [
                    for (final o in SortOption.values)
                      CheckedPopupMenuItem(
                          value: o,
                          checked: f.sort == o,
                          child: Text(_sortLabel(s, o))),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.sort, size: 18),
                    label: Text(_sortLabel(s, f.sort)),
                  ),
                ),
                if (f.isActive)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.filter_alt_off, size: 18),
                      label: Text(s.t('clear_filters')),
                      onPressed: () {
                        _search.clear();
                        s.clearFilters();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList(s)),
        ],
      ),
    );
  }

  Widget _buildList(AppState s) {
    if (s.loading) return const Center(child: CircularProgressIndicator());
    if (s.loadError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.loadError!),
          const SizedBox(height: 8),
          FilledButton(onPressed: s.reload, child: Text(s.t('retry'))),
        ]),
      );
    }
    if (s.dishes.isEmpty) {
      return RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          Icon(Icons.ramen_dining_outlined,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Center(
              child: Text(s.t(s.filter.isActive ? 'no_results' : 'no_dishes'))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        itemCount: s.dishes.length,
        separatorBuilder: (_, i) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _DishCard(dish: s.dishes[i]),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  final Dish dish;
  const _DishCard({required this.dish});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final catName = s.categories
        .where((c) => c.id == dish.dishCategoryId)
        .map((c) => c.name)
        .firstOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DishDetailScreen(dishId: dish.id!))),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: NetImage(
                  url: dish.thumbnail?.imageUrl, width: 76, height: 76),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (dish.syncStatus != 0)
                      Tooltip(
                        message: s.t('pending_icon_tip'),
                        child: const Icon(Icons.cloud_upload_outlined,
                            size: 16, color: Colors.orange),
                      ),
                  ]),
                  if (catName != null)
                    Text(catName,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(formatPrice(dish.price),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    AvailabilityBadge(available: dish.isAvailable),
                  ]),
                  const SizedBox(height: 4),
                  PrepTimeChip(dish: dish),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DishFormScreen(dishId: dish.id)));
                } else {
                  await deleteDishWithConfirm(context, dish);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(s.t('edit'))),
                PopupMenuItem(value: 'delete', child: Text(s.t('delete'))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// Bottom sheet nhập khoảng giá; chỉ áp dụng khi hợp lệ.
class _PriceSheet extends StatefulWidget {
  final DishFilter initial;
  const _PriceSheet({required this.initial});

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final TextEditingController _min = TextEditingController(
      text: widget.initial.minPrice == null
          ? ''
          : numberToText(widget.initial.minPrice!));
  late final TextEditingController _max = TextEditingController(
      text: widget.initial.maxPrice == null
          ? ''
          : numberToText(widget.initial.maxPrice!));
  String? _minErr;
  String? _maxErr;
  String? _rangeErr;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// Trả về (ok, giá trị). Ô trống = không giới hạn.
  (bool, double?) _parse(String text) {
    if (text.trim().isEmpty) return (true, null);
    final v = parseNumber(text);
    if (v == null) return (false, null);
    return (true, v);
  }

  void _apply() {
    final s = context.read<AppState>();
    final (okMin, minV) = _parse(_min.text);
    final (okMax, maxV) = _parse(_max.text);
    setState(() {
      _minErr = okMin ? null : s.t('err_number');
      _maxErr = okMax ? null : s.t('err_number');
      _rangeErr = null;
      if (okMin && okMax) {
        if ((minV != null && minV < 0) ||
            (maxV != null && maxV < 0) ||
            (minV != null && maxV != null && minV > maxV)) {
          _rangeErr = s.t('err_price_range');
        }
      }
    });
    if (_minErr != null || _maxErr != null || _rangeErr != null) return;
    s.setFilter(s.filter.copyWith(minPrice: minV, maxPrice: maxV));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('price_range'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _min,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: s.t('min_price'), errorText: _minErr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: s.t('max_price'), errorText: _maxErr),
              ),
            ),
          ]),
          if (_rangeErr != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_rangeErr!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () {
                s.setFilter(s.filter.copyWith(minPrice: null, maxPrice: null));
                Navigator.pop(context);
              },
              child: Text(s.t('clear_filters')),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _apply, child: Text(s.t('apply'))),
          ]),
        ],
      ),
    );
  }
}
