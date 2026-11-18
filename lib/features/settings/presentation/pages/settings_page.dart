import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/audio/app_audio_cue.dart';
import '../../../../core/audio/app_audio_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ace_card.dart';
import '../../../../core/widgets/club_auth_dialog.dart';
import '../../../../core/widgets/subpage_background_waves.dart';
import '../../../../core/widgets/subpage_header.dart';
import '../../domain/entities/app_settings_state.dart';
import '../controllers/settings_controller.dart';

/// Settings & Help screen matching the Ace Society design.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
  });

  final SettingsController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadSettings();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _copyPlayerId(String playerId) async {
    await Clipboard.setData(ClipboardData(text: playerId));
    if (mounted) {
      _showFeedback('Player ID $playerId copied!');
    }
  }

  Future<void> _showInfoSheet(String title, String body) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.modalHeading,
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Got It'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openManageAccountDialog(AppSettingsState settings) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => ClubAuthDialog(
        mode: ClubAuthDialogMode.manageAccount,
        playerId: settings.playerId,
        playerName: settings.playerName,
        linkedProvider: settings.linkedProvider,
        onLinkAccount: (email, password) =>
            widget.controller.linkAccount(email: email, password: password),
        onSignIn: (email, password) => widget.controller
            .signInExistingAccount(email: email, password: password),
      ),
    );
    if (!mounted || result == null) return;
    _showFeedback('Account linked to ${result.email ?? 'your email'}!');
  }

  Future<void> _confirmLogOut() async {
    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Log Out',
            style: AppTextStyles.modalHeading,
          ),
          content: const Text(
            'Are you sure you want to log out of Ace Society?',
            style: TextStyle(color: AppColors.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.forestGreen),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC93B2B),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogOut == true && mounted) {
      await widget.controller.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.landing,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: SubpageBackgroundWaves(),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final settings = widget.controller.state;
                if (widget.controller.isLoading || settings == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                    ),
                  );
                }

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SubpageHeader(
                        title: 'Settings & Help',
                        subtitle: 'Customize your experience and get support',
                        onBackTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 18),

                      // Game Preferences Card
                      _SettingsSectionCard(
                        icon: Icons.sports_esports_outlined,
                        title: 'Game Preferences',
                        children: [
                          _ToggleRow(
                            icon: Icons.volume_up_outlined,
                            label: 'Sound Effects',
                            value: settings.soundEffects,
                            onChanged: widget.controller.toggleSoundEffects,
                          ),
                          _VolumeSliderRow(
                            icon: Icons.graphic_eq_rounded,
                            label: 'SFX Volume',
                            value: settings.sfxVolume,
                            enabled: settings.soundEffects,
                            onChanged: (v) =>
                                widget.controller.setSfxVolume(v),
                            onChangeEnd: (v) {
                              widget.controller.setSfxVolume(v, persist: true);
                              AppAudioService.instance.play(AppAudioCue.uiTap);
                            },
                          ),
                          _ToggleRow(
                            icon: Icons.music_note_outlined,
                            label: 'Background Music',
                            value: settings.backgroundMusic,
                            onChanged: widget.controller.toggleBackgroundMusic,
                          ),
                          _VolumeSliderRow(
                            icon: Icons.tune_rounded,
                            label: 'Music Volume',
                            value: settings.musicVolume,
                            enabled: settings.backgroundMusic,
                            onChanged: (v) =>
                                widget.controller.setMusicVolume(v),
                            onChangeEnd: (v) => widget.controller
                                .setMusicVolume(v, persist: true),
                          ),
                          _ToggleRow(
                            icon: Icons.vibration_rounded,
                            label: 'Vibration',
                            value: settings.vibration,
                            onChanged: widget.controller.toggleVibration,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Account Card
                      _SettingsSectionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'Account',
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.profile),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFECE9DF),
                                      border: Border.all(
                                        color: AppColors.inputBorder
                                            .withValues(alpha: 0.7),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        settings.avatarAsset,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          settings.playerName,
                                          style: const TextStyle(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF14281D),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Player ID: ${settings.playerId}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.mutedText,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _copyPlayerId(
                                                settings.playerId,
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              child: const Padding(
                                                padding: EdgeInsets.all(2),
                                                child: Icon(
                                                  Icons.copy_rounded,
                                                  size: 17,
                                                  color: Color(0xFF1E3728),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF2D3F33),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _ChevronRow(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Manage Account',
                            badgeText: settings.isAccountLinked
                                ? 'Linked'
                                : 'Link Email',
                            onTap: () => _openManageAccountDialog(settings),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Game & Information Card
                      _SettingsSectionCard(
                        icon: Icons.filter_none_rounded,
                        title: 'Game & Information',
                        children: [
                          _ChevronRow(
                            icon: Icons.menu_book_outlined,
                            label: 'Game Rules',
                            onTap: () => _showInfoSheet(
                              'Teen Patti Game Rules',
                              'Hand Rankings (Highest to Lowest):\n'
                              '1. Trail / Trio (Three of a Kind)\n'
                              '2. Pure Sequence (Straight Flush)\n'
                              '3. Sequence (Straight)\n'
                              '4. Color (Flush)\n'
                              '5. Pair (Two of a Kind)\n'
                              '6. High Card\n\n'
                              'Play Blind or Seen, request a Sideshow, or call Show when two players remain.',
                            ),
                          ),
                          _ChevronRow(
                            icon: Icons.verified_user_outlined,
                            label: 'Privacy Policy',
                            onTap: () => _showInfoSheet(
                              'Privacy Policy',
                              'Ace Society collects only your nickname, chosen avatar, and in-game statistics to provide multiplayer table matching and progression.',
                            ),
                          ),
                          _ChevronRow(
                            icon: Icons.description_outlined,
                            label: 'Terms & Conditions',
                            onTap: () => _showInfoSheet(
                              'Terms & Conditions',
                              'All chips in Ace Society are virtual in-game currency for social entertainment and have no real-world monetary value.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Help & Support Card
                      _SettingsSectionCard(
                        icon: Icons.headset_mic_outlined,
                        title: 'Help & Support',
                        children: [
                          _ChevronRow(
                            icon: Icons.help_outline_rounded,
                            label: 'Help / FAQ',
                            onTap: () => _showInfoSheet(
                              'Help / FAQ',
                              '• How do I get free chips?\nVisit Daily Rewards or the Chip Wallet to claim daily bonuses and streak rewards.\n\n• How do Private Rooms work?\nShare your 6-character room code with friends to play at a private table.',
                            ),
                          ),
                          _ChevronRow(
                            icon: Icons.sms_outlined,
                            label: 'Contact Support',
                            onTap: () => _showInfoSheet(
                              'Contact Support',
                              'Need help with a table or your account?\nReach our support desk at support@acesociety.club with Player ID ${settings.playerId}.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Log Out Button
                      Material(
                        color: const Color(0xFFFCF0EE),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: _confirmLogOut,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFEED5D0),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFFC93B2B),
                                  size: 22,
                                ),
                                SizedBox(width: 14),
                                Text(
                                  'Log Out',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFC93B2B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AceCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.forestGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF14281D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < children.length; i++) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.inputBorder.withValues(alpha: 0.38),
            ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 21, color: AppColors.forestGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1E2D24),
              ),
            ),
          ),
          AceToggleSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _VolumeSliderRow extends StatelessWidget {
  const _VolumeSliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final percent = (value.clamp(0.0, 1.0) * 100).round();
    final activeColor = AppColors.forestGreen;
    final fgOpacity = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: fgOpacity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: activeColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E2D24),
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: AppTextStyles.chipBalance.copyWith(
                    fontSize: 13,
                    color: activeColor,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
                activeTrackColor: activeColor,
                inactiveTrackColor: AppColors.inputBorder.withValues(alpha: 0.45),
                thumbColor: activeColor,
                overlayColor: activeColor.withValues(alpha: 0.14),
                disabledActiveTrackColor:
                    activeColor.withValues(alpha: 0.45),
                disabledThumbColor: activeColor.withValues(alpha: 0.5),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: enabled ? onChanged : null,
                onChangeEnd: enabled ? onChangeEnd : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeText,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.forestGreen),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1E2D24),
                ),
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF2D3F33),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
