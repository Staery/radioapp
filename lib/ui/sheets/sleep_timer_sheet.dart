import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/radio_controller.dart';
import '../theme.dart';
import '../l10n.dart';

/// Lets the user stop playback after a while.
class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  static const options = [15, 30, 45, 60, 90];

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<RadioController>(),
      child: const SleepTimerSheet(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioController>();
    final sleepAt = radio.sleepAt;
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sleepTimer,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              sleepAt == null
                  ? l10n.sleepHintOff
                  : l10n.sleepHintOn(
                      TimeOfDay.fromDateTime(sleepAt).format(context),
                    ),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in options)
                  ActionChip(
                    avatar: const Icon(Icons.bedtime_outlined, size: 18),
                    label: Text(l10n.minutes(minutes)),
                    onPressed: () {
                      radio.setSleepTimer(Duration(minutes: minutes));
                      Navigator.of(context).pop();
                    },
                  ),
                if (sleepAt != null)
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l10n.turnOff),
                    onPressed: () {
                      radio.setSleepTimer(null);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
