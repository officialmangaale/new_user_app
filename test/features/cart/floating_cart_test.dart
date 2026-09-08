import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/core/widgets/app_ui.dart';
import 'package:turquoise_delivery/features/cart/presentation/floating_cart.dart';
import 'package:turquoise_delivery/features/cart/presentation/product_cart_animation.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:turquoise_delivery/features/catalog/presentation/add_to_cart.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

const _capture = bool.fromEnvironment('CART_CAPTURE');
final _captureKey = GlobalKey();

CatalogItem product(int id) => CatalogItem(
  id: '$id',
  name: 'Product $id',
  subtitle: 'Fresh groceries',
  store: 'Mangaale',
  storeId: 'shop',
  price: 100,
  originalPrice: 100,
  imageUrl: '',
  type: CatalogItemType.grocery,
);

void main() {
  if (_capture) {
    setUpAll(() async {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
      final fallback = FontLoader('Ahem')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await fallback.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
  }
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ProviderContainer> host(
    WidgetTester tester, {
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late ProviderContainer container;
    final image = GlobalKey();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                body: ListView(
                  children: [
                    AppNetworkImage(
                      key: image,
                      url: '',
                      width: 140,
                      height: 140,
                    ),
                    TextButton(
                      onPressed: () => addItemToCart(
                        context,
                        ref,
                        product(1),
                        origin: ProductAddOrigin(imageKey: image),
                      ),
                      child: const Text('Add product'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/next'),
                      child: const Text('Next'),
                    ),
                  ],
                ),
                bottomNavigationBar: const CartDock(
                  child: SizedBox(
                    height: 56,
                    child: Center(child: Text('Navigation')),
                  ),
                ),
              );
            },
          ),
        ),
        GoRoute(
          path: '/next',
          builder: (_, _) => const Scaffold(body: Text('Next page')),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Checkout destination')),
            body: Text(
              state.uri.queryParameters['instructions'] ?? 'No instructions',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesProvider.overrideWith((ref) async => []),
          cartBillProvider.overrideWith(
            (ref) async => BillSummary(
              subtotal: ref.watch(cartTotalProvider),
              discount: 0,
              deliveryFee: 20,
              packagingCharge: 0,
              cgst: 0,
              sgst: 0,
              taxAmount: 0,
              platformFee: 0,
              roundOff: 0,
              grandTotal: ref.watch(cartTotalProvider) + 20,
              valid: true,
              message: '',
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: !_capture
              ? AppTheme.light
              : AppTheme.light.copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: AppTheme.light.filledButtonTheme.style?.copyWith(
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
          routerConfig: router,
          builder: (context, child) => RepaintBoundary(
            key: _captureKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'first add and rapid repeats update immediately; flights never add quantities',
    (tester) async {
      final container = await host(tester);
      await tester.tap(find.text('Add product'));
      expect(container.read(cartCountProvider), 1);
      await tester.pump();
      expect(container.read(productCartAnimationProvider).activeFlightCount, 1);
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Add product'));
      }
      expect(container.read(cartCountProvider), 11);
      await tester.pump();
      expect(
        container.read(productCartAnimationProvider).activeFlightCount,
        lessThanOrEqualTo(6),
      );
      await tester.pumpAndSettle();
      expect(container.read(cartCountProvider), 11);
      expect(container.read(cartLinesProvider).length, 1);
      expect(container.read(productCartAnimationProvider).activeFlightCount, 0);
      expect(find.text('11 items · ₹1100'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(FloatingCartBar)).dy,
        lessThan(tester.getTopLeft(find.text('Navigation')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('distinct photos, panel scrolling, controls and last removal', (
    tester,
  ) async {
    final container = await host(tester);
    final cart = container.read(cartControllerProvider.notifier);
    for (var i = 1; i <= 12; i++) {
      cart.addItem(product(i));
    }
    await tester.pumpAndSettle();
    expect(find.text('+9'), findsOneWidget);
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Your grocery basket'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(container.read(cartCountProvider), 13);
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pumpAndSettle();
    expect(container.read(cartCountProvider), 12);
    await tester.drag(find.byType(ListView).last, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Checkout').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close cart'));
    await tester.pumpAndSettle();
    expect(find.text('View cart'), findsOneWidget);
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();
    cart.clearCart();
    await tester.pumpAndSettle();
    expect(find.byType(FloatingCartBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion omits flight; navigation clears active overlays',
    (tester) async {
      var container = await host(tester, reduced: true);
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      expect(container.read(productCartAnimationProvider).activeFlightCount, 0);
      await tester.pumpWidget(const SizedBox());
      container = await host(tester);
      await tester.tap(find.text('Add product'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(container.read(productCartAnimationProvider).activeFlightCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'panel repeats selected variant and checkout preserves instructions',
    (tester) async {
      final container = await host(tester);
      await container
          .read(appControllerProvider.notifier)
          .completeLogin(
            authToken: 'test-token',
            userId: 'test',
            name: 'Test',
            phone: '9999999999',
          );
      final cart = container.read(cartControllerProvider.notifier);
      cart.addSelection(
        CartSelection(
          item: product(1),
          variant: const MenuVariant(
            id: 'large',
            name: 'Large',
            price: 150,
            isAvailable: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View cart'));
      await tester.pumpAndSettle();
      expect(find.text('Large'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(container.read(cartLinesProvider).length, 1);
      expect(container.read(cartLinesProvider).single.variant?.id, 'large');
      expect(container.read(cartTotalProvider), 300);
      await tester.enterText(find.byType(TextField), 'No bags');
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      expect(find.text('Checkout destination'), findsOneWidget);
      expect(find.text('No bags'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Your grocery basket'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();
      expect(container.read(cartCountProvider), 0);
      expect(find.byType(FloatingCartBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  if (_capture) {
    testWidgets('record cart interaction using missing-image fixtures', (
      tester,
    ) async {
      await host(tester);
      Directory('build/cart_capture').createSync(recursive: true);
      var frame = 0;
      Future<void> frames(int count) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          final boundary =
              _captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              'build/cart_capture/frame_${(frame++).toString().padLeft(4, '0')}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      await frames(10);
      await tester.tap(find.text('Add product'));
      await frames(28);
      await tester.tap(find.text('Add product'));
      await frames(28);
      await tester.tap(find.text('View cart'));
      await frames(35);
      await tester.tap(find.byTooltip('Close cart'));
      await frames(25);
      expect(tester.takeException(), isNull);
    });
  }
}
