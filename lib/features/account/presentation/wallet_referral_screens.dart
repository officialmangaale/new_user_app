import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/engagement_repository.dart';
import '../providers/engagement_providers.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: AsyncView<WalletStatement>(
        value: ref.watch(walletProvider),
        onRetry: () => ref.invalidate(walletProvider),
        builder: (wallet) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Color(0xFFBCECE5),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${wallet.balance.toStringAsFixed(0)}',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _walletButton(
                          Icons.add_rounded,
                          'Add Money',
                          () => _amountSheet(context, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _walletButton(
                          Icons.arrow_outward_rounded,
                          'Withdraw',
                          () => _amountSheet(context, true),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0x3355E1D1), height: 30),
                  // Derived from the ledger the backend returned — the API
                  // does not send a pre-aggregated breakdown, so nothing here
                  // is invented.
                  Row(
                    children: [
                      Expanded(
                        child: _WalletStat(
                          label: 'Cashback',
                          value: '₹${_sumMatching(wallet, 'cashback')}',
                        ),
                      ),
                      Expanded(
                        child: _WalletStat(
                          label: 'Referrals',
                          value: '₹${_sumMatching(wallet, 'referral')}',
                        ),
                      ),
                      Expanded(
                        child: _WalletStat(
                          label: 'Total earned',
                          value: '₹${_sumCredits(wallet)}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'All transactions'),
              Tab(text: 'Cashback'),
              Tab(text: 'Referral rewards'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TransactionList(items: wallet.transactions),
                _TransactionList(
                  items: wallet.transactions
                      .where(
                        (item) => item.title.toLowerCase().contains('cashback'),
                      )
                      .toList(),
                ),
                _TransactionList(
                  items: wallet.transactions
                      .where(
                        (item) => item.title.toLowerCase().contains('referral'),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  int _sumMatching(WalletStatement wallet, String keyword) => wallet.transactions
      .where((item) => item.title.toLowerCase().contains(keyword))
      .fold(0, (sum, item) => sum + item.amount);

  int _sumCredits(WalletStatement wallet) => wallet.transactions
      .where((item) => item.amount > 0)
      .fold(0, (sum, item) => sum + item.amount);

  Widget _walletButton(IconData icon, String label, VoidCallback onTap) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.dark,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  void _amountSheet(BuildContext context, bool withdraw) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              withdraw ? 'Withdraw money' : 'Add money',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              withdraw
                  ? 'Transfer your eligible wallet balance to a verified bank account.'
                  : 'Add securely using UPI, card or net banking.',
            ),
            const SizedBox(height: 18),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                labelText: 'Amount',
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: withdraw ? 'Continue to bank' : 'Continue to payment',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      withdraw
                          ? 'Withdrawal flow preview opened'
                          : 'Add-money flow preview opened',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(color: Color(0xFFBCECE5), fontSize: 10),
      ),
    ],
  );
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.items});
  final List<WalletTransaction> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No transactions yet',
        message: 'Wallet activity will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(indent: 52),
      itemBuilder: (_, index) =>
          WalletTransactionTile(transaction: items[index]),
    );
  }
}

class WalletTransactionTile extends StatelessWidget {
  const WalletTransactionTile({required this.transaction, super.key});
  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.amount > 0;
    final icon = switch (transaction.iconName) {
      'cashback' => Icons.savings_outlined,
      'referral' => Icons.redeem_outlined,
      'add' => Icons.add_card_rounded,
      _ => Icons.shopping_bag_outlined,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.light,
        child: Icon(icon, color: AppColors.dark),
      ),
      title: Text(
        transaction.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(transaction.date),
      trailing: Text(
        '${positive ? '+' : '−'}₹${transaction.amount.abs()}',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: positive ? AppColors.success : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(referralSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Refer and Earn')),
      body: AsyncView<ReferralSummary>(
        value: summary,
        onRetry: () => ref.invalidate(referralSummaryProvider),
        builder: (referral) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Earn ₹1 for a lifetime',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Earn ₹1 every time your referred friend completes an eligible order—for a lifetime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFD2F4EF), height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(15, 10, 7, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR CODE',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              referral.code,
                              style: const TextStyle(
                                fontSize: 19,
                                color: AppColors.dark,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: referral.code),
                          );
                          if (context.mounted) {
                            _toast(context, 'Referral code copied');
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => _toast(context, 'Share preview opened'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'WhatsApp',
                  outlined: true,
                  icon: Icons.chat_rounded,
                  onPressed: () => _toast(context, 'WhatsApp preview opened'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const ReferralSummaryCard(),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your earning potential',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Refer 100 active users.\nIf every user places 5 orders per month,\nyou can earn ₹500 per month.',
                  style: TextStyle(
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Recent referral earnings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final person in const [
            ('Riya S.', 'Today • Completed order', '+₹1'),
            ('Ayaan K.', '11 Jul • Completed order', '+₹1'),
            ('Meera P.', '9 Jul • Completed order', '+₹1'),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.light,
                child: Text(
                  person.$1[0],
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(
                person.$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(person.$2),
              trailing: Text(
                person.$3,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('How it works', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const _Rule(text: 'Only successfully completed orders qualify.'),
          const _Rule(text: 'Cancelled or refunded orders do not qualify.'),
          const _Rule(text: 'The ₹1 reward is added after order completion.'),
          const _Rule(text: 'You continue earning on future eligible orders.'),
        ],
        ),
      ),
    );
  }

  static void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class ReferralSummaryCard extends StatelessWidget {
  const ReferralSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            const Row(
              children: [
                Expanded(
                  child: _ReferralStat(label: 'People referred', value: '142'),
                ),
                Expanded(
                  child: _ReferralStat(label: 'Active users', value: '96'),
                ),
              ],
            ),
            const Divider(height: 28),
            const Row(
              children: [
                Expanded(
                  child: _ReferralStat(label: 'Total earnings', value: '₹386'),
                ),
                Expanded(
                  child: _ReferralStat(label: 'This month', value: '₹74'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralStat extends StatelessWidget {
  const _ReferralStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: AppColors.dark),
      ),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.primary,
          size: 19,
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
