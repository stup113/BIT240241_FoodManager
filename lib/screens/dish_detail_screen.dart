import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../state/app_state.dart';
import '../utils.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import 'dish_form_screen.dart';

class DishDetailScreen extends StatefulWidget {
  final int dishId;
  const DishDetailScreen({super.key, required this.dishId});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  Dish? _dish;
  bool _loading = true;
  bool _notFound = false;
  int _page = 0;
  final PageController _pc = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    final d = await repo.getDish(widget.dishId);
    if (!mounted) return;
    setState(() {
      _dish = d;
      _notFound = d == null; // Id không tồn tại (hoặc đã bị xóa)
      _loading = false;
      if (d != null && _page >= d.images.length) {
        _page = d.images.isEmpty ? 0 : d.images.length - 1;
      }
    });
  }

  Future<void> _addImage() async {
    final s = context.read<AppState>();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _AddImageDialog(),
    );
    if (url == null || _dish == null) return;
    try {
      await s.updateImages(_dish!.id!, [
        ..._dish!.images,
        DishImage(imageUrl: url.trim()),
      ]);
      await _load();
      if (mounted) {
        _pc.jumpToPage(_dish!.images.length - 1);
        setState(() => _page = _dish!.images.length - 1);
      }
    } catch (e) {
      if (mounted) showSnack(context, s.msg(e));
    }
  }

  Future<void> _setThumbnail() async {
    final s = context.read<AppState>();
    final d = _dish!;
    try {
      await s.updateImages(d.id!, [
        for (var i = 0; i < d.images.length; i++)
          d.images[i].copyWith(isThumbnail: i == _page),
      ]);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, s.msg(e));
    }
  }

  Future<void> _deleteImage() async {
    final s = context.read<AppState>();
    final d = _dish!;
    final ok = await confirmDialog(context, message: s.t('confirm_delete_image'));
    if (!ok) return;
    try {
      await s.updateImages(d.id!, [
        for (var i = 0; i < d.images.length; i++)
          if (i != _page) d.images[i],
      ]);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, s.msg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: Text(s.t('dish_detail'))),
          body: const Center(child: CircularProgressIndicator()));
    }
    final d = _dish;
    if (_notFound || d == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('dish_detail'))),
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

    final catName = s.categories
        .where((c) => c.id == d.dishCategoryId)
        .map((c) => c.name)
        .firstOrNull;
    final hasImages = d.images.isNotEmpty;
    final index = hasImages && _page >= d.images.length
        ? d.images.length - 1
        : _page;
    final current = hasImages ? d.images[index] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: s.t('edit'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DishFormScreen(dishId: d.id)));
              if (mounted) _load();
            },
          ),
          IconButton(
            tooltip: s.t('delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final deleted = await deleteDishWithConfirm(context, d);
              if (deleted && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // ---- ảnh
          if (!hasImages)
            Container(
              height: 200,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.image_not_supported_outlined, size: 48),
                const SizedBox(height: 8),
                Text(s.t('no_images')),
              ]),
            )
          else
            SizedBox(
              height: 240,
              child: Stack(children: [
                PageView.builder(
                  controller: _pc,
                  itemCount: d.images.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
                    NetImage(url: d.images[i].imageUrl),
                    if (d.images[i].isThumbnail)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Chip(
                          avatar: const Icon(Icons.star,
                              size: 16, color: Colors.amber),
                          label: Text(s.t('thumbnail')),
                        ),
                      ),
                  ]),
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < d.images.length; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page ? Colors.white : Colors.white54,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(s.t('add_image')),
                onPressed: _addImage,
              ),
              if (hasImages)
                OutlinedButton.icon(
                  icon: const Icon(Icons.star_outline),
                  label: Text(s.t('set_thumbnail')),
                  onPressed: current!.isThumbnail ? null : _setThumbnail,
                ),
              if (hasImages)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(s.t('delete_image')),
                  onPressed: _deleteImage,
                ),
            ]),
          ),
          // ---- thông tin
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Row(children: [
                Text(formatPrice(d.price),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                AvailabilityBadge(available: d.isAvailable),
              ]),
              const SizedBox(height: 8),
              PrepTimeChip(dish: d),
              const Divider(height: 32),
              _info(context, s.t('category'), catName ?? '-'),
              _info(context, s.t('prep_time'),
                  '${d.preparationTime} ${s.t('minutes_unit')}'),
              const SizedBox(height: 8),
              Text(s.t('description'),
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(d.description.isEmpty ? s.t('no_description') : d.description),
              if (d.syncStatus != 0) ...[
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.cloud_upload_outlined,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(s.t('pending_icon_tip')),
                ]),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 170,
              child: Text(label,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          Expanded(child: Text(value)),
        ]),
      );
}

class _AddImageDialog extends StatefulWidget {
  const _AddImageDialog();

  @override
  State<_AddImageDialog> createState() => _AddImageDialogState();
}

class _AddImageDialogState extends State<_AddImageDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return AlertDialog(
      title: Text(s.t('add_image')),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration:
            InputDecoration(labelText: s.t('image_url'), errorText: _error),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: () {
            if (!isHttpUrl(_ctrl.text)) {
              setState(() => _error = s.t('err_image_url'));
              return;
            }
            Navigator.pop(context, _ctrl.text.trim());
          },
          child: Text(s.t('add')),
        ),
      ],
    );
  }
}
