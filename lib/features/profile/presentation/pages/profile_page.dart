import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ace_card.dart';
import '../../../../core/widgets/subpage_background_waves.dart';
import '../../../../core/widgets/subpage_header.dart';
import '../controllers/profile_controller.dart';
import '../widgets/performance_chart_card.dart';

/// My Profile screen matching the Ace Society design.
/// Works both as a standalone route and embedded inside the Home Profile tab.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    this.embedded = false,
    this.onBackTap,
    this.onAddChipsTap,
    this.onSettingsTap,
  });

  final ProfileController controller;
  final bool embedded;
  final VoidCallback? onBackTap;
  final VoidCallback? onAddChipsTap;
  final VoidCallback? onSettingsTap;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadProfile();
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

  Future<void> _showEditProfileDialog() async {
    final profile = widget.controller.profile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.name);
    var selectedAvatar = profile.avatarAsset;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.creamBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Edit Profile',
                style: AppTextStyles.modalHeading,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Select Avatar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.controller.availableAvatars.map((asset) {
                      final isSelected = asset == selectedAvatar;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedAvatar = asset),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.forestGreen
                                  : AppColors.inputBorder,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              asset,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.forestGreen),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    widget.controller.updateProfile(
                      name: nameController.text,
                      avatarAsset: selectedAvatar,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _showInfoSheet(String title, List<String> lines) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 14),
              Text(
                title,
                style: AppTextStyles.modalHeading,
              ),
              const SizedBox(height: 12),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppColors.forestGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E2D24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollContent() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final profile = widget.controller.profile;
        if (widget.controller.isLoading || profile == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.forestGreen),
          );
        }

        final chartValues =
            profile.weeklyPerformance[widget.controller.selectedMetric] ??
                const [];

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            widget.embedded ? 6 : 10,
            16,
            widget.embedded ? 16 : 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SubpageHeader(
                title: 'My Profile',
                onBackTap:
                    widget.onBackTap ?? () => Navigator.of(context).maybePop(),
                trailingIcon: Icons.settings_outlined,
                trailingTooltip: 'Settings & Help',
                onTrailingTap: widget.onSettingsTap ??
                    () => Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
              const SizedBox(height: 18),

              // Avatar + Name + ID + Club Member Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFECE9DF),
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            profile.avatarAsset,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GestureDetector(
                          onTap: _showEditProfileDialog,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.inputBorder,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Color(0xFF1D3325),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.modalHeading.copyWith(
                            fontSize: 22.5,
                            color: const Color(0xFF143820),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Player ID: ${profile.playerId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _copyPlayerId(profile.playerId),
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 17,
                                  color: Color(0xFF1D3325),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7EFE5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.workspace_premium_rounded,
                                size: 17,
                                color: Color(0xFFC89223),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                profile.tierLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Chip Balance Card
              AceCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      const PokerChipBadge(size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Chip Balance',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.mutedText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${formatIndianNumber(profile.chipBalance)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF143820),
                              ),
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        width: 24,
                        thickness: 1,
                        color: AppColors.inputBorder.withValues(alpha: 0.45),
                      ),
                      SizedBox(
                        height: 40,
                        child: FilledButton.icon(
                          onPressed: widget.onAddChipsTap ??
                              () => Navigator.of(context)
                                  .pushNamed(AppRoutes.wallet),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 19),
                          label: const Text(
                            'Add Chips',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4-Stat Summary Row Card
              AceCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _ProfileStatColumn(
                          icon: Icons.style_outlined,
                          iconColor: AppColors.forestGreen,
                          label: 'Games Played',
                          value: formatCommaNumber(profile.gamesPlayed),
                        ),
                      ),
                      _verticalDivider(),
                      Expanded(
                        child: _ProfileStatColumn(
                          icon: Icons.emoji_events_rounded,
                          iconColor: const Color(0xFFD89D27),
                          label: 'Wins',
                          value: formatCommaNumber(profile.wins),
                        ),
                      ),
                      _verticalDivider(),
                      Expanded(
                        child: _ProfileStatColumn(
                          icon: Icons.track_changes_rounded,
                          iconColor: AppColors.forestGreen,
                          label: 'Win Rate',
                          value: '${profile.winRatePercent}%',
                        ),
                      ),
                      _verticalDivider(),
                      Expanded(
                        child: _ProfileStatColumn(
                          icon: Icons.bar_chart_rounded,
                          iconColor: AppColors.forestGreen,
                          label: 'Best Streak',
                          value: '${profile.bestStreak}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Performance Chart Card
              PerformanceChartCard(
                values: chartValues,
                selectedMetric: widget.controller.selectedMetric,
                onSelectMetric: widget.controller.selectMetric,
              ),
              const SizedBox(height: 14),

              // Bottom Menu Links Card
              AceCard(
                borderRadius: 20,
                child: Column(
                  children: [
                    _ProfileMenuRow(
                      icon: Icons.military_tech_outlined,
                      label: 'Achievements',
                      onTap: () => _showInfoSheet(
                        'Achievements',
                        const [
                          'Trail Blazer — Won 25 hands with Three of a Kind',
                          'High Roller — Reached ₹1,00,000+ Chip Balance',
                          '12-Day Streak — Claimed Daily Rewards 12 days straight',
                          'Table Host — Hosted 15+ Private Room matches',
                        ],
                      ),
                    ),
                    _rowDivider(),
                    _ProfileMenuRow(
                      icon: Icons.history_rounded,
                      label: 'Game History',
                      onTap: () => _showInfoSheet(
                        'Recent Game History',
                        widget.controller.recentHistoryLines,
                      ),
                    ),
                    _rowDivider(),
                    _ProfileMenuRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Account & Security',
                      onTap: widget.onSettingsTap ??
                          () => Navigator.of(context)
                              .pushNamed(AppRoutes.settings),
                    ),
                    _rowDivider(),
                    _ProfileMenuRow(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: widget.onSettingsTap ??
                          () => Navigator.of(context)
                              .pushNamed(AppRoutes.settings),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _verticalDivider() {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: AppColors.inputBorder.withValues(alpha: 0.45),
    );
  }

  Widget _rowDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.inputBorder.withValues(alpha: 0.38),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildScrollContent();
    }

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: SubpageBackgroundWaves(),
          ),
          SafeArea(
            child: _buildScrollContent(),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatColumn extends StatelessWidget {
  const _ProfileStatColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedText,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14281D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  color: Color(0xFF14281D),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFF2D3F33),
            ),
          ],
        ),
      ),
    );
  }
}
