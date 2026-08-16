import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/premium_components.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../../shared/widgets/shared_order_status.dart';
import '../../account/providers/engagement_providers.dart';
import '../../app_state/providers/app_controller.dart';
import '../../authentication/presentation/auth_screens.dart';

/// Placeholder rendered while a group request is in flight, so the layout has
/// something to lay out against without inventing plausible-looking numbers.
SharedGroup _emptyGroup(String groupId) => SharedGroup(
  id: groupId,
  title: '',
  subtitle: '',
  participants: 0,
  requiredParticipants: 0,
  distanceKm: 0,
  minutesLeft: 0,
  currentDiscount: 0,
  maximumDiscount: 0,
  deliveryDiscount: 0,
  savings: 0,
  imageUrl: '',
  mode: DeliveryMode.food,
);

Future<void> handleJoinGroup(
  BuildContext context,
  WidgetRef ref,
  SharedGroup group,
) async {
  final authenticated = ref.read(appControllerProvider).authenticated;
  if (!authenticated) {
    await ProtectedActionSheet.show(context, '/shared/${group.id}');
    return;
  }
  await HapticFeedback.mediumImpact();
  ref.read(appControllerProvider.notifier).joinGroup(group.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          group.mode == DeliveryMode.food
              ? 'You joined the FoodShare order'
              : 'You joined the Share Basket',
        ),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () => context.push('/waiting-room/${group.id}'),
        ),
      ),
    );
  }
}

class SharedOrderListingScreen extends ConsumerStatefulWidget {
  const SharedOrderListingScreen({
    required this.mode,
    this.embedded = false,
    super.key,
  });

  final DeliveryMode mode;
  final bool embedded;

  @override
  ConsumerState<SharedOrderListingScreen> createState() =>
      _SharedOrderListingScreenState();
}

class _SharedOrderListingScreenState
    extends ConsumerState<SharedOrderListingScreen> {
  String _filter = 'All nearby';

  @override
  Widget build(BuildContext context) {
    final food = widget.mode == DeliveryMode.food;
    // Server already filters by mode; the list renders empty while loading.
    final groups =
        ref.watch(sharedGroupsProvider(widget.mode)).value ??
        const <SharedGroup>[];
    final state = ref.watch(appControllerProvider);
    final body = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, widget.embedded ? 14 : 4, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food ? 'FoodShare' : 'Share Basket',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        food
                            ? 'Order together. Save together.'
                            : 'Build separate carts. Unlock shared savings.',
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: food ? 'Create FoodShare' : 'Create Share Basket',
                  onPressed: () {
                    if (!state.authenticated) {
                      ProtectedActionSheet.show(
                        context,
                        '/create-shared?mode=${widget.mode.name}',
                      );
                    } else {
                      context.push('/create-shared?mode=${widget.mode.name}');
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 49,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in const [
                  'All nearby',
                  'Distance',
                  'Cuisine',
                  'Discount',
                  'Time left',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, color: AppColors.dark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      food
                          ? 'Join neighbours ordering from the same restaurant. Addresses always stay private.'
                          : 'Everyone pays for their own items. Only first names and avatars are shared.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.dark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            14,
            AppSpacing.screenPadding,
            widget.embedded ? AppSpacing.navigationClearance + 76 : 32,
          ),
          sliver: SliverList.separated(
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = groups[index];
              return SharedOrderCard(
                group: group,
                joined: state.joinedGroupIds.contains(group.id),
                onTap: () => context.push('/shared/${group.id}'),
                onJoin: () => handleJoinGroup(context, ref, group),
              );
            },
          ),
        ),
      ],
    );
    if (widget.embedded) return SafeArea(bottom: false, child: body);
    return Scaffold(
      appBar: AppBar(
        title: Text(food ? 'FoodShare near you' : 'Share Baskets near you'),
      ),
      body: body,
    );
  }
}

