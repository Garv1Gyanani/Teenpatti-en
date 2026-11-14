import 'package:flutter/foundation.dart';

import '../../domain/entities/avatar_option.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/get_avatar_options_usecase.dart';
import '../../domain/usecases/save_user_profile_usecase.dart';

enum ProfileSetupStatus { idle, saving, saved, error }

/// Presentation controller for the Set Up Your Profile screen.
class ProfileSetupController extends ChangeNotifier {
  ProfileSetupController({
    required GetAvatarOptionsUseCase getAvatarOptionsUseCase,
    required SaveUserProfileUseCase saveUserProfileUseCase,
  })  : _saveUserProfileUseCase = saveUserProfileUseCase,
        avatars = getAvatarOptionsUseCase() {
    if (avatars.isNotEmpty) {
      _selectedAvatarId = avatars.first.id;
    }
  }

  static const int maxNicknameLength = 15;

  final SaveUserProfileUseCase _saveUserProfileUseCase;
  final List<AvatarOption> avatars;

  late String _selectedAvatarId;
  String get selectedAvatarId => _selectedAvatarId;

  AvatarOption get selectedAvatar => avatars.firstWhere(
        (avatar) => avatar.id == _selectedAvatarId,
        orElse: () => avatars.first,
      );

  String _nickname = '';
  String get nickname => _nickname;

  String? _linkedProvider;
  String? get linkedProvider => _linkedProvider;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ProfileSetupStatus _status = ProfileSetupStatus.idle;
  ProfileSetupStatus get status => _status;

  bool _isDisposed = false;

  void selectAvatar(String avatarId) {
    if (_selectedAvatarId == avatarId) return;
    _selectedAvatarId = avatarId;
    _notifySafely();
  }

  void cycleNextAvatar() {
    if (avatars.isEmpty) return;
    final currentIndex = avatars.indexWhere((a) => a.id == _selectedAvatarId);
    final nextIndex = (currentIndex + 1) % avatars.length;
    selectAvatar(avatars[nextIndex].id);
  }

  void updateNickname(String value) {
    _nickname = value;
    if (_errorMessage != null && value.trim().isNotEmpty) {
      _errorMessage = null;
    }
    _notifySafely();
  }

  void toggleLinkedProvider(String provider) {
    _linkedProvider = _linkedProvider == provider ? null : provider;
    _notifySafely();
  }

  Future<void> submit() async {
    if (_status == ProfileSetupStatus.saving) return;

    final trimmed = _nickname.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Please enter a nickname to continue.';
      _status = ProfileSetupStatus.error;
      _notifySafely();
      return;
    }

    _errorMessage = null;
    _status = ProfileSetupStatus.saving;
    _notifySafely();

    try {
      await _saveUserProfileUseCase(
        UserProfile(
          nickname: trimmed,
          avatarId: _selectedAvatarId,
          linkedProvider: _linkedProvider,
        ),
      );
      _status = ProfileSetupStatus.saved;
      _notifySafely();
    } catch (_) {
      _errorMessage = 'Unable to save profile. Please try again.';
      _status = ProfileSetupStatus.error;
      _notifySafely();
    }
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

