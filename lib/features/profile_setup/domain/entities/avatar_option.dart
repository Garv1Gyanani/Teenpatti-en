/// Represents a selectable avatar asset for player profile setup.
class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.assetPath,
    required this.label,
  });

  final String id;
  final String assetPath;
  final String label;
}

