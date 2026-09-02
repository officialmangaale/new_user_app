// ignore_for_file: invalid_use_of_visible_for_testing_member
// Visual capture harness for the nature layer. NOT part of the test suite.
//
// It lives outside `test/` so `flutter test` never picks it up. Run it
// explicitly to regenerate the review images:
//
//     flutter test tool/visual_capture/nature_capture_test.dart
//
// Output goes to `build/nature_capture/`.
//
// Why frames rather than screen grabs: almost everything in the nature layer is
// motion. A still of Home before and after looks nearly identical, because the
// ripple, the flight and the badge bounce only exist for a few hundred
// milliseconds. Capturing named frames of each effect is the only way to
// review it in still images.
//
// Two things about the rendering environment, so nothing here is mistaken for a
// bug in the app:
//
//   * Product photos show the app's own "image unavailable" placeholder — the
//     test environment has no network. Only the artwork inside the shape is
//     missing; the shape, tint and path are the real thing.
//   * A system font is loaded below as "Roboto". Without it the test renderer
//     draws every glyph as a filled box.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/app/theme/app_colors.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/core/nature/cart_drop/add_to_cart_drop_animation.dart';
import 'package:turquoise_delivery/core/nature/cart_drop/cart_beacon.dart';
import 'package:turquoise_delivery/core/nature/nature_preferences.dart';
import 'package:turquoise_delivery/core/nature/widgets/leaf_accent.dart';
import 'package:turquoise_delivery/core/nature/widgets/nature_refresh_indicator.dart';
import 'package:turquoise_delivery/core/nature/widgets/order_success_ripple.dart';
import 'package:turquoise_delivery/core/widgets/app_ui.dart';
import 'package:turquoise_delivery/features/account/presentation/profile_screen.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

