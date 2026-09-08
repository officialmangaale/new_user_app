Implemented the product-image cart interaction using the existing cart providers and checkout screen.

- `lib/features/cart/presentation/product_cart_animation.dart`: silent 600 ms image flight, curved movement and shrinking, actual product image URL, bounded concurrent overlays, route/disposal cleanup, and system reduced-motion support. Cart quantities update before animation and never depend on its completion.
- `lib/features/cart/presentation/floating_cart.dart`: turquoise rounded cart bar, overlapping photos for three distinct products, additional-product count, immediate quantity/subtotal, arrival bounce and thumbnail highlight. The most recently added product is included among the photos. Expands and collapses through a rounded rectangle transition into the existing scrollable cart screen.
- `lib/features/cart/presentation/cart_screens.dart`: panel close action and compact Checkout label; preserves existing validation, fees, instructions, addresses, authentication and checkout navigation. Quantity increments now repeat the exact selected variant and add-ons instead of adding the base item.
- `lib/features/catalog/presentation/add_to_cart.dart`: retains success/failure outcomes and option hydration; prevents duplicate pending customization flows while ordinary repeat taps still increment immediately.
- `lib/core/widgets/app_ui.dart`: normal turquoise Add button, reduced-motion quantity transition, and immediate clean fallback for empty image URLs.
- `lib/shared/widgets/delivery_cards.dart`, catalog `catalog_detail_screens.dart`, `category_items_screen.dart`, `search_screen.dart`, and home `home_screen.dart`: product-image origins and cart docks across browsing surfaces; reserved space above navigation; overlay cleanup when changing home tabs or delivery mode. Existing image-origin improvements were retained.
- Account `addresses_screen.dart`, `profile_screen.dart`, orders `orders_screen.dart`, tracking `tracking_screen.dart`, and `lib/app/theme/app_colors.dart`: removed nature settings and decorations; retained refresh, profile, tracking and order behavior using ordinary widgets.
- `pubspec.yaml`, `pubspec.lock`, and generated Linux/macOS/Windows plugin registrations: removed the unused audioplayers dependency and registrations.
- `test/features/cart/add_to_cart_outcome_test.dart`: retained and relocated cart outcome coverage, extended for duplicate option taps. `test/features/cart/floating_cart_test.dart`: interaction, navigation, variant, fallback, and lifecycle regression coverage plus an optional capture harness.

Cleanup removed `lib/core/nature/`, its obsolete effect tests, the nature audio generator and old capture harness, and all seven nature WAV assets (including the untracked leaf/tip recordings present at task start). Removed water drops, ripples, splashes, clay pot, fill effects, audio startup, preferences and animation controllers. Ordinary Material button feedback and the unrelated dairy category icon remain. No cart state or checkout service was reverted.

Verification:

- Eleven focused cart tests passed; cart plus authentication domain tests passed together (30 tests).
- Tested first add, ten rapid repeats, multiple distinct products, reduction, last-unit removal, failed option requests, cancelled customization, duplicate option taps, missing images, long-cart scrolling, opening/closing, selected variants, reduced motion, navigation cleanup, and checkout instructions/navigation.
- Targeted analysis of the changed cart/catalog presentation, shared UI and cart tests passed with no issues. `git diff --check` passed.
- Android debug APK build passed: `build/app/outputs/flutter-apk/app-debug.apk`.
- Full-project analysis remains blocked by existing stale tests referencing deleted MockData, the previous AppController cart API, and incomplete catalog repository fakes; it reports 46 issues including existing informational lints.
- The broader widget run passed 33 tests and failed one existing test expecting the literal greeting “Good evening”. The production home no longer supplies that static greeting.
- Web compilation is blocked in the existing `firebase_messaging_web` dependency by missing `PromiseJsImpl` and `handleThenable` symbols. Firebase dependencies were not changed by this work.

Visual review and recording:

- `build/cart_capture/cart-interaction.mp4` is a five-second capture of real widget rendering with missing-image test fixtures, showing first add, repeat add, expansion and collapse. It uses a system font for legibility in Flutter's test renderer. It is not a recording against a live catalog or backend.
- Regenerate frames on Windows with `flutter test test/features/cart/floating_cart_test.dart --dart-define=CART_CAPTURE=true --plain-name "record cart interaction"`; encode `build/cart_capture/frame_%04d.png` at 25 fps with FFmpeg.
- The reference video was not accessible in the conversation or workspace, so exact reference matching could not be verified. No device was connected for live checkout verification, and no order was placed.
