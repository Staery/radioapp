import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../state/radio_controller.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Language code of the current UI locale: "en", "ru" or "be".
  String get languageCode => Localizations.localeOf(this).languageCode;
}

/// Localized genre name: "retro" → "Retro" / "Ретро" / "Рэтра".
String genreLabel(AppLocalizations l10n, String genre) => switch (genre) {
  'rock' => l10n.genreRock,
  'jazz' => l10n.genreJazz,
  'pop' => l10n.genrePop,
  'retro' => l10n.genreRetro,
  'humor' => l10n.genreHumor,
  'indie' => l10n.genreIndie,
  'chill' => l10n.genreChill,
  _ => genre.isEmpty ? genre : genre[0].toUpperCase() + genre.substring(1),
};

/// Text shown after a voice command.
String voiceReplyText(AppLocalizations l10n, VoiceReply reply) {
  final station = reply.station?.name ?? '';
  return switch (reply.kind) {
    VoiceReplyKind.playing => l10n.replyPlaying(station),
    VoiceReplyKind.playingGenre => l10n.replyPlayingGenre(
      genreLabel(l10n, reply.genre ?? ''),
      station,
    ),
    VoiceReplyKind.stopped => l10n.replyStopped,
    VoiceReplyKind.favoriteAdded => l10n.replyFavoriteAdded(station),
    VoiceReplyKind.favoriteRemoved => l10n.replyFavoriteRemoved(station),
    VoiceReplyKind.nothingSelected => l10n.replyNothingSelected,
    VoiceReplyKind.notHeard => l10n.replyNotHeard,
    VoiceReplyKind.unknown => l10n.replyUnknown(reply.phrase ?? ''),
  };
}