const _outputDir = 'build/nature_capture';
final _captureKey = GlobalKey();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Directory(_outputDir).createSync(recursive: true);
    await _loadSystemFont();
  });
  // Real stored defaults, so the settings capture shows the shipping state
  // rather than a harness override. Audio is instead suppressed per-frame by
  // `silentOverrides`, which only the captures that can trigger a splash use.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // -------------------------------------------------------------------------
  // 1. The ADD button
  // -------------------------------------------------------------------------

  testWidgets('01 add button', (tester) async {
    await _frame(
      tester,
      const Size(280, 116),
      _panel(
        label: 'BEFORE',
        child: SizedBox(
          height: 38,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(72, 38),
              padding: const EdgeInsets.symmetric(horizontal: 13),
            ),
            child: const Text('ADD'),
          ),
        ),
      ),
    );
    await _save(tester, '01a-add-before');

    await _frame(
      tester,
      const Size(280, 116),
      _panel(
        label: 'AFTER · at rest',
        child: QuantityControl(
          quantity: 0,
          onAdd: () {},
          onRemove: () {},
          compact: true,
        ),
      ),
    );
    await _save(tester, '01b-add-after-idle');

    // Pressed left of centre, so the ring is visibly off-centre — the whole
    // point is that it starts where the finger landed, not at the middle.
    final rect = tester.getRect(find.byType(OutlinedButton));
    await tester.tapAt(Offset(rect.left + rect.width * 0.22, rect.center.dy));

    // Three frames across the ripple's 420 ms life, so the review can judge
    // whether "low opacity" landed as calm or as invisible.
    var elapsed = 0;
    for (final step in <int>[70, 80, 110]) {
      await tester.pump(Duration(milliseconds: step));
      elapsed += step;
      await _save(tester, '01c-add-ripple-${elapsed}ms');
    }
    await tester.pumpAndSettle();
  });

  // -------------------------------------------------------------------------
  // 2. Section heading leaf accent
  // -------------------------------------------------------------------------

  testWidgets('02 section heading', (tester) async {
    Widget heading({required bool leaf}) => Row(
      children: [
        if (leaf)
          const Padding(
            padding: EdgeInsets.only(right: 7, bottom: 2),
            child: LeafAccent(size: 15),
          ),
        Expanded(
          child: Text(
            'Popular near you',
            style: AppTheme.light.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Text(
          'View all',
          style: TextStyle(color: AppColors.primary, fontSize: 13),
        ),
      ],
    );

    await _frame(
      tester,
      const Size(380, 96),
      _panel(label: 'BEFORE', child: heading(leaf: false)),
    );
    await _save(tester, '02a-heading-before');

    await _frame(
      tester,
      const Size(380, 96),
      _panel(label: 'AFTER', child: heading(leaf: true)),
    );
    await _save(tester, '02b-heading-after');
  });

  // -------------------------------------------------------------------------
  // 3. Cart icon
  // -------------------------------------------------------------------------

  testWidgets('03 cart beacon', (tester) async {
    await _frame(
      tester,
      const Size(240, 130),
      _panel(label: 'BEFORE', child: _cartIcon(badge: 3)),
    );
    await _save(tester, '03a-cart-before');

    await _frame(
      tester,
      const Size(240, 130),
      _panel(
        label: 'AFTER · calm turquoise disc',
        child: CartBeacon(
          discSize: 54,
          builder: (context, scale) => _cartIcon(badge: 3, badgeScale: scale),
        ),
      ),
    );
    await _save(tester, '03b-cart-after-idle');

    (tester.state<State>(find.byType(CartBeacon)) as dynamic).playArrival();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await _save(tester, '03c-cart-after-arrival');
    await tester.pumpAndSettle();
  });

  // -------------------------------------------------------------------------
  // 4. The drop in flight
  // -------------------------------------------------------------------------

  testWidgets('04 drop flight', (tester) async {
    final imageKey = GlobalKey();
    late WidgetRef captured;
    late BuildContext innerContext;

    await _frame(
      tester,
      const Size(380, 320),
      ColoredBox(
        color: const Color(0xFFF7FAF8),
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            // Must be a context inside MaterialApp: the drop is an overlay
            // entry, and the app's Overlay is below the capture boundary.
            innerContext = context;
            return Stack(
              children: [
                // A stand-in for the product image. The real app flies the
                // photo already in the image cache; this harness has no
                // network and `cached_network_image` needs plugins the test
                // environment does not provide, so a flat swatch stands in.
                // What is under review here is the path, shape, scaling and
                // turquoise wash — all of which are the real thing.
                Positioned(
                  left: 26,
                  bottom: 46,
                  child: Container(
                    key: imageKey,
                    width: 120,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'product\nimage',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 26,
                  top: 22,
                  child: CartBeacon(
                    discSize: 54,
                    builder: (context, scale) =>
                        _cartIcon(badge: 2, badgeScale: scale),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    captured
        .read(cartDropControllerProvider)
        .celebrateAdd(
          // ignore: use_build_context_synchronously
          context: innerContext,
          item: _item,
          isFirstAdd: true,
          sourceKey: imageKey,
        );
    await tester.pump();

    // Cumulative: each entry is the gap since the previous frame.
    var elapsed = 0;
    for (final step in <int>[100, 130, 130, 130]) {
      await tester.pump(Duration(milliseconds: step));
      elapsed += step;
      await _save(tester, '04-drop-flight-${elapsed}ms');
    }
    await tester.pump(const Duration(milliseconds: 600));
  });

  // -------------------------------------------------------------------------
  // 5. Pull-to-refresh
  // -------------------------------------------------------------------------

  testWidgets('05 refresh indicator', (tester) async {
    await _frame(
      tester,
      const Size(320, 230),
      NatureRefreshIndicator(
        onRefresh: () => Future<void>.delayed(const Duration(seconds: 5)),
        displacement: 26,
        child: ListView.builder(
          itemCount: 12,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ),
      ),
    );
    await _save(tester, '05a-refresh-idle');

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, 45));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await _save(tester, '05b-refresh-drop-forming');

    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    await _save(tester, '05c-refresh-armed-ripple');

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _save(tester, '05d-refresh-leaf-loading');

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  // -------------------------------------------------------------------------
  // 6. Order success
  // -------------------------------------------------------------------------

  testWidgets('06 order celebration', (tester) async {
    // Armed before the first pump: the celebration widget consumes the flag in
    // its first post-frame callback, so arming afterwards is too late.
    final container = ProviderContainer(overrides: silentOverrides);
    addTearDown(container.dispose);
    container.read(orderCelebrationProvider.notifier).arm('TQ240761');

    await _frame(
      tester,
      const Size(340, 300),
      // Mirrors the tracking screen's shape: a map header on top, order details
      // below it. The celebration is confined to that header band, so this is
      // the layout that proves the leaf never crosses the order number.
      OrderSuccessCelebration(
        orderId: 'TQ240761',
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 126,
                color: AppColors.primaryVeryLight,
                alignment: Alignment.center,
                child: const Text(
                  'map',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Order #TQ240761',
                textAlign: TextAlign.center,
                style: AppTheme.light.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Order confirmed · arriving in 32 min',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      container: container,
    );

    await tester.pump(const Duration(milliseconds: 260));
    await _save(tester, '06a-order-ripple');
    await tester.pump(const Duration(milliseconds: 340));
    await _save(tester, '06b-order-leaf-rising');
    await tester.pumpAndSettle();
  });

  // -------------------------------------------------------------------------
  // 7. Settings
  // -------------------------------------------------------------------------

  testWidgets('07 profile toggles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ProviderScope(
          overrides: [
            appControllerProvider.overrideWith(_StubAppController.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.scrollUntilVisible(
      find.text('Nature Sounds'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _save(tester, '07-profile-nature-settings');
  });
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

const _item = CatalogItem(
  id: 'i1',
  name: 'Alphonso Mangoes',
  subtitle: '1 kg',
  store: 'Green Basket',
  price: 240,
  originalPrice: 280,
  imageUrl: '',
  type: CatalogItemType.grocery,
  storeId: 's1',
);

/// Registers a real system font as "Roboto".
///
/// The Flutter test renderer ships no text font, so without this every glyph
/// draws as a solid rectangle and the captures are unreadable.
Future<void> _loadSystemFont() async {
  await _loadFirst('Roboto', <String>[
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ]);

  // Without this every Icon renders as an empty "tofu" box, which makes the
  // cart captures unreadable. The font ships with the SDK.
  final flutterRoot = _flutterRoot();
  await _loadFirst('MaterialIcons', <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _loadFirst(String family, List<String> candidates) async {
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader(family)
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    await loader.load();
    return;
  }
  stderr.writeln('Capture: no font found for "$family".');
}

/// Derives the SDK root from the running Dart executable, which lives at
/// `<flutter>/bin/cache/dart-sdk/bin/dart`.
String? _flutterRoot() {
  var dir = Directory(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      return dir.path.replaceAll(r'\', '/');
    }
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

Widget _cartIcon({required int badge, Animation<double>? badgeScale}) {
  Widget dot = Container(
    constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$badge',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        height: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  if (badgeScale != null) {
    dot = ScaleTransition(scale: badgeScale, child: dot);
  }
  return Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        onPressed: () {},
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          maximumSize: const Size.square(44),
          backgroundColor: Colors.white.withValues(alpha: 0.96),
          foregroundColor: AppColors.textPrimary,
          shadowColor: const Color(0x22075E54),
          elevation: 3,
        ),
        icon: const Icon(Icons.shopping_cart_outlined, size: 23),
      ),
      Positioned(right: -3, top: -4, child: dot),
    ],
  );
}

Widget _panel({required String label, required Widget child}) {
  return ColoredBox(
    color: const Color(0xFFF7FAF8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// The RepaintBoundary sits **above** [MaterialApp] on purpose.
///
/// The add-to-cart drop is an overlay entry, and the overlay lives inside the
/// app's Navigator. A boundary placed inside the Scaffold would capture
/// everything except the one thing being photographed.
Future<void> _frame(
  WidgetTester tester,
  Size size,
  Widget child, {
  ProviderContainer? container,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final app = MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: Scaffold(backgroundColor: const Color(0xFFF7FAF8), body: child),
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: container == null
          ? ProviderScope(overrides: silentOverrides, child: app)
          : UncontrolledProviderScope(container: container, child: app),
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
}

/// Forces sound off synchronously.
///
/// Setting the SharedPreferences mock is not enough: the real notifier hydrates
/// asynchronously, so a capture that fires within the first frames still sees
/// the default (on) and constructs an AudioPlayer — which raises an async
/// MissingPluginException in a test VM. Overriding `build` skips hydration
/// entirely.
final silentOverrides = [
  naturePreferencesProvider.overrideWith(_SilentNaturePreferences.new),
];

class _SilentNaturePreferences extends NaturePreferences {
  @override
  NaturePreferencesState build() =>
      const NaturePreferencesState(soundsEnabled: false, loaded: true);
}

/// Rasterises the current frame to a PNG.
///
/// The `runAsync` wrapper is essential: `toImage` completes on the engine's
/// raster thread, and inside a widget test's fake-async zone that future never
/// resolves — the call simply hangs until the suite times out.
Future<void> _save(WidgetTester tester, String name) async {
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outputDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _StubAppController extends AppController {
  @override
  AppState build() => const AppState(sessionLoaded: true);
}
