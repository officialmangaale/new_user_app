import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'menu_header.dart';

class _Block extends StatelessWidget {
  const _Block({this.width, required this.height, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Full-screen placeholder shown while the restaurant record loads: header,
/// info card, chips and dish rows. Static, so it never keeps the frame
/// scheduler busy.
class MenuSkeleton extends StatelessWidget {
  const MenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).top;
    return Semantics(
      label: 'Loading menu',
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: kMenuBannerHeight + inset,
                    color: AppColors.ink,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      kMenuBannerHeight + inset - 28,
                      16,
                      0,
                    ),
                    child: Container(
                      height: 132,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Block(width: 88, height: 88, radius: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Block(height: 24),
                                SizedBox(height: 10),
                                _Block(width: 140, height: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: _Block(height: 48, radius: 14)),
                    SizedBox(width: 10),
                    _Block(width: 92, height: 48, radius: 14),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    _Block(width: 84, height: 40, radius: 20),
                    SizedBox(width: 8),
                    _Block(width: 96, height: 40, radius: 20),
                    SizedBox(width: 8),
                    _Block(width: 72, height: 40, radius: 20),
                  ],
                ),
              ),
              const MenuRowsSkeleton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A few dish-row placeholders; also used while only the menu is loading.
class MenuRowsSkeleton extends StatelessWidget {
  const MenuRowsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Block(width: 16, height: 16, radius: 4),
                      SizedBox(height: 8),
                      _Block(height: 18),
                      SizedBox(height: 8),
                      _Block(width: 60, height: 14),
                      SizedBox(height: 10),
                      _Block(height: 12),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                _Block(width: 124, height: 124, radius: 16),
              ],
            ),
          ),
      ],
    );
  }
}
