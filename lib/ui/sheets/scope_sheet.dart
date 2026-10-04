import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/station_scope.dart';
import '../../state/radio_controller.dart';
import '../l10n.dart';
import '../theme.dart';

/// Chooses which stations to show: all, featured, a country or a language,
/// and whether to hide stations that do not work from this network.
class ScopeSheet extends StatelessWidget {
  const ScopeSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<RadioController>(),
      child: const ScopeSheet(),
    ),
  );

  static IconData iconFor(StationScope scope) => switch (scope.key) {
    'featured' => Icons.auto_awesome_rounded,
    'country:BY' || 'country:RU' => Icons.flag_rounded,
    'language:ru' || 'language:be' || 'language:en' => Icons.translate_rounded,
    _ => Icons.public_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioController>();
    final l10n = context.l10n;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                l10n.scopeTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final scope in StationScope.values)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(iconFor(scope), color: AppTheme.textSecondary),
                title: Text(
                  scopeLabel(l10n, scope),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.stationCount(radio.countIn(scope)),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                trailing: radio.scope == scope
                    ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                    : null,
                onTap: () {
                  radio.setScope(scope);
                  Navigator.of(context).pop();
                },
              ),
            const Divider(height: 24, color: AppTheme.outline),
            SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              value: radio.hideUnavailable,
              onChanged: radio.setHideUnavailable,
              title: Text(
                l10n.hideUnavailable,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.hideUnavailableHint,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _CatalogStatusLine(radio: radio),
          ],
        ),
      ),
    );
  }
}

class _CatalogStatusLine extends StatelessWidget {
  const _CatalogStatusLine({required this.radio});

  final RadioController radio;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy =
        radio.catalogStatus == CatalogStatus.loading || radio.isCheckingStreams;
    final failed = radio.catalogStatus == CatalogStatus.failed;
    final text = switch (radio.catalogStatus) {
      CatalogStatus.loading => l10n.catalogUpdating,
      CatalogStatus.failed => l10n.catalogFailed,
      _ => radio.isCheckingStreams ? l10n.checkingStreams : l10n.catalogSource,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              failed ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
              size: 18,
              color: failed ? AppTheme.danger : AppTheme.textSecondary,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: () => radio.refreshCatalog(force: true),
              child: Text(l10n.retry),
            ),
        ],
      ),
    );
  }
}
