import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../shared/mock_data/mock_data.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = MockData.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Mark all read')),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'All quiet for now',
              message:
                  'Order updates, group invites and rewards will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final item = items[index];
                final icon = switch (item.kind) {
                  'rider' => Icons.delivery_dining_rounded,
                  'discount' => Icons.local_offer_rounded,
                  'wallet' => Icons.account_balance_wallet_rounded,
                  'group' => Icons.people_alt_rounded,
                  _ => Icons.campaign_rounded,
                };
                return Card(
                  color: item.unread ? AppColors.light : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: item.unread
                          ? AppColors.primary
                          : const Color(0xFFF1F3F4),
                      child: Icon(
                        icon,
                        color: item.unread
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          item.time,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(item.body),
                    ),
                    trailing: item.unread
                        ? const CircleAvatar(
                            radius: 4,
                            backgroundColor: AppColors.primary,
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
