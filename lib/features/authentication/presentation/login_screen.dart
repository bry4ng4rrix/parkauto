import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/domain/tone.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/submit_button.dart';
import 'brand_mark.dart';
import 'login_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
    if (success) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final expired =
        ref.watch(sessionControllerProvider.select((s) => s.reason)) ==
        SignOutReason.sessionExpired;
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    final fieldErrors = state.fieldErrors;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandMark(),
                      AppSpacing.gapXxxl,
                      Text('Connexion', style: theme.textTheme.titleLarge),
                      AppSpacing.gapXs,
                      Text(
                        'Identifiez-vous avec votre compte conducteur.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapXxl,
                      if (expired && state.error == null) ...[
                        const InlineMessage(
                          message:
                              'Votre session a expiré. Veuillez vous reconnecter.',
                          tone: Tone.warning,
                        ),
                        AppSpacing.gapLg,
                      ],
                      if (state.error case final error?) ...[
                        InlineMessage.error(error),
                        AppSpacing.gapLg,
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !state.submitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          errorText: fieldErrors['email'],
                        ),
                        validator: Validators.email,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      AppSpacing.gapLg,
                      TextFormField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        enabled: !state.submitting,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          errorText: fieldErrors['motDePasse'],
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Afficher le mot de passe'
                                : 'Masquer le mot de passe',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: Validators.password,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      AppSpacing.gapXxl,
                      SubmitButton(
                        label: 'Se connecter',
                        loading: state.submitting,
                        onPressed: _submit,
                      ),
                      if (config.environment != AppEnvironment.production) ...[
                        AppSpacing.gapXxl,
                        Text(
                          '${config.environment.label} · ${config.apiBaseUrl}',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
