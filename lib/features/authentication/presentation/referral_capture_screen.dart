import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/storage/referral_storage.dart';
import '../../../core/widgets/app_ui.dart';
import '../../app_state/providers/app_controller.dart';

/// Landing point for a customer referral deep link.
///
/// Reached from `mangaale://referral/<code>` and, once the App Link is
/// verified, from `https://mangaale.com/r/<code>`. It stores the code and
/// sends the visitor on; nothing is attributed here, because attribution is
/// authenticated and this visitor has no account yet.
class ReferralCaptureScreen extends ConsumerStatefulWidget {
  const ReferralCaptureScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ReferralCaptureScreen> createState() =>
      _ReferralCaptureScreenState();
}

class _ReferralCaptureScreenState extends ConsumerState<ReferralCaptureScreen> {
  String? _message;
  bool _canSignUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    final normalized = ReferralStorage.normalize(widget.code);
    final storage = ReferralStorage();

    if (!ReferralStorage.isCustomerReferralCode(normalized)) {
      _show('That referral link is not valid for this app.', canSignUp: false);
      return;
    }

    // Referral codes are for new accounts. Saying so is better than storing a
    // code the server would refuse later.
    if (ref.read(appControllerProvider).authenticated) {
      _show(
        'Referral codes can only be used when creating a new account.',
        canSignUp: false,
      );
      return;
    }

    await storage.storePendingCode(normalized);
    _show(
      'Referral code $normalized saved. It will be applied when you create '
      'your account.',
      canSignUp: true,
    );
  }

  void _show(String message, {required bool canSignUp}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _canSignUp = canSignUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Referral invite')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'YOUR INVITE CODE',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ReferralStorage.normalize(widget.code),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? 'Checking this invite…',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (message != null) ...[
              if (_canSignUp)
                AppButton(
                  label: 'Create my account',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.go('/login'),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: _canSignUp ? 'Browse first' : 'Continue',
                outlined: true,
                onPressed: () => context.go('/home'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
