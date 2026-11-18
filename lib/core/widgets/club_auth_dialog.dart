import 'package:flutter/material.dart';

import '../session/app_session_store.dart';
import '../session/supabase_sync_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum ClubAuthDialogMode {
  landingSignIn,
  manageAccount,
}

/// Modal dialog for Member Sign-In / Registration on [LandingPage] and
/// Guest → Permanent Account Linking in [SettingsPage].
class ClubAuthDialog extends StatefulWidget {
  const ClubAuthDialog({
    super.key,
    required this.mode,
    this.playerId,
    this.playerName,
    this.linkedProvider,
    this.onSignIn,
    this.onRegister,
    this.onLinkAccount,
  });

  final ClubAuthDialogMode mode;
  final String? playerId;
  final String? playerName;
  final String? linkedProvider;

  final Future<SupabaseAuthResult> Function(String email, String password)?
      onSignIn;
  final Future<SupabaseAuthResult> Function(
    String email,
    String password,
    String? nickname,
  )? onRegister;
  final Future<SupabaseAuthResult> Function(String email, String password)?
      onLinkAccount;

  @override
  State<ClubAuthDialog> createState() => _ClubAuthDialogState();
}

class _ClubAuthDialogState extends State<ClubAuthDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  bool _isCreateAccountTab = false;
  bool _isSignInExistingTab = false;
  bool _showSwitchFormWhenLinked = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorText;
  String? _successText;

  bool get _isAlreadyLinked {
    final provider = widget.linkedProvider;
    return provider != null && provider.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final nickname = _nicknameController.text.trim();

    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorText = 'Please enter a valid email address.';
        _successText = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _errorText = 'Password must be at least 6 characters.';
        _successText = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
      _successText = null;
    });

    try {
      final store = AppSessionStore.instance;
      late final SupabaseAuthResult result;

      if (widget.mode == ClubAuthDialogMode.landingSignIn) {
        if (_isCreateAccountTab) {
          final registerFn = widget.onRegister ??
              (e, p, n) => store.registerWithEmail(
                    email: e,
                    password: p,
                    nickname: n,
                  );
          result = await registerFn(email, password, nickname);
        } else {
          final signInFn = widget.onSignIn ??
              (e, p) => store.signInWithEmail(email: e, password: p);
          result = await signInFn(email, password);
        }
      } else {
        if (_isSignInExistingTab || _showSwitchFormWhenLinked) {
          final signInFn = widget.onSignIn ??
              (e, p) => store.signInWithEmail(email: e, password: p);
          result = await signInFn(email, password);
        } else {
          final linkFn = widget.onLinkAccount ??
              (e, p) => store.linkGuestAccountWithEmail(
                    email: e,
                    password: p,
                  );
          result = await linkFn(email, password);
        }
      }

      if (!mounted) return;
      if (!result.succeeded) {
        setState(() {
          _isSubmitting = false;
          _errorText = result.errorMessage ?? 'Authentication failed.';
        });
        return;
      }

      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLanding = widget.mode == ClubAuthDialogMode.landingSignIn;
    final showAuthForm =
        isLanding || !_isAlreadyLinked || _showSwitchFormWhenLinked;

    final title = isLanding
        ? (_isCreateAccountTab ? 'Create Club Account' : 'Member Sign In')
        : 'Manage Account';

    final subtitle = isLanding
        ? (_isCreateAccountTab
            ? 'Save your chips and career progress across devices'
            : 'Sign in with your linked email and password')
        : (_isAlreadyLinked && !_showSwitchFormWhenLinked
            ? 'Your profile and chip balance are linked for cross-device recovery.'
            : 'Link an email & password so your chips and stats are never lost.');

    return Dialog(
      backgroundColor: AppColors.creamBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: AppColors.inputBorder.withValues(alpha: 0.8),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.forestGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.modalHeading.copyWith(fontSize: 21),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.mutedText,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.38,
                  color: AppColors.mutedText,
                ),
              ),
              if (!isLanding) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.inputBorder.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.playerName != null)
                        Text(
                          widget.playerName!,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      if (widget.playerId != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Player ID: ${widget.playerId}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _isAlreadyLinked
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                            color: _isAlreadyLinked
                                ? const Color(0xFF2B8C48)
                                : const Color(0xFFB37B16),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _isAlreadyLinked
                                  ? 'Linked: ${widget.linkedProvider}'
                                  : 'Status: Guest Session (Unlinked)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _isAlreadyLinked
                                    ? const Color(0xFF2B8C48)
                                    : const Color(0xFF8A5D0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (showAuthForm) ...[
                const SizedBox(height: 14),
                _ModeTabs(
                  leftLabel: isLanding ? 'Sign In' : 'Link Guest Account',
                  rightLabel:
                      isLanding ? 'Create Account' : 'Sign In Existing',
                  isRightSelected: isLanding
                      ? _isCreateAccountTab
                      : _isSignInExistingTab,
                  onSelectRight: (right) {
                    setState(() {
                      if (isLanding) {
                        _isCreateAccountTab = right;
                      } else {
                        _isSignInExistingTab = right;
                      }
                      _errorText = null;
                    });
                  },
                ),
                if (isLanding && _isCreateAccountTab) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('auth_nickname_field'),
                    controller: _nicknameController,
                    textInputAction: TextInputAction.next,
                    maxLength: 18,
                    decoration: InputDecoration(
                      labelText: 'Club Nickname (Optional)',
                      hintText: 'e.g. Kabir',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 19,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const Key('auth_email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'member@acesociety.club',
                    filled: true,
                    fillColor: AppColors.inputFill,
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      size: 19,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('auth_password_field'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 6 characters',
                    filled: true,
                    fillColor: AppColors.inputFill,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 19,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF0EE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEED5D0)),
                    ),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFC93B2B),
                      ),
                    ),
                  ),
                ],
                if (_successText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _successText!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B8C48),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    key: const Key('auth_submit_button'),
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isLanding
                                ? (_isCreateAccountTab
                                    ? 'Create Account'
                                    : 'Sign In')
                                : ((_isSignInExistingTab ||
                                        _showSwitchFormWhenLinked)
                                    ? 'Sign In'
                                    : 'Link Account'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _showSwitchFormWhenLinked = true;
                            _isSignInExistingTab = true;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forestGreen,
                          side: const BorderSide(color: AppColors.forestGreen),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Switch Account'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forestGreen,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Got It'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.leftLabel,
    required this.rightLabel,
    required this.isRightSelected,
    required this.onSelectRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isRightSelected;
  final ValueChanged<bool> onSelectRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: leftLabel,
              selected: !isRightSelected,
              onTap: () => onSelectRight(false),
            ),
          ),
          Expanded(
            child: _TabPill(
              label: rightLabel,
              selected: isRightSelected,
              onTap: () => onSelectRight(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.forestGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.forestGreen,
            ),
          ),
        ),
      ),
    );
  }
}
