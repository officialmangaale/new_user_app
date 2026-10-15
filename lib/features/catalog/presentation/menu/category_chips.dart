import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

const double kCategoryChipsHeight = 56;

/// Horizontally scrolling category pills. The active chip is kept in view.
class CategoryChips extends StatefulWidget {
  const CategoryChips({
    required this.labels,
    required this.activeIndex,
    required this.onSelected,
    this.elevated = false,
    super.key,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  /// Adds the soft shadow shown while the strip is stuck under the top bar.
  final bool elevated;

  @override
  State<CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  final Map<int, GlobalKey> _keys = {};
  final ScrollController _controller = ScrollController();
  final GlobalKey _listKey = GlobalKey();

  GlobalKey _key(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Centres the active chip in the strip. Done by hand because
  /// `Scrollable.ensureVisible` would also scroll the menu page.
  void _revealActive() {
    final chip = _keys[widget.activeIndex]?.currentContext?.findRenderObject();
    final list = _listKey.currentContext?.findRenderObject();
    if (chip is! RenderBox || list is! RenderBox || !_controller.hasClients) {
      return;
    }
    if (!chip.attached || !list.attached) return;
    final left = chip.localToGlobal(Offset.zero, ancestor: list).dx;
    final target =
        _controller.offset + left - (list.size.width - chip.size.width) / 2;
    final position = _controller.position;
    final clamped = target.clamp(0.0, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(clamped);
    } else {
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didUpdateWidget(CategoryChips old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealActive();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kCategoryChipsHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: widget.elevated
            ? const [
                BoxShadow(
                  color: Color(0x1F0B2E2C),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ListView.separated(
        key: _listKey,
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: widget.labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = index == widget.activeIndex;
          return Semantics(
            button: true,
            selected: active,
            label: widget.labels[index],
            excludeSemantics: true,
            child: Material(
              key: _key(index),
              color: active ? AppColors.primary : AppColors.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: active ? AppColors.primary : AppColors.hairline,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => widget.onSelected(index),
                child: Container(
                  height: 40,
                  constraints: const BoxConstraints(minWidth: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: Text(
                    widget.labels[index],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: AppColors.ink,
                    ),
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