class SharedOrderDetailsScreen extends ConsumerWidget {
  const SharedOrderDetailsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sharedGroupProvider(groupId)).value;
    final group = detail?.group ?? _emptyGroup(groupId);
    // Membership is whatever the server says; the local set is only an
    // optimistic echo for the session.
    final bool locallyJoined = ref.watch(
      appControllerProvider.select(
        (state) => state.joinedGroupIds.contains(groupId),
      ),
    );
    final bool joined = detail?.joined ?? locallyJoined;
    final grocery = group.mode == DeliveryMode.grocery;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            title: Text(group.title),
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AppIconAction(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                translucent: true,
                onPressed: () => context.pop(),
              ),
            ),
            leadingWidth: 56,
            actions: [
              AppIconAction(
                icon: Icons.favorite_border_rounded,
                tooltip: 'Save group',
                translucent: true,
                onPressed: () {},
              ),
              const SizedBox(width: 6),
              AppIconAction(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share group',
                translucent: true,
                onPressed: () => context.push('/invite/${group.id}'),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: group.imageUrl,
                    fit: BoxFit.cover,
                    semanticLabel: group.title,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x66000000)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    GroupCountdown(minutes: group.minutesLeft),
                  ],
                ),
                const SizedBox(height: 5),
                Text('${group.subtitle} • ${group.distanceKm} km away'),
                const SizedBox(height: AppSpacing.md),
                SharedOrderStatusBanner(
                  status: joined
                      ? SharedOrderUiStatus.joined
                      : group.participants >= group.requiredParticipants - 1
                      ? SharedOrderUiStatus.nearlyFull
                      : SharedOrderUiStatus.available,
                ),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group savings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DiscountProgressBar(group: group),
                        if (grocery) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const _MilestoneIndicator(),
                        ],
                        const Divider(height: 30),
                        _detailRow(
                          'Product / food discount',
                          '${group.currentDiscount}%',
                          Icons.local_offer_outlined,
                        ),
                        _detailRow(
                          'Delivery discount',
                          '${group.deliveryDiscount}%',
                          Icons.delivery_dining_outlined,
                        ),
                        _detailRow(
                          'Your estimated savings',
                          '₹${group.savings}',
                          Icons.savings_outlined,
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: '${group.participants} people are in',
                  subtitle: 'First names only • personal details stay private',
                ),
                const SizedBox(height: AppSpacing.sm),
                const _ParticipantRow(names: ['Maya', 'Kabir', 'Nisha', 'You']),
                const SizedBox(height: AppSpacing.lg),
                PremiumSurface(
                  color: AppColors.primaryVeryLight,
                  borderColor: AppColors.primaryLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grocery
                            ? 'How Share Basket works'
                            : 'Safe shared ordering',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      const _InfoLine(
                        icon: Icons.payments_outlined,
                        text: 'Pay only for your items',
                      ),
                      const _InfoLine(
                        icon: Icons.lock_outline_rounded,
                        text: 'Your address remains private',
                      ),
                      const _InfoLine(
                        icon: Icons.route_outlined,
                        text: 'Separate order tracking for your delivery',
                      ),
                      const _InfoLine(
                        icon: Icons.currency_rupee_rounded,
                        text: 'Automatic refund if the group does not complete',
                      ),
                      const _InfoLine(
                        icon: Icons.verified_user_outlined,
                        text: 'Order placed only after payment confirmation',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 132),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: AppButton(
            label: joined
                ? 'Open waiting room'
                : grocery
                ? 'Join Basket & save ₹${group.savings}'
                : 'Join Order & save ₹${group.savings}',
            icon: joined
                ? Icons.meeting_room_outlined
                : Icons.group_add_rounded,
            onPressed: joined
                ? () => context.push('/waiting-room/${group.id}')
                : () async {
                    await handleJoinGroup(context, ref, group);
                    if (context.mounted &&
                        ref
                            .read(appControllerProvider)
                            .joinedGroupIds
                            .contains(group.id)) {
                      context.push('/waiting-room/${group.id}');
                    }
                  },
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.dark),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: highlight ? AppColors.dark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneIndicator extends StatelessWidget {
  const _MilestoneIndicator();

  @override
  Widget build(BuildContext context) {
    const steps = [('2', '3%'), ('3', '5%'), ('5', '8%'), ('8', '12%')];
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          return const Expanded(
            child: Divider(color: AppColors.primary, thickness: 2),
          );
        }
        final step = steps[index ~/ 2];
        final unlocked = index ~/ 2 < 3;
        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: unlocked
                  ? AppColors.primary
                  : const Color(0xFFE5E7EB),
              child: unlocked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      step.$1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              step.$2,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        );
      }),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFFFDBB8),
      Color(0xFFDDEBFF),
      Color(0xFFFFE0EE),
      AppColors.light,
    ];
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: List.generate(names.length, (index) {
        return Column(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: colors[index % colors.length],
              child: Text(
                names[index][0],
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(names[index], style: Theme.of(context).textTheme.labelSmall),
          ],
        );
      }),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.dark, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class CreateSharedOrderScreen extends ConsumerStatefulWidget {
  const CreateSharedOrderScreen({required this.mode, super.key});

  final DeliveryMode mode;

  @override
  ConsumerState<CreateSharedOrderScreen> createState() =>
      _CreateSharedOrderScreenState();
}

