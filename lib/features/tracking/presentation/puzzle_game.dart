import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/storage/guest_storage.dart';

class WaitingPuzzleGame extends StatefulWidget {
  const WaitingPuzzleGame({required this.pausedForOrderAlert, super.key});

  final bool pausedForOrderAlert;

  @override
  State<WaitingPuzzleGame> createState() => _WaitingPuzzleGameState();
}

class _WaitingPuzzleGameState extends State<WaitingPuzzleGame> {
  static const _symbols = [
    Icons.local_pizza_outlined,
    Icons.lunch_dining_outlined,
    Icons.eco_outlined,
    Icons.bakery_dining_outlined,
    Icons.eco_outlined,
    Icons.local_grocery_store_outlined,
    Icons.grass_rounded,
    Icons.cake_outlined,
  ];
  final GuestStorage _storage = GuestStorage();
  late List<IconData> _cards;
  final Set<int> _matched = {};
  final List<int> _flipped = [];
  Timer? _timer;
  int _seconds = 0;
  int _moves = 0;
  int _best = 0;
  bool _minimised = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _cards = [..._symbols, ..._symbols]..shuffle(Random());
    _loadBest();
    _startTimer();
  }

  Future<void> _loadBest() async {
    final best = await _storage.bestPuzzleScore();
    if (mounted) setState(() => _best = best);
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.pausedForOrderAlert || _matched.length == 16) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void didUpdateWidget(covariant WaitingPuzzleGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pausedForOrderAlert != oldWidget.pausedForOrderAlert) {
      if (widget.pausedForOrderAlert) {
        _timer?.cancel();
      } else {
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _score => max(0, _matched.length * 75 - _moves * 8 - _seconds);

  Future<void> _flip(int index) async {
    if (_resolving ||
        widget.pausedForOrderAlert ||
        _matched.contains(index) ||
        _flipped.contains(index)) {
      return;
    }
    setState(() {
      _flipped.add(index);
      if (_flipped.length == 2) _moves++;
    });
    if (_flipped.length != 2) return;
    _resolving = true;
    final first = _flipped[0];
    final second = _flipped[1];
    if (_cards[first] == _cards[second]) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      setState(() {
        _matched.addAll([first, second]);
        _flipped.clear();
        _resolving = false;
      });
      if (_matched.length == 16) await _complete();
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        _flipped.clear();
        _resolving = false;
      });
    }
  }

  Future<void> _complete() async {
    _timer?.cancel();
    if (_score > _best) {
      _best = _score;
      await _storage.setBestPuzzleScore(_best);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.emoji_events_rounded,
          color: AppColors.warning,
          size: 42,
        ),
        title: const Text('Perfect match!'),
        content: Text(
          'You scored $_score points in $_seconds seconds.\n\nDaily reward: +25 Turquoise Points',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Collect reward'),
          ),
        ],
      ),
    );
  }

  void _restart() {
    setState(() {
      _cards = [..._symbols, ..._symbols]..shuffle(Random());
      _matched.clear();
      _flipped.clear();
      _seconds = 0;
      _moves = 0;
      _resolving = false;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _minimised = !_minimised),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.light,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Play While You Wait',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _matched.length == 16
                              ? 'Complete • +25 daily points'
                              : 'Match all 8 pairs',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _minimised
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: _minimised
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                children: [
                  if (widget.pausedForOrderAlert)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.pause_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFF9A6700),
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Paused for an important order update',
                              style: TextStyle(
                                color: Color(0xFF765500),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      _GameStat(label: 'SCORE', value: '$_score'),
                      _GameStat(label: 'BEST', value: '$_best'),
                      _GameStat(label: 'TIME', value: '${_seconds}s'),
                      IconButton(
                        tooltip: 'Restart',
                        onPressed: _restart,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: 16,
                    itemBuilder: (context, index) {
                      final visible =
                          _flipped.contains(index) || _matched.contains(index);
                      return Semantics(
                        button: true,
                        label: visible
                            ? 'Revealed food item card'
                            : 'Hidden puzzle card',
                        child: GestureDetector(
                          onTap: () => _flip(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _matched.contains(index)
                                  ? const Color(0xFFDDF7F1)
                                  : visible
                                  ? Colors.white
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: visible
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: visible
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x12000000),
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: visible
                                  ? Icon(
                                      _cards[index],
                                      key: ValueKey('symbol-$index'),
                                      color: AppColors.primaryDark,
                                      size: 28,
                                    )
                                  : const Icon(
                                      Icons.auto_awesome_rounded,
                                      key: ValueKey('hidden'),
                                      color: Colors.white,
                                      size: 21,
                                    ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameStat extends StatelessWidget {
  const _GameStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}
