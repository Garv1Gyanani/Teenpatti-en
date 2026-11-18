import 'dart:math';

import 'package:teen_patti_core/teen_patti_core.dart';

/// Offline AI difficulty & play-style presets mapped onto [BotProfileParams].
enum BotStyle { tight, balanced, aggressive, bluffer, easy, medium, hard }

/// Client-side offline Teen Patti bot backed by the shared [BotDecisionEngine].
///
/// Strictly converts full [TableState] into a sanitized [SeatObservation]
/// before making decisions so offline AI can never peek at the deck or other
/// players' cards.
class OfflineTeenPattiBot implements TablePlayerAgent, SeatAgent {
  OfflineTeenPattiBot({
    TeenPattiEngine? engine,
    Random? random,
    BotProfileParams? defaultProfile,
  })  : _random = random ?? Random(),
        _defaultProfile = defaultProfile;

  final Random _random;
  final BotProfileParams? _defaultProfile;

  BotProfileParams _profileFor(TablePlayer self) {
    if (_defaultProfile != null) return _defaultProfile;
    return BotProfileParams.fromTag(self.personaTag);
  }

  @override
  Future<bool> shouldSeeCards({
    required TableState state,
    required TablePlayer self,
  }) {
    final observation =
        SeatObservation.fromTableState(state, viewerId: self.id);
    return shouldSeeCardsForObservation(
      observation: observation,
      profile: _profileFor(self),
    );
  }

  @override
  Future<AgentTurnDecision> decideAction({
    required TableState state,
    required TablePlayer self,
  }) {
    final observation =
        SeatObservation.fromTableState(state, viewerId: self.id);
    return decideActionForObservation(
      observation: observation,
      profile: _profileFor(self),
    );
  }

  @override
  Future<bool> decideSideShowResponse({
    required TableState state,
    required TablePlayer self,
    required TablePlayer requester,
  }) {
    final observation =
        SeatObservation.fromTableState(state, viewerId: self.id);
    return decideSideShowResponseForObservation(
      observation: observation,
      profile: _profileFor(self),
    );
  }

  @override
  Future<bool> shouldSeeCardsForObservation({
    required SeatObservation observation,
    required BotProfileParams profile,
  }) async {
    return BotDecisionEngine.shouldSeeCards(
      observation,
      profile,
      random: _random,
    );
  }

  @override
  Future<AgentTurnDecision> decideActionForObservation({
    required SeatObservation observation,
    required BotProfileParams profile,
  }) async {
    return BotDecisionEngine.decideAction(
      observation,
      profile,
      random: _random,
    );
  }

  @override
  Future<bool> decideSideShowResponseForObservation({
    required SeatObservation observation,
    required BotProfileParams profile,
  }) async {
    return BotDecisionEngine.decideSideShowResponse(
      observation,
      profile,
      random: _random,
    );
  }
}
