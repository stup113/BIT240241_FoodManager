import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/errors.dart';
import '../models/dish.dart';
import '../state/app_state.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';

/// Màn hình thêm (dishId == null) hoặc sửa món.
class DishFormScreen extends StatefulWidget {
  final int? dishId;
  const DishFormScreen({super.key, this.dishId});

  @override
  State<DishFormScreen> createState() => _DishFormScreenState();
}

class _DishFormScreenState extends State<DishFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _time = TextEditingController();
  final _desc = TextEditingController();
  final _imageUrl = TextEditingController();

  int? _categoryId;
  bool _available = true;
  List<DishImage> _images = [];
  String? _imageError;

  bool _loading = false;
  bool _notFound = false;
  bool _saving = false;

  /// Lỗi do tầng lưu trữ trả về (trùng tên, loại không tồn tại...).
  final Map<String, String> _serverErrors = {};

  bool get _isEdit => widget.dishId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _loadDish();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _time.dispose();
    _desc.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _loadDish() async {
    final d = await context.read<AppState>().repo.getDish(widget.dishId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (d == null) {
        _notFound = true; // Id không tồn tại
        return;
      }
      _name.text = d.name;
      _price.text = numberToText(d.price);
      _time.text = '${d.preparationTime}';
      _desc.text = d.description;
      _categoryId = d.dishCategoryId;
      _available = d.isAvailable;
      _images = List.of(d.images);
    });
  }

  String? _server(AppState s, String field) =>
      _serverErrors[field] == null ? null : s.t(_serverErrors[field]!);

  void _addImage(AppState s) {
    final url = _imageUrl.text.trim();
    if (!isHttpUrl(url)) {
      setState(() => _imageError = s.t('err_image_url'));
      return;
    }
    setState(() {
      _images = [..._images, DishImage(imageUrl: url, isThumbnail: _images.isEmpty)];
      _imageUrl.clear();
      _imageError = null;
    });
  }

  void _setThumb(int index) => setState(() {
        _images = [
          for (var i = 0; i < _images.length; i++)
            _images[i].copyWith(isThumbnail: i == index),
        ];
      });

  void _removeImage(int index) => setState(() {
        final removedThumb = _images[index].isThumbnail;
        _images = [
          for (var i = 0; i < _images.length; i++)
            if (i != index) _images[i],
        ];
        if (removedThumb && _images.isNotEmpty) {
          _images[0] = _images[0].copyWith(isThumbnail: true);
        }
      });

  Future<void> _save() async {
    final s = context.read<AppState>();
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dish = Dish(
        id: widget.dishId,
        name: _name.text.trim(),
        price: parseNumber(_price.text)!,
        preparationTime: int.parse(_time.text.trim()),
        isAvailable: _available,
        description: _desc.text.trim(),
        dishCategoryId: _categoryId!,
        images: _images,
      );
      await s.saveDish(dish);
      if (!mounted) return;
      showSnack(context, s.t('saved'));
      Navigator.pop(context, true);
    } on ValidationException catch (e) {
      _serverErrors
        ..clear()
        ..addAll(e.errors);
      if (e.errors.containsKey('images') && mounted) {
        showSnack(context, s.t(e.errors['images']!));
      }
      _formKey.currentState?.validate();
    } catch (e) {
      if (mounted) showSnack(context, s.msg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final title = s.t(_isEdit ? 'edit_dish' : 'add_dish');

    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_notFound) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off, size: 56),
            const SizedBox(height: 8),
            Text(s.t('err_not_found')),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s.t('close'))),
          ]),
        ),
      );
    }

    final catValue =
        s.categories.any((c) => c.id == _categoryId) ? _categoryId : null;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: s.t('name'), border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? s.t('err_name_required')
                  : _server(s, 'name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: s.t('price'),
                  suffixText: '₫',
                  border: const OutlineInputBorder()),
              validator: (v) {
                final n = parseNumber(v ?? '');
                if (n == null || n <= 0) return s.t('err_price_invalid');
                return _server(s, 'price');
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _time,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: s.t('prep_time'),
                  border: const OutlineInputBorder()),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return s.t('err_time_invalid');
                return _server(s, 'time');
              },
            ),
            const SizedBox(height: 12),
            if (s.categories.isEmpty)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(s.t('create_category_first')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CategoriesScreen())),
                ),
              )
            else
              DropdownButtonFormField<int>(
                value: catValue,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: s.t('category'),
                    border: const OutlineInputBorder()),
                items: [
                  for (final c in s.categories)
                    DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() {
                  _categoryId = v;
                  _serverErrors.remove('name'); // trùng tên tính theo loại
                }),
                validator: (v) =>
                    v == null ? s.t('err_category_required') : _server(s, 'category'),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: s.t('description'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('available')),
              value: _available,
              onChanged: (v) => setState(() => _available = v),
            ),
            const Divider(),
            Text(s.t('images'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_images.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(s.t('no_images'),
                    style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ),
            for (var i = 0; i < _images.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: NetImage(url: _images[i].imageUrl, width: 56, height: 56),
                ),
                title: Text(_images[i].imageUrl,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: _images[i].isThumbnail ? Text(s.t('thumbnail')) : null,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: s.t('set_thumbnail'),
                    icon: Icon(
                        _images[i].isThumbnail ? Icons.star : Icons.star_outline,
                        color: _images[i].isThumbnail ? Colors.amber : null),
                    onPressed: () => _setThumb(i),
                  ),
                  IconButton(
                    tooltip: s.t('delete_image'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeImage(i),
                  ),
                ]),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _imageUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                      labelText: s.t('image_url'),
                      errorText: _imageError,
                      border: const OutlineInputBorder()),
                  onSubmitted: (_) => _addImage(s),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: s.t('add_image'),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: () => _addImage(s),
              ),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(s.t('save')),
              onPressed: _saving || s.categories.isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
