/// Distinguishes who controls a participant in a Teen Patti match.
enum ParticipantKind {
  /// Local or remote human user.
  human,

  /// Offline client-side AI bot running on this device.
  clientBot,

  /// Future server-backed online AI agent playing via the shared user model.
  onlineAgent,
}

/// Unified user model shared across human players, offline client bots,
/// and future online AI agents.
class GameUser {
  const GameUser({
    required this.id,
    required this.name,
    required this.chips,
    required this.avatarAsset,
    this.kind = ParticipantKind.human,
    this.personaTag,
    this.rating = 1000,
  });

  final String id;
  final String name;
  final int chips;
  final String avatarAsset;
  final ParticipantKind kind;
  final String? personaTag;
  final int rating;

  bool get isHuman => kind == ParticipantKind.human;
  bool get isClientBot => kind == ParticipantKind.clientBot;
  bool get isOnlineAgent => kind == ParticipantKind.onlineAgent;

  GameUser copyWith({
    String? id,
    String? name,
    int? chips,
    String? avatarAsset,
    ParticipantKind? kind,
    String? personaTag,
    int? rating,
  }) {
    return GameUser(
      id: id ?? this.id,
      name: name ?? this.name,
      chips: chips ?? this.chips,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      kind: kind ?? this.kind,
      personaTag: personaTag ?? this.personaTag,
      rating: rating ?? this.rating,
    );
  }
}
