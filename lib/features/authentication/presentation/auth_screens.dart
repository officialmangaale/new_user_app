import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/premium_components.dart';
import '../../../core/services/api_exception.dart';
import '../../../shared/models/app_models.dart';
import '../../app_state/providers/app_controller.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      final authenticated = ref.read(appControllerProvider).authenticated;
      context.go(authenticated ? '/home' : '/welcome');
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x26000000), blurRadius: 24),
                  ],
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  size: 54,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'turquoise',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Food, groceries & savings — together.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE6FFFB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                compact ? AppSpacing.sm : AppSpacing.md,
                AppSpacing.screenPadding,
                compact ? AppSpacing.md : AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.xl,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BrandMark(),
                      SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
                      WelcomeHeroComposition(compact: compact),
                      SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                      Text(
                        'Food, groceries and shared savings—delivered together.',
                        style: compact
                            ? Theme.of(context).textTheme.headlineMedium
                            : Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Quick local delivery, better prices with nearby people, and real-time tracking from store to door.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                      AppButton(
                        label: 'Continue with mobile number',
                        icon: Icons.phone_outlined,
                        onPressed: () => context.push('/login'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Explore as guest',
                        outlined: true,
                        onPressed: () => context.go('/home'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Row(
                        children: [
                          Expanded(
                            child: BenefitRow(
                              icon: Icons.bolt_rounded,
                              label: 'Fast local delivery',
                              stacked: true,
                            ),
                          ),
                          Expanded(
                            child: BenefitRow(
                              icon: Icons.groups_2_outlined,
                              label: 'Save with nearby people',
                              stacked: true,
                            ),
                          ),
                          Expanded(
                            child: BenefitRow(
                              icon: Icons.route_rounded,
                              label: 'Track every order',
                              stacked: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delivery_dining_rounded, color: Colors.white),
        ),
        const SizedBox(width: 9),
        const Flexible(
          child: Text(
            'turquoise',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: AppColors.dark,
            ),
          ),
        ),
      ],
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.returnTo, super.key});

  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Requests an OTP from user-service, then hands the phone number to the
  /// verify screen. Navigation only happens once the backend has accepted.
  Future<void> _sendOtp() async {
    final phone = _controller.text.replaceAll(' ', '');
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      context.push(
        Uri(
          path: '/otp',
          queryParameters: {
            'returnTo': widget.returnTo ?? '/setup',
            'phone': phone,
          },
        ).toString(),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _controller.text.replaceAll(' ', '').length == 10;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'What’s your number?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'We’ll text you a one-time code. No passwords, no fuss.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '98765 43210',
                  prefixIconConstraints: const BoxConstraints(minWidth: 92),
                  prefixIcon: InkWell(
                    onTap: () => _showCountryCodes(context),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 15),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🇮🇳  +91',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: _sending ? 'Sending OTP…' : 'Send OTP',
                onPressed: (valid && !_sending) ? _sendOtp : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryCodes(BuildContext context) {
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
                'Select country code',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final country in const [
                ('🇮🇳', 'India', '+91'),
                ('🇬🇧', 'United Kingdom', '+44'),
                ('🇦🇪', 'United Arab Emirates', '+971'),
              ])
                ListTile(
                  leading: Text(
                    country.$1,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(country.$2),
                  trailing: Text(country.$3),
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.returnTo, this.phone = '', super.key});

  final String returnTo;

  /// Number the OTP was sent to, forwarded by [LoginScreen].
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  int _seconds = 30;
  Timer? _timer;
  bool _verifying = false;

  String get _code => _controllers.map((c) => c.text).join();

  /// Verifies the code against user-service and persists the returned session.
  /// The screen only advances after the backend has issued a token.
  Future<void> _verify() async {
    setState(() => _verifying = true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: widget.phone, otp: _code);
      await ref.read(appControllerProvider.notifier).completeLogin(session);
      if (!mounted) return;
      // A returning customer should not be pushed back through onboarding.
      final destination = (!session.user.isNewUser && widget.returnTo == '/setup')
          ? '/home'
          : widget.returnTo;
      context.go(destination);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Requests a fresh code, then restarts the countdown.
  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      if (!mounted) return;
      setState(_startTimer);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complete = _controllers.every(
      (controller) => controller.text.isNotEmpty,
    );
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify your number',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.phone.isEmpty
                    ? 'Enter the 6-digit code we just sent you.'
                    : 'Enter the 6-digit code sent to +91 ${widget.phone}.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: List.generate(6, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 5 ? 0 : 7),
                      child: TextField(
                        controller: _controllers[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            FocusScope.of(context).nextFocus();
                          }
                          setState(() {});
                        },
                        decoration: const InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: _seconds > 0
                    ? Text(
                        'Resend code in 00:${_seconds.toString().padLeft(2, '0')}',
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Resend code'),
                      ),
              ),
              const Spacer(),
              AppButton(
                label: _verifying ? 'Verifying…' : 'Verify & continue',
                onPressed: (complete && !_verifying) ? _verify : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController(text: 'Aarav');
  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Set up profile' : 'Your preference'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _step == 0
                ? _profileStep(context)
                : _preferenceStep(context),
          ),
        ),
      ),
    );
  }

  Widget _profileStep(BuildContext context) {
    return Column(
      key: const ValueKey('profile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nice to meet you!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Tell us what we should call you.'),
        const SizedBox(height: 28),
        const Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.light,
                child: Icon(
                  Icons.person_rounded,
                  size: 54,
                  color: AppColors.dark,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const Spacer(),
        AppButton(
          label: 'Continue',
          onPressed: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _preferenceStep(BuildContext context) {
    return Column(
      key: const ValueKey('preference'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where shall we start?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('You can switch between both any time.'),
        const SizedBox(height: 28),
        _PreferenceCard(
          icon: Icons.restaurant_rounded,
          title: 'Food delivery',
          message: 'Restaurants, dishes and FoodShare savings',
          onTap: () {
            ref.read(appControllerProvider.notifier).setMode(DeliveryMode.food);
            context.go('/home');
          },
        ),
        const SizedBox(height: 14),
        _PreferenceCard(
          icon: Icons.local_grocery_store_rounded,
          title: 'Grocery delivery',
          message: 'Fresh essentials and Share Basket deals',
          onTap: () {
            ref
                .read(appControllerProvider.notifier)
                .setMode(DeliveryMode.grocery);
            context.go('/home');
          },
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Center(child: Text('Decide later')),
        ),
      ],
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: AppColors.dark, size: 29),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProtectedActionSheet extends StatelessWidget {
  const ProtectedActionSheet({required this.returnTo, super.key});

  final String returnTo;

  static Future<void> show(BuildContext context, String returnTo) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ProtectedActionSheet(returnTo: returnTo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: AppColors.light,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.dark,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to continue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your cart and browsing stay right here. Sign in securely with a one-time code.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Sign in with mobile',
              onPressed: () {
                Navigator.pop(context);
                context.push(
                  Uri(
                    path: '/login',
                    queryParameters: {'returnTo': returnTo},
                  ).toString(),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
