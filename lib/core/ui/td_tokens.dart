import 'package:flutter/material.dart';

/// Design tokens for the TimeDock visual language: a polished, card-based
/// dashboard look with semantic status colours that stay consistent across
/// workspaces (the workspace seed still tints the Material [ColorScheme]).
///
/// Attached to [ThemeData.extensions]; read via `context.td`.
@immutable
class TdTokens extends ThemeExtension<TdTokens> {
  const TdTokens({
    required this.canvas,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.track,
    required this.faint,
    required this.good,
    required this.goodBg,
    required this.goodInk,
    required this.warn,
    required this.warnBg,
    required this.warnInk,
    required this.crit,
    required this.critBg,
    required this.critInk,
    required this.info,
    required this.infoBg,
    required this.infoInk,
    required this.accent2,
    required this.cardShadow,
  });

  /// Scaffold background — a cool off-white / deep slate.
  final Color canvas;

  /// Primary card surface and a slightly tinted inner surface.
  final Color card;
  final Color cardAlt;

  /// Hairline border for cards and rows.
  final Color border;

  /// Track behind progress bars and donut rings.
  final Color track;

  /// Muted label / caption colour (eyebrows, meta).
  final Color faint;

  // Semantic status trio: line colour, tinted background, readable ink.
  final Color good, goodBg, goodInk;
  final Color warn, warnBg, warnInk;
  final Color crit, critBg, critInk;
  final Color info, infoBg, infoInk;

  /// Secondary brand accent (violet) used in gradients alongside the primary.
  final Color accent2;

  /// Soft elevation used on cards.
  final List<BoxShadow> cardShadow;

  static const _lightShadow = [
    BoxShadow(color: Color(0x14142040), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1A1B2A55), blurRadius: 22, offset: Offset(0, 10)),
  ];
  static const _darkShadow = [
    BoxShadow(color: Color(0x59000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x66000000), blurRadius: 34, offset: Offset(0, 14)),
  ];

  factory TdTokens.light() => const TdTokens(
        canvas: Color(0xFFE4E9F3),
        card: Color(0xFFFFFFFF),
        cardAlt: Color(0xFFEFF3FA),
        border: Color(0xFFD4DCEA),
        track: Color(0xFFE1E7F1),
        faint: Color(0xFF77809A),
        good: Color(0xFF1FA971),
        goodBg: Color(0xFFE7F6EF),
        goodInk: Color(0xFF0E7C50),
        warn: Color(0xFFDE9412),
        warnBg: Color(0xFFFBF2DF),
        warnInk: Color(0xFF8F6109),
        crit: Color(0xFFE0464B),
        critBg: Color(0xFFFBE8E8),
        critInk: Color(0xFFAC2429),
        info: Color(0xFF3B82C4),
        infoBg: Color(0xFFE7F1FA),
        infoInk: Color(0xFF215B8C),
        accent2: Color(0xFF7C5CFC),
        cardShadow: _lightShadow,
      );

  factory TdTokens.dark() => const TdTokens(
        canvas: Color(0xFF0E1320),
        card: Color(0xFF171E2C),
        cardAlt: Color(0xFF1E2636),
        border: Color(0xFF252F3E),
        track: Color(0xFF232C3C),
        faint: Color(0xFF6B7587),
        good: Color(0xFF33B37E),
        goodBg: Color(0xFF12271F),
        goodInk: Color(0xFF63D6A5),
        warn: Color(0xFFE0A53C),
        warnBg: Color(0xFF2A2314),
        warnInk: Color(0xFFF0C468),
        crit: Color(0xFFEC6067),
        critBg: Color(0xFF2C191B),
        critInk: Color(0xFFF49B9F),
        info: Color(0xFF5AA0DA),
        infoBg: Color(0xFF14232F),
        infoInk: Color(0xFF92C6EF),
        accent2: Color(0xFF9E86FF),
        cardShadow: _darkShadow,
      );

  @override
  TdTokens copyWith() => this;

  @override
  TdTokens lerp(ThemeExtension<TdTokens>? other, double t) {
    if (other is! TdTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return TdTokens(
      canvas: c(canvas, other.canvas),
      card: c(card, other.card),
      cardAlt: c(cardAlt, other.cardAlt),
      border: c(border, other.border),
      track: c(track, other.track),
      faint: c(faint, other.faint),
      good: c(good, other.good),
      goodBg: c(goodBg, other.goodBg),
      goodInk: c(goodInk, other.goodInk),
      warn: c(warn, other.warn),
      warnBg: c(warnBg, other.warnBg),
      warnInk: c(warnInk, other.warnInk),
      crit: c(crit, other.crit),
      critBg: c(critBg, other.critBg),
      critInk: c(critInk, other.critInk),
      info: c(info, other.info),
      infoBg: c(infoBg, other.infoBg),
      infoInk: c(infoInk, other.infoInk),
      accent2: c(accent2, other.accent2),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

/// Convenience accessors for theme, tokens and common text styles.
extension TdContext on BuildContext {
  TdTokens get td =>
      Theme.of(this).extension<TdTokens>() ?? TdTokens.light();
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
}
