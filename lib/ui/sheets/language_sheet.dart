import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/locale_controller.dart';
import '../l10n.dart';
import '../theme.dart';

/// Picks the app language or goes back to the system language.
class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key});

  /// Language names are shown in their own language.
  static const names = {'en': 'English', 'ru': 'Русский', 'be': 'Беларуская'};

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<LocaleController>(),
      child: const LanguageSheet(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocaleController>();
    final selected = controller.locale?.languageCode;

    Widget option(String? code, String title) => ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: selected == code
          ? const Icon(Icons.check_rounded, color: AppTheme.accent)
          : null,
      onTap: () {
        controller.setLanguage(code);
        Navigator.of(context).pop();
      },
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                context.l10n.language,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            option(null, context.l10n.languageSystem),
            for (final code in supportedLanguages) option(code, names[code]!),
          ],
        ),
      ),
    );
  }
}
