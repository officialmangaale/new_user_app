import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../orders/providers/orders_providers.dart';

/// The customer's name for orders, from the profile or the stored session.
/// Empty when the customer has never given one (phone-OTP sign-up does not ask).
Future<String> readKnownCustomerName(WidgetRef ref) async {
  try {
    final profile = await ref.read(accountRepositoryProvider).fetchProfile();
    if (profile.name.trim().isNotEmpty) return profile.name.trim();
  } catch (_) {
    // Offline or not signed in: fall through to the stored name.
  }
  final stored = await ref.read(authStorageProvider).readUserName();
  return (stored ?? '').trim();
}

/// Asks for the name, in one field. Returns the saved name, or null when the
/// customer dismissed the sheet.
Future<String?> showCustomerNameSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const CustomerNameSheet(),
    ),
  );
}

class CustomerNameSheet extends ConsumerStatefulWidget {
  const CustomerNameSheet({super.key});

  @override
  ConsumerState<CustomerNameSheet> createState() => _CustomerNameSheetState();
}

class _CustomerNameSheetState extends ConsumerState<CustomerNameSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    setState(() => _saving = true);

    // The order carries this name whatever happens next, so it is kept on the
    // device first. Syncing it to the profile is best effort: a slow or failed
    // sync must never stop someone placing an order.
    await ref.read(authStorageProvider).saveUserName(name);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(name: name)
          .timeout(const Duration(seconds: 10));
      ref.invalidate(profileProvider);
    } catch (_) {
      // Stored locally; the profile will pick it up on the next edit.
    }
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What is your name?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'The restaurant and rider use it to hand over your order.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('customer-name-field'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Please enter your name.'
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('customer-name-save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save and continue'),
            ),
          ],
        ),
      ),
    );
  }
}
