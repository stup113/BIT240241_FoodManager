import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/errors.dart';
import '../models/dish_category.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Quản lý loại món (DishCategory): thêm / sửa / xóa.
/// Không cho xóa loại đang có món sử dụng (kiểm tra ở Repo.deleteCategory).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _delete(BuildContext context, DishCategory c) async {
    final s = context.read<AppState>();
    final ok = await confirmDialog(context,
        message: s.t('confirm_delete_category', {'name': c.name}));
    if (!ok) return;
    try {
      await s.deleteCategory(c.id!);
      if (context.mounted) showSnack(context, s.t('deleted'));
    } catch (e) {
      if (context.mounted) showSnack(context, s.msg(e)); // vd: đang được sử dụng
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('manage_categories'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(s.t('add_category')),
        onPressed: () => showDialog<void>(
            context: context, builder: (_) => const _CategoryDialog()),
      ),
      body: Column(children: [
        const StatusBanner(),
        Expanded(
          child: s.categories.isEmpty
              ? Center(child: Text(s.t('no_categories')))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: s.categories.length,
                  separatorBuilder: (_, i) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = s.categories[i];
                    return ListTile(
                      title: Text(c.name),
                      subtitle: c.description.isEmpty ? null : Text(c.description),
                      leading: c.syncStatus != 0
                          ? const Icon(Icons.cloud_upload_outlined,
                              color: Colors.orange)
                          : const Icon(Icons.category_outlined),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: s.t('edit'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => _CategoryDialog(category: c)),
                        ),
                        IconButton(
                          tooltip: s.t('delete'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, c),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final DishCategory? category;
  const _CategoryDialog({this.category});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.category?.name ?? '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.category?.description ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = s.t('err_name_required'));
      return;
    }
    setState(() => _saving = true);
    try {
      await s.saveCategory(DishCategory(
        id: widget.category?.id,
        name: _name.text,
        description: _desc.text,
      ));
      if (!mounted) return;
      showSnack(context, s.t('saved'));
      Navigator.pop(context);
    } on ValidationException catch (e) {
      setState(() {
        _error = s.t(e.errors.values.first);
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, s.msg(e));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return AlertDialog(
      title: Text(s.t(widget.category == null ? 'add_category' : 'edit_category')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _name,
          autofocus: true,
          decoration:
              InputDecoration(labelText: s.t('name'), errorText: _error),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        TextField(
          controller: _desc,
          decoration: InputDecoration(labelText: s.t('description')),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(s.t('cancel'))),
        FilledButton(
            onPressed: _saving ? null : _save, child: Text(s.t('save'))),
      ],
    );
  }
}
