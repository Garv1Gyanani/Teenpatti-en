import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ace_background_waves.dart';
import '../../../../core/widgets/ace_brand_header.dart';
import '../controllers/profile_setup_controller.dart';
import '../widgets/avatar_picker_row.dart';
import '../widgets/avatar_preview_badge.dart';
import '../widgets/link_account_section.dart';
import '../widgets/nickname_input_field.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.controller,
  });

  final ProfileSetupController controller;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final TextEditingController _nicknameController;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted || _hasNavigated) return;
    if (widget.controller.status == ProfileSetupStatus.saved) {
      _hasNavigated = true;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _nicknameController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(
              child: AceBackgroundWaves(),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ListenableBuilder(
                          listenable: widget.controller,
                          builder: (context, _) {
                            final isSaving = widget.controller.status ==
                                ProfileSetupStatus.saving;

                            return Column(
                              children: [
                                const SizedBox(height: 8),
                                _TopHeaderBar(
                                  onBack: () =>
                                      Navigator.of(context).maybePop(),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Set Up Your Profile',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.pageHeading,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Choose an avatar and a nickname to get started',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.pageSubheading,
                                ),
                                const SizedBox(height: 18),
                                AvatarPreviewBadge(
                                  assetPath:
                                      widget.controller.selectedAvatar.assetPath,
                                  onEditTap: widget.controller.cycleNextAvatar,
                                ),
                                const SizedBox(height: 18),
                                NicknameInputField(
                                  controller: _nicknameController,
                                  maxLength:
                                      ProfileSetupController.maxNicknameLength,
                                  currentLength:
                                      widget.controller.nickname.length,
                                  errorText: widget.controller.errorMessage,
                                  onChanged: widget.controller.updateNickname,
                                ),
                                const SizedBox(height: 18),
                                AvatarPickerRow(
                                  avatars: widget.controller.avatars,
                                  selectedAvatarId:
                                      widget.controller.selectedAvatarId,
                                  onSelect: widget.controller.selectAvatar,
                                ),
                                const SizedBox(height: 22),
                                LinkAccountSection(
                                  selectedProvider:
                                      widget.controller.linkedProvider,
                                  onToggleProvider:
                                      widget.controller.toggleLinkedProvider,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: isSaving
                                        ? null
                                        : widget.controller.submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.forestGreen,
                                      foregroundColor: Colors.white,
                                      shape: const StadiumBorder(),
                                      elevation: 0,
                                    ),
                                    child: isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Continue',
                                                style: TextStyle(
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 36),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.forestGreen,
              size: 24,
            ),
            tooltip: 'Back',
          ),
        ),
        AceBrandHeader(
          clubSize: 22,
          titleStyle: AppTextStyles.brandTitle.copyWith(fontSize: 26),
        ),
      ],
    );
  }
}

