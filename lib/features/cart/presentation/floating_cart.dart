import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../shared/models/app_models.dart';
import '../providers/cart_controller.dart';
import 'cart_screens.dart';
import 'product_cart_animation.dart';

/// Reserves space for cart chrome instead of covering the browsing content.
class CartDock extends ConsumerWidget {
  const CartDock({this.child, super.key});
  final Widget? child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ref.watch(cartCountProvider) > 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: FloatingCartBar(),
          ),
        ?child,
      ],
    ),
  );
}

class FloatingCartBar extends ConsumerStatefulWidget {
  const FloatingCartBar({super.key});
  @override
  ConsumerState<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends ConsumerState<FloatingCartBar>
    with SingleTickerProviderStateMixin {
  final _barKey = GlobalKey();
  final _photosKey = GlobalKey();
  final _thumbnailKeys = <String, GlobalKey>{};
  late final ProductCartAnimation _flights;
  late final AnimationController _bounce;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _flights = ref.read(productCartAnimationProvider);
    _flights.targets.add(_photosKey);
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _flights.arrivals.addListener(_arrived);
  }

  void _arrived() {
    if (mounted && !MediaQuery.disableAnimationsOf(context)) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flights.targets.remove(_photosKey);
    _flights.thumbnails.remove(_photosKey);
    _flights.arrivals.removeListener(_arrived);
    _flights.clear();
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    final start = _flights.rect(_barKey);
    if (start == null) return;
    _opening = true;
    _flights.clear();
    final reduced = MediaQuery.disableAnimationsOf(context);
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Close cart',
        barrierColor: Colors.black38,
        transitionDuration: Duration(milliseconds: reduced ? 0 : 360),
        reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _CartPanel(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final media = MediaQuery.of(context);
          final end = Rect.fromLTRB(
            12,
            media.padding.top + 24,
            media.size.width - 12,
            media.size.height - media.padding.bottom - 12,
          );
          final t = Curves.easeInOutCubic.transform(animation.value);
          final bounds = Rect.lerp(start, end, t)!;
          return Stack(
            children: [
              Positioned.fromRect(
                rect: bounds,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: end.width,
                    maxWidth: end.width,
                    minHeight: end.height,
                    maxHeight: end.height,
                    child: ColoredBox(
                      color: AppColors.primary,
                      child: Opacity(opacity: t, child: child),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartLinesProvider);
    final count = ref.watch(cartCountProvider);
    final total = ref.watch(cartTotalProvider);
    final distinct = <String, CatalogItem>{};
    for (final line in lines) {
      distinct['${line.item.type.name}:${line.item.storeId}:${line.item.id}'] =
          line.item;
    }
    final ordered = distinct.entries.toList();
    final latest = ordered
        .where((entry) => entry.key == _flights.latestProduct)
        .firstOrNull;
    if (latest != null) {
      ordered.remove(latest);
      ordered.insert(0, latest);
    }
    final items = ordered.take(3).toList();
    for (final item in items) {
      _thumbnailKeys.putIfAbsent(item.key, GlobalKey.new);
    }
    _thumbnailKeys.removeWhere(
      (key, _) => !items.any((item) => item.key == key),
    );
    _flights.thumbnails[_photosKey] = _thumbnailKeys;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, _) {
          final pulse = math.sin(math.pi * _bounce.value);
          return Transform.scale(
            scale: 1 + .025 * pulse,
            child: Material(
              key: _barKey,
              color: AppColors.primary,
              elevation: 7,
              shadowColor: AppColors.shadow,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                enableFeedback: false,
                onTap: _open,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        key: _photosKey,
                        width: 38 + math.max(0, items.length - 1) * 24.0,
                        height: 38,
                        child: Stack(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Positioned(
                                left: i * 24.0,
                                top: 0,
                                child: Container(
                                  key: _thumbnailKeys[items[i].key],
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        (_flights.arrivals.value?.startsWith(
                                                  '${items[i].key}:',
                                                ) ??
                                                false) &&
                                            pulse > .1
                                        ? Colors.amber.shade200
                                        : Colors.white,
                                  ),
                                  child: AppNetworkImage(
                                    url: items[i].value.imageUrl,
                                    width: 34,
                                    height: 34,
                                    borderRadius: 99,
                                    semanticLabel: items[i].value.name,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (distinct.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Text(
                            '+${distinct.length - 3}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'View cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$count ${count == 1 ? 'item' : 'items'} · ₹$total',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(cartCountProvider, (previous, next) {
      if (next == 0 &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    });
    return CartScreen(onClose: () => Navigator.of(context).pop());
  }
}
