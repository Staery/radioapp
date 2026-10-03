import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/radio_controller.dart';
import '../../voice/voice_command.dart';
import '../../voice/voice_input.dart';
import '../theme.dart';
import '../l10n.dart';

/// Listens for a spoken command, or accepts a typed one, and runs it.
class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key, this.autoListen = true});

  final bool autoListen;

  /// Speech recogniser locale for each app language.
  static const speechLocales = {'en': 'en_US', 'ru': 'ru_RU', 'be': 'be_BY'};

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<RadioController>()),
        Provider.value(value: context.read<VoiceInput>()),
      ],
      child: const VoiceSheet(),
    ),
  );

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

enum _Phase { starting, listening, done, unavailable }

class _VoiceSheetState extends State<VoiceSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  final _textController = TextEditingController();
  _Phase _phase = _Phase.starting;
  String _heard = '';
  VoiceReply? _reply;
  String? _locale;
  Timer? _closeTimer;
  late final VoiceInput _voice;

  @override
  void initState() {
    super.initState();
    _voice = context.read<VoiceInput>();
    if (!widget.autoListen) _phase = _Phase.done;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locale != null) return;
    // Listen in the app language by default.
    _locale = VoiceSheet.speechLocales[context.languageCode] ?? 'en_US';
    if (widget.autoListen) unawaited(_listen());
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _pulse.dispose();
    _textController.dispose();
    unawaited(_voice.stop());
    super.dispose();
  }

  Future<void> _listen() async {
    final voice = _voice;
    setState(() {
      _phase = _Phase.starting;
      _heard = '';
      _reply = null;
    });
    if (!await voice.initialize()) {
      if (mounted) setState(() => _phase = _Phase.unavailable);
      return;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.listening);
    unawaited(_pulse.repeat(reverse: true));
    await voice.listen(
      localeId: _locale,
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() => _heard = words);
        if (isFinal) unawaited(_run(words));
      },
    );
  }

  Future<void> _run(String phrase) async {
    _pulse.stop();
    final radio = context.read<RadioController>();
    final command = VoiceCommandParser(radio.stations).parse(phrase);
    final reply = await radio.execute(command);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.done;
      _heard = phrase;
      _reply = reply;
    });
    if (command is! UnknownCommand) {
      _closeTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listening = _phase == _Phase.listening;
    final reply = _reply;
    final status = switch (_phase) {
      _Phase.starting => l10n.voicePreparing,
      _Phase.listening => _heard.isEmpty ? l10n.voiceListening : '“$_heard”',
      _Phase.done =>
        reply == null ? l10n.voiceTapMic : voiceReplyText(l10n, reply),
      _Phase.unavailable => l10n.voiceUnavailable,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.voiceTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      for (final entry in VoiceSheet.speechLocales.entries)
                        ButtonSegment(
                          value: entry.value,
                          label: Text(entry.key.toUpperCase()),
                        ),
                    ],
                    selected: {_locale ?? 'en_US'},
                    onSelectionChanged: (value) {
                      setState(() => _locale = value.first);
                      if (_phase != _Phase.unavailable) unawaited(_listen());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _phase == _Phase.unavailable ? null : _listen,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final glow = listening ? 12 + 18 * _pulse.value : 0.0;
                    return Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.5),
                            blurRadius: 10 + glow,
                            spreadRadius: glow / 3,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Icon(
                    _phase == _Phase.unavailable
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  status,
                  key: ValueKey(status),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  if (value.trim().isEmpty) return;
                  _textController.clear();
                  unawaited(_run(value));
                },
                decoration: InputDecoration(
                  hintText: l10n.voiceTypeHint,
                  prefixIcon: const Icon(Icons.keyboard_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final example in l10n.voiceExamples.split('|'))
                    ActionChip(
                      label: Text(
                        example,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onPressed: () => _run(example),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