class _CreateSharedOrderScreenState
    extends ConsumerState<CreateSharedOrderScreen> {
  double _duration = 20;
  bool _friendsOnly = false;
  bool _substitutions = true;

  @override
  Widget build(BuildContext context) {
    final grocery = widget.mode == DeliveryMode.grocery;
    return Scaffold(
      appBar: AppBar(
        title: Text(grocery ? 'Create Share Basket' : 'Create FoodShare'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    grocery
                        ? Icons.shopping_basket_outlined
                        : Icons.restaurant_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grocery ? 'Save up to 12%' : 'Save up to 15%',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        grocery
                            ? 'Invite people while keeping baskets separate.'
                            : 'Choose a restaurant and let nearby people join.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            grocery ? 'Choose a store' : 'Choose a restaurant',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            leading: const CircleAvatar(
              backgroundColor: AppColors.light,
              child: Icon(Icons.storefront_rounded, color: AppColors.dark),
            ),
            title: Text(grocery ? 'Turquoise Daily' : 'The Spice Route'),
            subtitle: Text(
              grocery ? '12 minute delivery' : 'North Indian • 24 min',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Group open for',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${_duration.round()} minutes',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          Slider(
            value: _duration,
            min: 10,
            max: 45,
            divisions: 7,
            onChanged: (value) => setState(() => _duration = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Friends only'),
            subtitle: const Text('Only people with your invite link can join'),
            value: _friendsOnly,
            onChanged: (value) => setState(() => _friendsOnly = value),
          ),
          if (grocery)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow substitutions'),
              subtitle: const Text(
                'You still approve substitutions for your own items',
              ),
              value: _substitutions,
              onChanged: (value) => setState(() => _substitutions = value),
            ),
          const SizedBox(height: 18),
          const _MilestoneIndicator(),
          const SizedBox(height: 28),
          AppButton(
            label: grocery ? 'Create Share Basket' : 'Create FoodShare',
            icon: Icons.people_alt_rounded,
            onPressed: () {
              final id = grocery ? 'b1' : 's1';
              ref.read(appControllerProvider.notifier).joinGroup(id);
              context.go('/waiting-room/$id');
            },
          ),
        ],
      ),
    );
  }
}

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  bool _approved = false;

  @override
  Widget build(BuildContext context) {
    final group =
        ref.watch(sharedGroupProvider(widget.groupId)).value?.group ??
        _emptyGroup(widget.groupId);
    final grocery = group.mode == DeliveryMode.grocery;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group waiting room'),
        actions: [
          IconButton(
            onPressed: () => context.push('/invite/${group.id}'),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Text(
                  '${group.minutesLeft}:00',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'until the group closes',
                  style: TextStyle(color: Color(0xFFBCECE5)),
                ),
                const SizedBox(height: 18),
                DiscountProgressBar(group: group),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Participants',
            subtitle: grocery
                ? 'Each person has a private basket'
                : 'The group is getting closer to the next saving',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final participant in const [
            ('Maya', '4 items', true),
            ('Kabir', '2 items', true),
            ('Nisha', 'Adding items…', false),
            ('You', '3 items', true),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.light,
                child: Text(
                  participant.$1[0],
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(participant.$1),
              subtitle: Text(participant.$2),
              trailing: participant.$3
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                    )
                  : const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          if (grocery) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.change_circle_outlined,
                          color: AppColors.dark,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Substitution request',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Full Cream Milk 1 L is unavailable. Replace with Fresh Dairy Milk 1 L at the same price?',
                    ),
                    const SizedBox(height: 12),
                    if (_approved)
                      const AppPill(
                        label: 'Approved',
                        icon: Icons.check_rounded,
                        background: Color(0xFFEAF8EF),
                        foreground: Color(0xFF137333),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Skip item'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => setState(() => _approved = true),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Invite friends',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => context.push('/invite/${group.id}'),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Continue adding items',
            outlined: true,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}

class InviteFriendsScreen extends ConsumerWidget {
  const InviteFriendsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group =
        ref.watch(sharedGroupProvider(groupId)).value?.group ??
        _emptyGroup(groupId);
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: AppColors.light,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add_rounded,
                size: 54,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Unlock ${group.maximumDiscount}% off together',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Invite friends to join ${group.title}. Their address and basket details remain private.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'turquoise.app/join/TQ8SAVE',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _message(context, 'Invite link copied'),
                    icon: const Icon(Icons.copy_rounded, color: AppColors.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Share on WhatsApp',
              icon: Icons.chat_rounded,
              onPressed: () =>
                  _message(context, 'WhatsApp share preview opened'),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Share invite link',
              outlined: true,
              icon: Icons.ios_share_rounded,
              onPressed: () => _message(context, 'Share sheet preview opened'),
            ),
          ],
        ),
      ),
    );
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
