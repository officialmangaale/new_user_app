import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/grocery_push_open_broker.dart';
import '../core/storage/campaign_attribution_storage.dart';
import '../features/app_state/providers/app_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TurquoiseApp extends ConsumerStatefulWidget {
  const TurquoiseApp({super.key});

  @override
  ConsumerState<TurquoiseApp> createState() => _TurquoiseAppState();
}

class _TurquoiseAppState extends ConsumerState<TurquoiseApp> {
  PushOpenTarget? _pendingPushTarget;

  @override
  void initState() {
    super.initState();
    // A tapped notification (food/grocery order or product) opens its screen
    // once the customer is signed in. The destination screen re-reads the data
    // from the backend, so the backend decides what this customer may see and
    // what the current price/offer is.
    ref.listenManual<AppState>(appControllerProvider, (_, next) {
      if (next.authenticated) _openPendingPushTarget();
    });
    GroceryPushOpenBroker.instance.attach((target) {
      _pendingPushTarget = target;
      _openPendingPushTarget();
    });
  }

  @override
  void dispose() {
    GroceryPushOpenBroker.instance.detach();
    super.dispose();
  }

  void _openPendingPushTarget() {
    final target = _pendingPushTarget;
    if (target == null || !ref.read(appControllerProvider).authenticated) {
      return;
    }
    _pendingPushTarget = null;
    // Remember the campaign so the next order can be attributed to it.
    final campaignId = target.campaignId;
    if (campaignId != null) {
      unawaited(const CampaignAttributionStorage().store(campaignId));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(appRouterProvider).push<void>(target.location));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mangaale',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
