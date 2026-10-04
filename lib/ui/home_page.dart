import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/radio_controller.dart';
import 'l10n.dart';
import 'sheets/language_sheet.dart';
import 'sheets/scope_sheet.dart';
import 'sheets/sleep_timer_sheet.dart';
import 'sheets/stations_sheet.dart';
import 'sheets/voice_sheet.dart';
import 'theme.dart';
import 'widgets/player_panel.dart';
import 'widgets/station_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController(viewportFraction: 0.84);
  RadioController? _radio;
  String? _lastError;
  String? _lastFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final radio = context.read<RadioController>();
    if (_radio != radio) {
      _radio?.removeListener(_syncPage);
      _radio = radio..addListener(_syncPage);
    }
  }

  @override
  void dispose() {
    _radio?.removeListener(_syncPage);
    _pageController.dispose();
    super.dispose();
  }

  /// Keeps the carousel on the selected station when the selection changes
  /// from elsewhere (buttons, voice, the station list), and shows errors.
  void _syncPage() {
    final radio = _radio!;
    if (_pageController.hasClients) {
      final target = radio.selectedIndex;
      final page = _pageController.page?.round();
      if (radio.filter != _lastFilter) {
        // A new filter means a new list: jump instead of animating through it.
        _lastFilter = radio.filter;
        if (page != target) _pageController.jumpToPage(target);
      } else if (page != null && (page - target).abs() > 3) {
        _pageController.jumpToPage(target);
      } else if (page != null && page != target) {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    }
    final failed = radio.failedStation;
    final error = failed == null ? null : context.l10n.streamError(failed.name);
    if (error != null && error != _lastError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
    _lastError = error;
  }

  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioController>();
    final accent = radio.selected?.color ?? AppTheme.accent;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _ToggleIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _NextIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _PreviousIntent(),
      },
      child: Actions(
        actions: {
          _ToggleIntent: CallbackAction<_ToggleIntent>(
            onInvoke: (_) => radio.toggle(),
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (_) => radio.next(),
          ),
          _PreviousIntent: CallbackAction<_PreviousIntent>(
            onInvoke: (_) => radio.previous(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -1.1),
                  radius: 1.5,
                  colors: [accent.withValues(alpha: 0.45), AppTheme.background],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _body(context, radio),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, RadioController radio) {
    if (!radio.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (radio.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.loadError(radio.loadError!),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final visible = radio.visibleStations;
    return Column(
      children: [
        _Header(
          stationCount: radio.scopedStations.length,
          sleepOn: radio.sleepAt != null,
          busy:
              radio.catalogStatus == CatalogStatus.loading ||
              radio.isCheckingStreams,
        ),
        _GenreChips(radio: radio),
        const SizedBox(height: 12),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(favorites: radio.filter == favoritesFilter)
              : PageView.builder(
                  controller: _pageController,
                  itemCount: visible.length,
                  onPageChanged: radio.select,
                  itemBuilder: (context, index) {
                    final station = visible[index];
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        var distance = 0.0;
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          distance = ((_pageController.page ?? 0) - index)
                              .abs()
                              .clamp(0, 1);
                        }
                        return Transform.scale(
                          scale: 1 - distance * 0.08,
                          child: Opacity(
                            opacity: 1 - distance * 0.35,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: StationCard(
                          station: station,
                          isFavorite: radio.isFavorite(station),
                          isPlaying: radio.isCurrent(station),
                          onTap: () => radio.isCurrent(station)
                              ? radio.stop()
                              : radio.play(station),
                          onFavorite: () => radio.toggleFavorite(station),
                          available: radio.isAvailable(station),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (visible.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _PageDots(count: visible.length, index: radio.selectedIndex),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: PlayerPanel(onVoice: () => VoiceSheet.show(context)),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.stationCount,
    required this.sleepOn,
    required this.busy,
  });

  final int stationCount;
  final bool sleepOn;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.radio_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.appTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.headerSubtitle(stationCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (busy) ...[
                      const SizedBox(width: 6),
                      const SizedBox.square(
                        dimension: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.language,
            onPressed: () => LanguageSheet.show(context),
            icon: const Icon(Icons.translate_rounded),
          ),
          IconButton(
            tooltip: context.l10n.sleepTimer,
            onPressed: () => SleepTimerSheet.show(context),
            icon: Icon(
              sleepOn ? Icons.bedtime_rounded : Icons.bedtime_outlined,
            ),
          ),
          IconButton(
            tooltip: context.l10n.allStations,
            onPressed: () => StationsSheet.show(context),
            icon: const Icon(Icons.format_list_bulleted_rounded),
          ),
        ],
      ),
    );
  }
}

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.radio});

  final RadioController radio;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget chip(String label, String? value, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16),
        label: Text(label),
        selected: radio.filter == value,
        onSelected: (_) => radio.setFilter(value),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(ScopeSheet.iconFor(radio.scope), size: 16),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(scopeLabel(l10n, radio.scope)),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
              tooltip: l10n.scopeTitle,
              side: const BorderSide(color: AppTheme.accent),
              onPressed: () => ScopeSheet.show(context),
            ),
          ),
          chip(l10n.filterAll, null),
          chip(
            l10n.filterFavorites,
            favoritesFilter,
            icon: Icons.favorite_rounded,
          ),
          for (final genre in radio.genres)
            chip(genreLabel(l10n, genre), genre),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count > 12) {
      return Text(
        '${index + 1} / $count',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? AppTheme.textPrimary : AppTheme.outline,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.favorites});

  final bool favorites;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              favorites ? Icons.favorite_border_rounded : Icons.radio_rounded,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              favorites ? l10n.noFavoritesTitle : l10n.noStationsTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              favorites ? l10n.noFavoritesHint : l10n.noStationsHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}
