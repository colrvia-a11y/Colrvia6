// lib/screens/interview_screen.dart
import 'package:flutter/material.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/create_flow_progress.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/services/interview_engine.dart';
import 'package:color_canvas/services/voice_assistant.dart';
import 'package:color_canvas/services/schema_interview_compiler.dart';
import 'package:color_canvas/widgets/interview_widgets.dart';
import 'package:color_canvas/screens/interview_review_screen.dart';
import 'package:color_canvas/widgets/photo_picker_inline.dart';

enum InterviewMode { text, talk }

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});
  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final JourneyService journey = JourneyService.instance;
  late InterviewEngine _engine; // built after schema load
  final _voice = VoiceAssistant();
  final _scroll = ScrollController();

  InterviewMode _mode = InterviewMode.text;
  InterviewDepth _depth = InterviewDepth.quick;

  final _messages = <_Message>[];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final compiler = await SchemaInterviewCompiler.loadFromAsset('assets/schemas/single-room-color-intake.json');
      final prompts = compiler.compile();
      _engine = InterviewEngine.fromPrompts(prompts);
    } catch (e) {
      // graceful fallback to demo prompts if asset missing or invalid
      _engine = InterviewEngine.demo();
      _loadError = 'Schema load failed, using fallback prompts.';
    }

    _engine.addListener(_onEngine);
    final seed = journey.state.value?.artifacts['answers'] as Map<String, dynamic>?;
    _engine.start(seedAnswers: seed, depth: _depth);

    _enqueueSystem(_engine.current?.title ?? "Let's get started");
    await _voice.init();

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    if (!_loading) _engine.removeListener(_onEngine);
    _voice.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onEngine() {
    CreateFlowProgress.instance.set('interview', _engine.progress);
    setState(() {});
  }

  void _enqueueSystem(String text) {
    setState(() => _messages.add(_Message.system(text)));
    _autoScroll();
  }

  void _enqueueUser(String text) {
    setState(() => _messages.add(_Message.user(text)));
    _autoScroll();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _persistAnswers() async {
    await journey.setArtifact('answers', _engine.answers);
  }

  Future<void> _finish() async {
    // Persist current answers
    await journey.setArtifact('answers', _engine.answers);
    await AnalyticsService.instance.logEvent('interview_completed');

    if (!mounted) return;
    // Navigate to Review (and await potential deep-link edit requests)
    final result = await Navigator.of(context).push<Map<String, String>?>( 
      MaterialPageRoute(
        builder: (_) => InterviewReviewScreen(engine: _engine),
        fullscreenDialog: true,
      ),
    );

    // If review asked to jump back to a specific prompt, do it and continue chat
    final jumpTo = result != null ? result['jumpTo'] : null;
    if (jumpTo != null && jumpTo.isNotEmpty) {
      _engine.jumpTo(jumpTo);
      if (_engine.current != null) {
        _enqueueSystem('Let\'s update: ${_engine.current!.title}');
        if (_mode == InterviewMode.talk) _voice.speak(_engine.current!.title);
      }
      return; // back to chat to edit
    }

    // If review confirmed (no jump back), the Review screen already completed the journey.
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _submitFreeText(String text) async {
    final prompt = _engine.current;
    if (prompt == null) return;

    _enqueueUser(text);
    _engine.setAnswer(prompt.id, text);
    await _persistAnswers();

    _engine.next();
    if (_engine.current != null) {
      _enqueueSystem(_engine.current!.title);
      if (_mode == InterviewMode.talk) {
        _voice.speak(_engine.current!.title);
      }
    } else {
      await _finish();
    }
  }

  Future<void> _selectSingle(String label) async {
    final prompt = _engine.current;
    if (prompt == null) return;
    _enqueueUser(label);

    final opt = prompt.options.firstWhere((o) => o.label == label, orElse: () => prompt.options.first);
    _engine.setAnswer(prompt.id, opt.value);
    await _persistAnswers();

    _engine.next();
    if (_engine.current != null) {
      _enqueueSystem(_engine.current!.title);
      if (_mode == InterviewMode.talk) {
        _voice.speak(_engine.current!.title);
      }
    } else {
      await _finish();
    }
  }

  // ---- Voice helpers (kept from Patch 2) ----
  final Map<String, List<String>> _synonyms = {
    'veryBright': ['very bright','tons of light','super bright','flooded'],
    'kindaBright': ['pretty bright','fairly bright','some light','medium bright'],
    'dim': ['dim','dark','little light','not much light'],
    'cozyYellow_2700K': ['warm bulbs','yellow light','2700','cozy'],
    'neutral_3000_3500K': ['neutral','3000','3500','soft white'],
    'brightWhite_4000KPlus': ['cool white','bright white','4000','daylight'],
    'loveIt': ['yes','love it','i like it','for sure'],
    'maybe': ['maybe','not sure','depends'],
    'noThanks': ['no','no thanks','skip it'],
  };

  String? _fuzzyValueFromSpeech(InterviewPrompt prompt, String heard) {
    final h = heard.toLowerCase();
    for (final o in prompt.options) {
      if (h.contains(o.label.toLowerCase())) return o.value;
    }
    for (final o in prompt.options) {
      final syns = _synonyms[o.value] ?? const [];
      if (syns.any((s) => h.contains(s))) return o.value;
    }
    return null;
  }

  Future<void> _handleTalkTap() async {
    final prompt = _engine.current;
    if (prompt == null) return;

    final heard = await _voice.listenOnce();
    if (heard == null || heard.isEmpty) return;

    switch (prompt.type) {
      case InterviewPromptType.singleSelect:
        final match = _fuzzyValueFromSpeech(prompt, heard);
        if (match != null) {
          final label = prompt.options.firstWhere((o) => o.value == match).label;
          await _selectSingle(label);
        } else {
          _enqueueSystem('I heard "$heard". Could you tap or say one of the options?');
          _voice.speak('Please choose one of the options on screen.');
        }
        break;
      case InterviewPromptType.freeText:
        await _submitFreeText(heard);
        break;
      case InterviewPromptType.multiSelect:
      case InterviewPromptType.yesNo:
        _enqueueSystem('Please tap to pick your choices.');
        _voice.speak('Please tap your choices.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Interview')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final prompt = _engine.current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SegmentedButton<InterviewMode>(
              segments: [
                ButtonSegment(value: InterviewMode.text, label: Text('Text'), icon: Icon(Icons.chat_bubble_outline)),
                ButtonSegment(value: InterviewMode.talk, label: Text('Talk'), icon: Icon(Icons.mic_none)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SegmentedButton<InterviewDepth>(
              segments: [
                ButtonSegment(value: InterviewDepth.quick, label: Text('Quick')),
                ButtonSegment(value: InterviewDepth.full, label: Text('Full')),
              ],
              selected: {_depth},
              onSelectionChanged: (s) {
                setState(() => _depth = s.first);
                _engine.setDepth(_depth);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: _engine.progress > 0 ? _engine.progress : null),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_loadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + 1,
                itemBuilder: (context, i) {
                  if (i < _messages.length) {
                    final m = _messages[i];
                    return ChatBubble(isUser: m.isUser, child: Text(m.text));
                  }

                  if (prompt == null) return const SizedBox();

                  final help = prompt.help != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(prompt.help!, style: Theme.of(context).textTheme.bodySmall),
                        )
                      : const SizedBox.shrink();

                  switch (prompt.type) {
                    case InterviewPromptType.singleSelect:
                      final labels = prompt.options.map((o) => o.label).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChatBubble(isUser: false, child: Text(prompt.title)),
                          const SizedBox(height: 8),
                          OptionChips(options: labels, onTap: _selectSingle),
                          help,
                        ],
                      );
                    case InterviewPromptType.multiSelect:
                      if (prompt.id == 'photos') {
                        final urls = (_engine.answers['photos'] as List?)?.cast<String>() ?? const <String>[];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChatBubble(isUser: false, child: Text(prompt.title)),
                            const SizedBox(height: 8),
                            PhotoPickerInline(
                              value: urls,
                              onChanged: (next) async {
                                _engine.setAnswer('photos', next);
                                await _persistAnswers();
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  _enqueueUser('Photos added');
                                  _engine.next();
                                  if (_engine.current != null) {
                                    _enqueueSystem(_engine.current!.title);
                                    if (_mode == InterviewMode.talk) _voice.speak(_engine.current!.title);
                                  } else {
                                    await _finish();
                                  }
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Continue'),
                              ),
                            ]),
                          ],
                        );
                      }
                      final labels = prompt.options.map((o) => o.label).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChatBubble(isUser: false, child: Text(prompt.title)),
                          const SizedBox(height: 8),
                          MultiSelectChips(
                            options: labels,
                            minItems: prompt.minItems,
                            maxItems: prompt.maxItems,
                            onChanged: (vals) {
                              final values = vals
                                  .map((l) => prompt.options.firstWhere((o) => o.label == l).value)
                                  .toList();
                              _engine.setAnswer(prompt.id, values);
                              _persistAnswers();
                            },
                          ),
                          help,
                          const SizedBox(height: 8),
                          Row(children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                _enqueueUser('Selections updated');
                                _engine.next();
                                if (_engine.current != null) {
                                  _enqueueSystem(_engine.current!.title);
                                  if (_mode == InterviewMode.talk) _voice.speak(_engine.current!.title);
                                } else {
                                  await _finish();
                                }
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Continue'),
                            ),
                          ]),
                        ],
                      );
                    case InterviewPromptType.yesNo:
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChatBubble(isUser: false, child: Text(prompt.title)),
                          const SizedBox(height: 8),
                          OptionChips(options: const ['Yes','No'], onTap: (val) => _selectSingle(val)),
                          help,
                        ],
                      );
                    case InterviewPromptType.freeText:
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChatBubble(isUser: false, child: Text(prompt.title)),
                          const SizedBox(height: 8),
                          help,
                          const SizedBox(height: 8),
                          _mode == InterviewMode.text
                              ? _TextComposer(onSubmit: _submitFreeText)
                              : _TalkComposer(onMic: _handleTalkTap, isListening: _voice.isListening, isSpeaking: _voice.isSpeaking),
                        ],
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message.user(this.text) : isUser = true;
  _Message.system(this.text) : isUser = false;
}

class _TextComposer extends StatefulWidget {
  final Future<void> Function(String) onSubmit;
  const _TextComposer({required this.onSubmit});
  @override
  State<_TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<_TextComposer> {
  final _controller = TextEditingController();
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Type your answer…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.arrow_upward),
          label: const Text('Send'),
        ),
      ],
    );
  }
  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    await widget.onSubmit(text);
    _controller.clear();
    setState(() => _busy = false);
  }
}

class _TalkComposer extends StatelessWidget {
  final VoidCallback onMic;
  final bool isListening;
  final bool isSpeaking;
  const _TalkComposer({required this.onMic, required this.isListening, required this.isSpeaking});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(isListening ? 'Listening…' : (isSpeaking ? 'Speaking…' : 'Tap the mic and answer')),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onMic,
          icon: Icon(isListening ? Icons.hearing : Icons.mic),
          label: Text(isListening ? 'Listening' : 'Speak'),
        ),
      ],
    );
  }
}
