import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/grocery_push_open_broker.dart';
import '../features/app_state/providers/app_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TurquoiseApp extends ConsumerStatefulWidget {
  const TurquoiseApp({super.key});

  @override
  ConsumerState<TurquoiseApp> createState() => _TurquoiseAppState();
}

class _TurquoiseAppState extends ConsumerState<TurquoiseApp> {
  GroceryOrderPushTarget? _pendingGroceryOrder;

  @override
  void initState() {
    super.initState();
    // A tapped grocery order notification opens tracking once the customer is
    // signed in. The tracking screen re-reads the order, so the backend decides
    // whether this customer may see it.
    ref.listenManual<AppState>(appControllerProvider, (_, next) {
      if (next.authenticated) _openPendingGroceryOrder();
    });
    GroceryPushOpenBroker.instance.attach((target) {
      _pendingGroceryOrder = target;
      _openPendingGroceryOrder();
    });
  }

  @override
  void dispose() {
    GroceryPushOpenBroker.instance.detach();
    super.dispose();
  }

  void _openPendingGroceryOrder() {
    final target = _pendingGroceryOrder;
    if (target == null || !ref.read(appControllerProvider).authenticated) {
      return;
    }
    _pendingGroceryOrder = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(appRouterProvider)
            .push<void>('/tracking/${target.orderId}?mode=grocery'),
      );
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
