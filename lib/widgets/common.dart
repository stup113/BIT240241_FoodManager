import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/dish.dart';
import '../state/app_state.dart';

/// Ảnh từ URL, có placeholder khi không có ảnh hoặc ảnh lỗi.
class NetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const NetImage({super.key, this.url, this.width, this.height, this.fit = BoxFit.cover});

  Widget _placeholder(BuildContext context) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.restaurant,
            color: Theme.of(context).colorScheme.outline),
      );

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return _placeholder(context);
    return Image.network(
      u,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (c, e, s) => _placeholder(c),
      loadingBuilder: (c, child, progress) => progress == null
          ? child
          : SizedBox(
              width: width,
              height: height,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
    );
  }
}

/// Nhãn "Quick / Regular" suy ra từ PreparationTime (không lưu DB).
class PrepTimeChip extends StatelessWidget {
  final Dish dish;
  const PrepTimeChip({super.key, required this.dish});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final quick = dish.isQuick;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: quick ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(quick ? Icons.bolt : Icons.schedule, size: 14),
        const SizedBox(width: 4),
        Text(
          '${s.t(quick ? 'quick' : 'regular')} · ${dish.preparationTime} ${s.t('minutes_unit')}',
          style: const TextStyle(fontSize: 12),
        ),
      ]),
    );
  }
}

class AvailabilityBadge extends StatelessWidget {
  final bool available;
  const AvailabilityBadge({super.key, required this.available});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final color = available ? Colors.green : Colors.red;
    return Text(
      s.t(available ? 'available' : 'unavailable'),
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}

/// Banner trạng thái mạng / đồng bộ.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    Widget bar(Color bg, IconData icon, String text, {bool progress = false}) {
      return Material(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            if (progress)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ]),
        ),
      );
    }

    final pendingText = s.pending > 0
        ? s.t('pending_sync', {'n': '${s.pending}'})
        : '';

    if (!s.isOnline) {
      return bar(Colors.amber.shade200, Icons.cloud_off,
          '${s.t('offline_banner')}${pendingText.isEmpty ? '' : '\n$pendingText'}');
    }
    if (!kApiConfigured) {
      return bar(scheme.surfaceContainerHighest, Icons.info_outline,
          s.t('api_not_configured'));
    }
    if (s.syncing) {
      return bar(scheme.primaryContainer, Icons.sync, s.t('syncing'),
          progress: true);
    }
    if (s.syncError != null) {
      return bar(scheme.errorContainer, Icons.sync_problem,
          s.t('sync_error', {'msg': s.syncError!}));
    }
    if (s.pending > 0) {
      return bar(scheme.secondaryContainer, Icons.cloud_upload_outlined,
          pendingText);
    }
    return const SizedBox.shrink();
  }
}

Future<bool> confirmDialog(BuildContext context,
    {required String message}) async {
  final s = context.read<AppState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.t('confirm_delete_title')),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel'))),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('delete'))),
      ],
    ),
  );
  return ok == true;
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
