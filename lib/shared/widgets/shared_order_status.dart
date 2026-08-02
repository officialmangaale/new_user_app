import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

enum SharedOrderUiStatus {
  available,
  nearlyFull,
  full,
  expired,
  joined,
  left,
  milestoneUnlocked,
  waiting,
  paymentPending,
  confirmed,
  failed,
  refundInitiated,
  refundComplete,
}

class SharedOrderStatusBanner extends StatelessWidget {
  const SharedOrderStatusBanner({required this.status, super.key});

  final SharedOrderUiStatus status;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(status);
    return Semantics(
      liveRegion: true,
      label: '${presentation.title}. ${presentation.message}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: presentation.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: presentation.foreground.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(presentation.icon, color: presentation.foreground, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: presentation.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    presentation.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusPresentation _presentation(SharedOrderUiStatus status) {
    return switch (status) {
      SharedOrderUiStatus.available => const _StatusPresentation(
        'Group available',
        'Join now to unlock the next savings milestone.',
        Icons.group_add_outlined,
        AppColors.primaryDark,
        AppColors.primaryVeryLight,
      ),
      SharedOrderUiStatus.nearlyFull => const _StatusPresentation(
        'Nearly full',
        'Only one place remains in this group.',
        Icons.groups_2_outlined,
        AppColors.warning,
        AppColors.warningLight,
      ),
      SharedOrderUiStatus.full => const _StatusPresentation(
        'Group full',
        'This group has reached its participant limit.',
        Icons.group_off_outlined,
        AppColors.textSecondary,
        AppColors.background,
      ),
      SharedOrderUiStatus.expired => const _StatusPresentation(
        'Group expired',
        'The joining window has closed. Find another nearby group.',
        Icons.timer_off_outlined,
        AppColors.error,
        AppColors.errorLight,
      ),
      SharedOrderUiStatus.joined => const _StatusPresentation(
        'You joined the group',
        'Your place is reserved while payment is completed.',
        Icons.check_circle_outline_rounded,
        AppColors.success,
        AppColors.successLight,
      ),
      SharedOrderUiStatus.left => const _StatusPresentation(
        'You left the group',
        'Your place is available for another nearby user.',
        Icons.logout_rounded,
        AppColors.textSecondary,
        AppColors.background,
      ),
      SharedOrderUiStatus.milestoneUnlocked => const _StatusPresentation(
        'New discount unlocked',
        'Everyone in the group now saves more.',
        Icons.savings_outlined,
        AppColors.success,
        AppColors.successLight,
      ),
      SharedOrderUiStatus.waiting => const _StatusPresentation(
        'Waiting for participants',
        'We will notify you as soon as the group is ready.',
        Icons.hourglass_top_rounded,
        AppColors.warning,
        AppColors.warningLight,
      ),
      SharedOrderUiStatus.paymentPending => const _StatusPresentation(
        'Payment pending',
        'Complete payment to confirm your place in the group.',
        Icons.account_balance_wallet_outlined,
        AppColors.warning,
        AppColors.warningLight,
      ),
      SharedOrderUiStatus.confirmed => const _StatusPresentation(
        'Order confirmed',
        'The store has received your order and tracking will begin soon.',
        Icons.verified_outlined,
        AppColors.success,
        AppColors.successLight,
      ),
      SharedOrderUiStatus.failed => const _StatusPresentation(
        'Group did not complete',
        'The minimum participant count was not reached in time.',
        Icons.error_outline_rounded,
        AppColors.error,
        AppColors.errorLight,
      ),
      SharedOrderUiStatus.refundInitiated => const _StatusPresentation(
        'Automatic refund started',
        'Your payment is being returned to the original method.',
        Icons.sync_rounded,
        AppColors.primaryDark,
        AppColors.primaryVeryLight,
      ),
      SharedOrderUiStatus.refundComplete => const _StatusPresentation(
        'Refund complete',
        'The payment provider has completed your refund.',
        Icons.price_check_rounded,
        AppColors.success,
        AppColors.successLight,
      ),
    };
  }
}

class _StatusPresentation {
  const _StatusPresentation(
    this.title,
    this.message,
    this.icon,
    this.foreground,
    this.background,
  );

  final String title;
  final String message;
  final IconData icon;
  final Color foreground;
  final Color background;
}
