import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/app_models.dart';
import '../../../core/widgets/app_ui.dart';

class ProductAddOrigin {
  const ProductAddOrigin({this.imageKey, this.addButtonKey});
  final GlobalKey? imageKey;
  final GlobalKey? addButtonKey;
}

class ProductCartAnimation {
  final targets = <GlobalKey>[];
  final thumbnails = <GlobalKey, Map<String, GlobalKey>>{};
  final arrivals = ValueNotifier<String?>(null);
  String? latestProduct;
  final _entries = <OverlayEntry>[];
  int _serial = 0;
  int _generation = 0;
  bool _disposed = false;
  @visibleForTesting
  int get activeFlightCount => _entries.length;
  Rect? rect(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  void celebrateAdd({
    required BuildContext context,
    required CatalogItem item,
    required int unitsAdded,
    required int cartCountAfter,
    bool isIncrement = false,
    ProductAddOrigin? origin,
  }) {
    if (unitsAdded <= 0) return;
    latestProduct = '${item.type.name}:${item.storeId}:${item.id}';
    if (MediaQuery.disableAnimationsOf(context)) return;
    final source = rect(origin?.imageKey);
    final generation = _generation;
    final route = ModalRoute.of(context);
    // Wait for the first nonempty cart bar to be laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed ||
          generation != _generation ||
          !context.mounted ||
          route?.isCurrent == false ||
          source == null) {
        return;
      }
      final active = targets.reversed
          .where(
            (key) =>
                key.currentContext != null &&
                ModalRoute.of(key.currentContext!)?.isCurrent != false,
          )
          .firstOrNull;
      final productKey = '${item.type.name}:${item.storeId}:${item.id}';
      final destination = [
        thumbnails[active]?[productKey],
        active,
      ].map(rect).whereType<Rect>().firstOrNull;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (destination == null || overlay == null) return;
      final box = overlay.context.findRenderObject() as RenderBox;
      final start = box.globalToLocal(source.topLeft) & source.size;
      final end = box.globalToLocal(destination.topLeft) & const Size(38, 38);
      while (_entries.length >= 6) {
        _remove(_entries.first);
      }
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _ProductFlight(
          start: start,
          end: end,
          item: item,
          valid: () => context.mounted && route?.isCurrent != false,
          done: (arrived) {
            _remove(entry);
            if (arrived) {
              arrivals.value =
                  '${item.type.name}:${item.storeId}:${item.id}:${_serial++}';
            }
          },
        ),
      );
      _entries.add(entry);
      overlay.insert(entry);
    });
  }

  void _remove(OverlayEntry entry) {
    if (!_entries.remove(entry)) return;
    entry.remove();
    entry.dispose();
  }

  void clear() {
    _generation++;
    for (final entry in _entries.toList()) {
      _remove(entry);
    }
  }

  void dispose() {
    _disposed = true;
    clear();
    arrivals.dispose();
  }
}

final productCartAnimationProvider = Provider<ProductCartAnimation>((ref) {
  final controller = ProductCartAnimation();
  ref.onDispose(controller.dispose);
  return controller;
});

class _ProductFlight extends StatefulWidget {
  const _ProductFlight({
    required this.start,
    required this.end,
    required this.item,
    required this.valid,
    required this.done,
  });
  final Rect start, end;
  final CatalogItem item;
  final bool Function() valid;
  final void Function(bool) done;
  @override
  State<_ProductFlight> createState() => _ProductFlightState();
}

class _ProductFlightState extends State<_ProductFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    _animation =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 600),
          )
          ..addListener(() {
            if (!_finished && (!widget.valid() || _animation.isCompleted)) {
              _finished = true;
              widget.done(widget.valid());
            }
          })
          ..forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (_, _) {
      final t = Curves.easeInOutCubic.transform(_animation.value);
      final rect = Rect.lerp(
        widget.start,
        widget.end,
        t,
      )!.translate(0, -48 * math.sin(math.pi * t));
      return Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: AppNetworkImage(
              url: widget.item.imageUrl,
              width: rect.width,
              height: rect.height,
              borderRadius: 12 + t * 20,
            ),
          ),
        ),
      );
    },
  );
}
