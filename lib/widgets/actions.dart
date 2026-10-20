import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Hỏi xác nhận rồi xóa món. Trả về true nếu đã xóa.
Future<bool> deleteDishWithConfirm(BuildContext context, Dish dish) async {
  final s = context.read<AppState>();
  final ok = await confirmDialog(context,
      message: s.t('confirm_delete_dish', {'name': dish.name}));
  if (!ok || dish.id == null) return false;
  try {
    await s.deleteDish(dish.id!);
    if (context.mounted) showSnack(context, s.t('deleted'));
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, s.msg(e));
    return false;
  }
}
