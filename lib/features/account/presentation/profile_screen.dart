import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../app_state/providers/app_controller.dart';
import '../../authentication/presentation/auth_screens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authenticated = ref.watch(
      appControllerProvider.select((state) => state.authenticated),
    );
    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        embedded ? 12 : 4,
        AppSpacing.screenPadding,
        embedded ? AppSpacing.navigationClearance + 76 : 24,
      ),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        _ProfileHero(
          authenticated: authenticated,
          onSignIn: () => context.push('/login?returnTo=/home'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (authenticated) const _ProfileStats(),
        if (authenticated) const SizedBox(height: AppSpacing.lg),
        _MenuSection(
          title: 'Orders & savings',
          entries: [
            _MenuEntry(
              Icons.receipt_long_outlined,
              'My Orders',
              route: '/orders',
              protected: true,
            ),
            _MenuEntry(
              Icons.delivery_dining_outlined,
              'Active Orders',
              route: '/tracking/TQ240761',
              protected: true,
            ),
            _MenuEntry(
              Icons.account_balance_wallet_outlined,
              'Wallet',
              route: '/wallet',
              protected: true,
              trailing: '₹1,284',
            ),
            _MenuEntry(
              Icons.redeem_outlined,
              'Referral and Earn',
              route: '/referral',
              protected: true,
              trailing: '₹386 earned',
            ),
            _MenuEntry(
              Icons.savings_outlined,
              'Total Shared Savings',
              route: '/info/Total Shared Savings',
              trailing: '₹2,840',
            ),
          ],
          authenticated: authenticated,
        ),
        _MenuSection(
          title: 'Your account',
          entries: [
            _MenuEntry(
              Icons.location_on_outlined,
              'Saved Addresses',
              route: '/info/Saved Addresses',
            ),
            _MenuEntry(
              Icons.credit_card_outlined,
              'Payment Methods',
              route: '/info/Payment Methods',
            ),
            _MenuEntry(
              Icons.favorite_border_rounded,
              'Favourite Restaurants',
              route: '/info/Favourite Restaurants',
            ),
            _MenuEntry(
              Icons.bookmark_border_rounded,
              'Saved Grocery Items',
              route: '/info/Saved Grocery Items',
            ),
            _MenuEntry(
              Icons.notifications_none_rounded,
              'Notifications',
              route: '/notifications',
            ),
          ],
          authenticated: authenticated,
        ),
        _MenuSection(
          title: 'Shared orders',
          entries: [
            _MenuEntry(
              Icons.groups_outlined,
              'My FoodShare Groups',
              route: '/info/My FoodShare Groups',
              protected: true,
            ),
            _MenuEntry(
              Icons.shopping_basket_outlined,
              'My Share Baskets',
              route: '/info/My Share Baskets',
              protected: true,
            ),
            _MenuEntry(
              Icons.history_rounded,
              'Shared Order History',
              route: '/orders',
              protected: true,
            ),
          ],
          authenticated: authenticated,
        ),
        _MenuSection(
          title: 'Help & preferences',
          entries: [
            _MenuEntry(
              Icons.help_outline_rounded,
              'Help and Support',
              route: '/info/Help and Support',
            ),
            _MenuEntry(
              Icons.chat_bubble_outline_rounded,
              'Chat with Support',
              route: '/info/Chat with Support',
            ),
            _MenuEntry(
              Icons.report_problem_outlined,
              'Report an Issue',
              route: '/info/Report an Issue',
            ),
            _MenuEntry(
              Icons.language_rounded,
              'Language',
              route: '/info/Language',
              trailing: 'English',
            ),
            _MenuEntry(
              Icons.tune_rounded,
              'Notification Settings',
              route: '/info/Notification Settings',
            ),
            _MenuEntry(
              Icons.privacy_tip_outlined,
              'Privacy Settings',
              route: '/info/Privacy Settings',
            ),
          ],
          authenticated: authenticated,
        ),
        _MenuSection(
          title: 'About',
          entries: [
            _MenuEntry(
              Icons.description_outlined,
              'Terms and Conditions',
              route: '/info/Terms and Conditions',
            ),
            _MenuEntry(
              Icons.policy_outlined,
              'Privacy Policy',
              route: '/info/Privacy Policy',
            ),
            _MenuEntry(
              Icons.currency_rupee_rounded,
              'Refund and Cancellation Policy',
              route: '/info/Refund and Cancellation Policy',
            ),
            _MenuEntry(
              Icons.info_outline_rounded,
              'About Us',
              route: '/info/About Us',
            ),
            _MenuEntry(
              Icons.star_border_rounded,
              'Rate the App',
              route: '/info/Rate the App',
            ),
          ],
          authenticated: authenticated,
        ),
        if (authenticated)
          TextButton.icon(
            onPressed: () async {
              await ref.read(appControllerProvider.notifier).logout();
              if (context.mounted) context.go('/welcome');
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
    if (embedded) return SafeArea(bottom: false, child: content);
    return Scaffold(body: SafeArea(child: content));
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.authenticated, required this.onSignIn});

  final bool authenticated;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.light,
            child: Text(
              authenticated ? 'A' : 'G',
              style: const TextStyle(
                fontSize: 27,
                color: AppColors.dark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authenticated ? 'Aarav Mehta' : 'Welcome, guest',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  authenticated
                      ? '+91 ••••• 43210'
                      : 'Sign in to access orders and rewards',
                  style: const TextStyle(
                    color: Color(0xFFBCECE5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                if (authenticated)
                  InkWell(
                    onTap: () {},
                    child: const Text(
                      'Edit profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: onSignIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.dark,
                        minimumSize: const Size(90, 34),
                      ),
                      child: const Text('Sign in'),
                    ),
                  ),
              ],
            ),
          ),
          if (authenticated)
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: const [
            Expanded(
              child: _Stat(label: 'Wallet', value: '₹1,284'),
            ),
            SizedBox(height: 38, child: VerticalDivider()),
            Expanded(
              child: _Stat(label: 'Referral', value: '₹386'),
            ),
            SizedBox(height: 38, child: VerticalDivider()),
            Expanded(
              child: _Stat(label: 'Points', value: '2,450'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _MenuEntry {
  const _MenuEntry(
    this.icon,
    this.label, {
    required this.route,
    this.protected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String route;
  final bool protected;
  final String? trailing;
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.title,
    required this.entries,
    required this.authenticated,
  });

  final String title;
  final List<_MenuEntry> entries;
  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Card(
            child: Column(
              children: List.generate(entries.length, (index) {
                final entry = entries[index];
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.light,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          entry.icon,
                          size: 20,
                          color: AppColors.dark,
                        ),
                      ),
                      title: Text(
                        entry.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (entry.trailing != null)
                            Text(
                              entry.trailing!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      onTap: () {
                        if (entry.protected && !authenticated) {
                          ProtectedActionSheet.show(context, entry.route);
                        } else {
                          context.push(entry.route);
                        }
                      },
                    ),
                    if (index < entries.length - 1)
                      const Divider(height: 1, indent: 66),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class InformationScreen extends StatelessWidget {
  const InformationScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final content = switch (title) {
      'Help and Support' => (
        'How can we help?',
        'Browse common questions about orders, payments, shared groups and refunds. Our support team is available every day.',
      ),
      'Chat with Support' => (
        'Start a conversation',
        'Average response time is under 2 minutes. A support specialist will have access only to the order information you choose to share.',
      ),
      'Privacy Policy' => (
        'Your privacy matters',
        'We use only the information required to fulfil deliveries, secure payments and improve your experience. Shared-order participants never see private addresses.',
      ),
      'Terms and Conditions' => (
        'Clear, fair terms',
        'These demo terms explain eligibility, payments, group savings and account responsibilities. Production legal copy can be supplied through the content API.',
      ),
      'Refund and Cancellation Policy' => (
        'Refunds and cancellations',
        'Eligible refunds are returned to the original payment method. Cancelled or refunded orders do not earn referral rewards.',
      ),
      _ => (
        title,
        'This area is ready for its API-backed content. The complete navigation, states and production design system are already in place.',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: AppColors.light,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.dark,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              content.$1,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(content.$2),
            const SizedBox(height: 24),
            if (title.contains('Support') || title.contains('Issue'))
              AppButton(
                label: title == 'Chat with Support'
                    ? 'Start chat'
                    : 'Contact support',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Support conversation preview opened'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
