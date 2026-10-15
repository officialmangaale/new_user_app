import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'veg_mark.dart';

/// 48px "Search dishes" field that filters the menu live.
class MenuSearchBar extends StatelessWidget {
  const MenuSearchBar({
    required this.controller,
    required this.onChanged,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
        cursorColor: AppColors.deepTeal,
        decoration: InputDecoration(
          hintText: 'Search dishes',
          hintStyle: const TextStyle(color: AppColors.inkSecondary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 22,
            color: AppColors.inkSecondary,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.inkSecondary,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: _border(AppColors.hairline),
          focusedBorder: _border(AppColors.deepTeal, width: 1.5),
          border: _border(AppColors.hairline),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Labelled veg-only switch: veg mark, "Veg", and a visible switch.
class VegToggle extends StatelessWidget {
  const VegToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: 'Veg only',
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: Material(
        color: value ? AppColors.mint : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(!value),
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 10, right: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value ? AppColors.vegGreen : AppColors.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VegMark(isVeg: true),
                const SizedBox(width: 6),
                const Text(
                  'Veg',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: ExcludeSemantics(
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                      activeTrackColor: AppColors.vegGreen,
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: AppColors.hairline,
                      inactiveThumbColor: Colors.white,
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
