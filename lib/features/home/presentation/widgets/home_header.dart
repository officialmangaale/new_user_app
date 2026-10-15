import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/app_models.dart';

/// "Good morning, Asha" — device-time greeting; no name means no comma.
String greetingFor(DateTime now, String? name) {
  final hour = now.hour;
  final part = hour < 12
      ? 'Good morning'
      : hour < 17
      ? 'Good afternoon'
      : 'Good evening';
  final first = (name ?? '').trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? part : '$part, $first';
}

/// Mint header band: location, cart/account, service toggle, greeting, search.
class HomeHeaderBand extends StatelessWidget {
  const HomeHeaderBand({
    required this.mode,
    required this.primaryLocation,
    required this.secondaryLocation,
    required this.greeting,
    required this.cartCount,
    required this.accountInitial,
    required this.searchHint,
    required this.onLocationTap,
    required this.onCartTap,
    required this.onAccountTap,
    required this.onSearchTap,
    super.key,
  });

  final DeliveryMode mode;
  final String primaryLocation;
  final String secondaryLocation;
  final String greeting;
  final int cartCount;

  /// Empty when the customer's name is unknown.
  final String accountInitial;
  final String searchHint;
  final VoidCallback onLocationTap;
  final VoidCallback onCartTap;
  final VoidCallback onAccountTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final grocery = mode == DeliveryMode.grocery;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _LocationBlock(
                  primary: primaryLocation,
                  secondary: secondaryLocation,
                  onTap: onLocationTap,
                ),
              ),
              const SizedBox(width: 8),
              _CartButton(count: cartCount, onPressed: onCartTap),
              const SizedBox(width: 8),
              _AccountButton(initial: accountInitial, onPressed: onAccountTap),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              greeting,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            grocery
                ? 'What does your kitchen need today?'
                : 'What are you craving today?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 16),
          _SearchField(hint: searchHint, onTap: onSearchTap),
        ],
      ),
    );
  }
}

class _LocationBlock extends StatelessWidget {
  const _LocationBlock({
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  final String primary;
  final String secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Delivering to $primary${secondary.isEmpty ? '' : ', $secondary'}. '
          'Change location',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivering to',
                style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: AppColors.deepTeal,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.ink,
                  ),
                ],
              ),
              if (secondary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Cart, $count items' : 'Cart',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: const Color(0x330B2E2C),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 22,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.mint, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.initial, required this.onPressed});

  final String initial;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Account',
      excludeSemantics: true,
      child: Material(
        color: AppColors.ink,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: initial.isEmpty
                  ? const Icon(
                      Icons.person_outline_rounded,
                      size: 22,
                      color: AppColors.primary,
                    )
                  : Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      textField: true,
      label: hint,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x260B2E2C),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.deepTeal,
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
