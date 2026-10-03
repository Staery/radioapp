import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/radio_controller.dart';
import '../theme.dart';
import 'equalizer.dart';
import '../l10n.dart';

/// Status line, transport controls and the voice button.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key, required this.onVoice});

  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioController>();
    final l10n = context.l10n;
    final selected = radio.selected;
    final accent = selected?.color ?? AppTheme.accent;
    final isSelectedActive = radio.isActive && radio.current == selected;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusLine(radio: radio),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                icon: Icons.skip_previous_rounded,
                tooltip: l10n.previousStation,
                onPressed: radio.visibleStations.length > 1
                    ? radio.previous
                    : null,
              ),
              const SizedBox(width: 22),
              _PlayButton(
                color: accent,
                loading:
                    isSelectedActive && radio.status == PlaybackStatus.loading,
                playing: isSelectedActive,
                onPressed: selected == null ? null : radio.toggle,
              ),
              const SizedBox(width: 22),
              _RoundButton(
                icon: Icons.skip_next_rounded,
                tooltip: l10n.nextStation,
                onPressed: radio.visibleStations.length > 1 ? radio.next : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onVoice,
              icon: const Icon(Icons.mic_rounded, size: 20),
              label: Text(l10n.voiceButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.outline),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.radio});

  final RadioController radio;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.languageCode;
    final current = radio.current?.name ?? '';
    final (
      String title,
      String? subtitle,
      Color color,
    ) = switch (radio.status) {
      PlaybackStatus.playing => (
        l10n.statusLive(current),
        radio.trackTitle,
        const Color(0xFF4ADE80),
      ),
      PlaybackStatus.loading => (
        l10n.statusConnecting(current),
        null,
        AppTheme.textSecondary,
      ),
      PlaybackStatus.error => (
        l10n.statusUnavailable,
        l10n.streamError(radio.failedStation?.name ?? current),
        AppTheme.danger,
      ),
      PlaybackStatus.idle => (
        l10n.statusIdle,
        radio.selected?.description.of(lang),
        AppTheme.textSecondary,
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: radio.status == PlaybackStatus.playing
              ? Equalizer(active: true, color: color, size: 16)
              : Icon(
                  radio.status == PlaybackStatus.error
                      ? Icons.error_outline_rounded
                      : Icons.radio_rounded,
                  size: 18,
                  color: color,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (radio.sleepAt != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.sleepTimerOn,
            child: const Icon(
              Icons.bedtime_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.color,
    required this.loading,
    required this.playing,
    required this.onPressed,
  });

  final Color color;
  final bool loading;
  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing ? context.l10n.stop : context.l10n.play,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (loading)
                  const SizedBox.square(
                    dimension: 70,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 30,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surfaceHigh,
        foregroundColor: AppTheme.textPrimary,
        fixedSize: const Size(56, 56),
      ),
      icon: Icon(icon),
    );
  }
}
