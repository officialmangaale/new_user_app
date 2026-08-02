import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import 'puzzle_game.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  static const _statuses = [
    'Order confirmed',
    'Preparing',
    'Rider assigned',
    'Picked up',
    'On the way',
    'Arriving soon',
    'Delivered',
  ];
  int _statusIndex = 4;
  bool _importantAlert = false;
  Timer? _statusTimer;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(seconds: 18), (_) {
      if (!mounted || _statusIndex >= _statuses.length - 1) return;
      setState(() {
        _statusIndex++;
        _importantAlert = true;
      });
      _alertTimer?.cancel();
      _alertTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _importantAlert = false);
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eta = _statusIndex >= 5 ? '2 min' : '11 min';
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text('Order #${widget.orderId}'),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.help_outline_rounded),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 330,
              child: Stack(
                children: [
                  const Positioned.fill(child: _MapPlaceholder()),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 14,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _importantAlert
                          ? Container(
                              key: const ValueKey('alert'),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.navy,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_active_rounded,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      '${_statuses[_statusIndex]} • Your order status just changed',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-alert')),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statuses[_statusIndex],
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 3),
                                const Text('Arjun is heading to your location'),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                eta,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: AppColors.dark),
                              ),
                              const Text(
                                '1.8 km away',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.list(
              children: [
                RiderInformationCard(
                  onCall: () => _toast('Calling Arjun…'),
                  onChat: () => _toast('Rider chat preview opened'),
                  onSafety: () => _safetySheet(context),
                ),
                const SizedBox(height: AppSpacing.md),
                _StatusTimeline(
                  statuses: _statuses,
                  currentIndex: _statusIndex,
                ),
                const SizedBox(height: AppSpacing.md),
                WaitingPuzzleGame(pausedForOrderAlert: _importantAlert),
                const SizedBox(height: AppSpacing.md),
                const _SharedOrderSummary(),
                const SizedBox(height: AppSpacing.md),
                const _CollapsibleOrderSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _safetySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety centre',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.light,
                  child: Icon(
                    Icons.share_location_rounded,
                    color: AppColors.dark,
                  ),
                ),
                title: Text('Share live order status'),
                subtitle: Text('Let a trusted contact follow this delivery'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.light,
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.dark,
                  ),
                ),
                title: Text('Contact safety support'),
                subtitle: Text('Available throughout your delivery'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFFFEDEE),
                  child: Icon(Icons.emergency_rounded, color: AppColors.error),
                ),
                title: Text('Emergency assistance'),
                subtitle: Text('Call local emergency services'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F0EC),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          const Positioned(
            left: 35,
            top: 72,
            child: _MapMarker(
              icon: Icons.restaurant_rounded,
              label: 'Restaurant',
              color: AppColors.navy,
            ),
          ),
          const Positioned(
            right: 94,
            top: 138,
            child: _MapMarker(
              icon: Icons.delivery_dining_rounded,
              label: 'Arjun',
              color: AppColors.primary,
            ),
          ),
          const Positioned(
            right: 27,
            bottom: 78,
            child: _MapMarker(
              icon: Icons.home_rounded,
              label: 'You',
              color: AppColors.dark,
            ),
          ),
          Positioned(
            right: 14,
            top: 18,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'locate',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.dark,
                  onPressed: () {},
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'layers',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.dark,
                  onPressed: () {},
                  child: const Icon(Icons.layers_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke;
    final minorPaint = Paint()
      ..color = const Color(0xFFC9DDD5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final road = Path()
      ..moveTo(-20, size.height * 0.26)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.55,
        size.height * 0.55,
        size.width + 30,
        size.height * 0.35,
      );
    canvas.drawPath(road, roadPaint);
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i + 1) / 6;
      canvas.drawLine(Offset(x, 0), Offset(x - 55, size.height), minorPaint);
    }
    final route = Path()
      ..moveTo(size.width * 0.2, size.height * 0.31)
      ..cubicTo(
        size.width * 0.44,
        size.height * 0.2,
        size.width * 0.63,
        size.height * 0.6,
        size.width * 0.83,
        size.height * 0.7,
      );
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x30000000), blurRadius: 8),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class RiderInformationCard extends StatelessWidget {
  const RiderInformationCard({
    required this.onCall,
    required this.onChat,
    required this.onSafety,
    super.key,
  });
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onSafety;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 31,
                  backgroundColor: AppColors.light,
                  child: Icon(
                    Icons.person_rounded,
                    size: 34,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arjun Kumar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      const Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                            size: 17,
                          ),
                          Expanded(
                            child: Text(
                              '4.9  •  Electric scooter',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'KA 03 EF 2147',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _RiderAction(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  onTap: onCall,
                ),
                const SizedBox(width: 6),
                _RiderAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  onTap: onChat,
                ),
              ],
            ),
            const Divider(height: 24),
            InkWell(
              onTap: onSafety,
              child: const Row(
                children: [
                  Icon(Icons.health_and_safety_outlined, color: AppColors.dark),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Safety tools',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderAction extends StatelessWidget {
  const _RiderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.light,
            child: Icon(icon, color: AppColors.dark, size: 18),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.statuses, required this.currentIndex});
  final List<String> statuses;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: const Border(),
        title: Text(
          'Delivery progress',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(statuses[currentIndex]),
        leading: const CircleAvatar(
          backgroundColor: AppColors.light,
          child: Icon(Icons.route_rounded, color: AppColors.dark),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              children: List.generate(statuses.length, (index) {
                final complete = index <= currentIndex;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: complete
                                  ? AppColors.primary
                                  : const Color(0xFFE5E7EB),
                              child: complete
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            if (index < statuses.length - 1)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: complete && index < currentIndex
                                      ? AppColors.primary
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(
                            statuses[index],
                            style: TextStyle(
                              fontWeight: index == currentIndex
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: complete
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedOrderSummary extends StatelessWidget {
  const _SharedOrderSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: AppColors.dark),
              const SizedBox(width: 9),
              Text(
                'FoodShare delivery',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Row(
            children: [
              Expanded(
                child: _GroupStat(label: 'Participants', value: '5'),
              ),
              Expanded(
                child: _GroupStat(label: 'Group savings', value: '₹412'),
              ),
              Expanded(
                child: _GroupStat(label: 'Preparation', value: 'Complete'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Delivery sequence: You’re stop 1 of 3. Other addresses are kept private.',
            style: TextStyle(fontSize: 12, color: AppColors.dark),
          ),
        ],
      ),
    );
  }
}

class _GroupStat extends StatelessWidget {
  const _GroupStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.dark,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 9)),
    ],
  );
}

class _CollapsibleOrderSummary extends StatelessWidget {
  const _CollapsibleOrderSummary();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          'Order summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: const Text('3 items • ₹624'),
        children: const [
          ListTile(
            title: Text('Royal Chicken Biryani × 2'),
            trailing: Text('₹558'),
          ),
          ListTile(title: Text('House dip × 1'), trailing: Text('₹29')),
          ListTile(title: Text('Taxes & fees'), trailing: Text('₹37')),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}
