import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:color_canvas/services/interview_engine.dart';
import 'package:color_canvas/services/schema_interview_compiler.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/screens/interview_review_screen.dart';
import '../theme.dart';

/// One-question-per-screen onboarding wizard backed by InterviewEngine.
class InterviewWizardScreen extends StatefulWidget {
  const InterviewWizardScreen({super.key});
  @override
  State<InterviewWizardScreen> createState() => _InterviewWizardScreenState();
}

class _InterviewWizardScreenState extends State<InterviewWizardScreen> {
  late InterviewEngine _engine;
  bool _loading = true;
  String? _error;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final compiler = await SchemaInterviewCompiler
          .loadFromAsset('assets/schemas/single-room-color-intake.json');
      final prompts = compiler.buildPrompts();
      _engine = InterviewEngine.fromPrompts(prompts);
      final seed = JourneyService.instance.state.value?.artifacts['answers']
          as Map<String, dynamic>?;
      _engine.start(seedAnswers: seed, depth: InterviewDepth.quick);
      _syncTextToPrompt();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await JourneyService.instance.setArtifact('answers', _engine.answers);
  }

  void _syncTextToPrompt() {
    final p = _engine.current;
    if (p?.type == InterviewPromptType.freeText) {
      _textController.text =
          (_engine.answers[p!.id] as String?)?.trim() ?? '';
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    } else {
      _textController.clear();
    }
  }

  Future<void> _next() async {
    final p = _engine.current;
    if (p == null) return;

    // Commit free text before advancing
    if (p.type == InterviewPromptType.freeText) {
      _engine.setAnswer(p.id, _textController.text.trim());
      await _persist();
    }

    final isLast = (_engine.index >= _engine.total - 1);
    if (isLast) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InterviewReviewScreen(engine: _engine),
          fullscreenDialog: true,
        ),
      );
      setState(() {}); // refresh in case of edits
      return;
    }

    _engine.next();
    _syncTextToPrompt();
    setState(() {});
  }

  void _prev() {
    if (_engine.index > 0) {
      _engine.prev();
      _syncTextToPrompt();
      setState(() {});
    } else {
      Navigator.maybePop(context);
    }
  }

  bool _isValid(InterviewPrompt p) {
    final v = _engine.answers[p.id];
    if (p.required != true) {
      // Only enforce multi-select upper bounds for non-required prompts.
      if (p.type == InterviewPromptType.multiSelect && p.maxItems != null) {
        final list = (v as List?)?.cast<String>() ?? const <String>[];
        return list.length <= p.maxItems!;
      }
      return true;
    }
    switch (p.type) {
      case InterviewPromptType.singleSelect:
      case InterviewPromptType.yesNo:
        return v is String && v.trim().isNotEmpty;
      case InterviewPromptType.freeText:
        final txt = p.type == InterviewPromptType.freeText
            ? (_textController.text.trim())
            : (v as String? ?? '');
        return txt.isNotEmpty;
      case InterviewPromptType.multiSelect:
        final list = (v as List?)?.cast<String>() ?? const <String>[];
        if (p.minItems != null && list.length < p.minItems!) return false;
        if (p.maxItems != null && list.length > p.maxItems!) return false;
        return true;
    }
  }

  Future<void> _selectSingle(InterviewPrompt p, String value) async {
    _engine.setAnswer(p.id, value);
    await _persist();
    setState(() {});
  }

  Future<void> _toggleMulti(InterviewPrompt p, String value) async {
    final cur = (_engine.answers[p.id] as List?)?.cast<String>() ?? <String>[];
    final picked = List<String>.from(cur);
    if (picked.contains(value)) {
      picked.remove(value);
    } else {
      if (p.maxItems != null && picked.length >= p.maxItems!) return;
      picked.add(value);
    }
    _engine.setAnswer(p.id, picked);
    await _persist();
    setState(() {});
  }

  Future<void> _preferNot(InterviewPrompt p) async {
    // Remove any existing answer and advance
    try {
      _engine.clearAnswer(p.id);
    } catch (_) {
      // Fallback: set empty list/string; review screen tolerates missing/empty.
      if (p.isArray == true) {
        _engine.setAnswer(p.id, <String>[]);
      } else {
        _engine.setAnswer(p.id, '');
      }
    }
    await _persist();
    _next();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }

    final p = _engine.current;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _prev,
        ),
        title: const SizedBox.shrink(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: _engine.progress),
              const SizedBox(height: 16),
              if (p != null) ...[
                Text(
                  p.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (p.help != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    p.help!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(child: _answerSurface(p)),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: math.max(
              16,
              MediaQuery.of(context).viewInsets.bottom,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p != null && p.required == false)
                TextButton(
                  onPressed: () => _preferNot(p),
                  child: const Text('Prefer not to answer'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: (p != null && _isValid(p)) ? _next : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(
                  (_engine.index >= _engine.total - 1) ? 'Finish' : 'Continue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerSurface(InterviewPrompt p) {
    switch (p.type) {
      case InterviewPromptType.singleSelect:
      case InterviewPromptType.yesNo:
        final selected = _engine.answers[p.id] as String?;
        return ListView.separated(
          itemCount: p.options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final opt = p.options[i];
            final isSel = selected == opt.value;
            return _ChoiceCard(
              label: opt.label,
              selected: isSel,
              onTap: () => _selectSingle(p, opt.value),
            );
          },
        );
      case InterviewPromptType.multiSelect:
        final picked =
            (_engine.answers[p.id] as List?)?.cast<String>() ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: p.options.map((opt) {
                final isSel = picked.contains(opt.value);
                return _ChipCard(
                  label: opt.label,
                  selected: isSel,
                  onTap: () => _toggleMulti(p, opt.value),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (p.maxItems != null)
              Text(
                '${picked.length}/${p.maxItems} selected',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        );
      case InterviewPromptType.freeText:
        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _textController,
              autofocus: true,
              minLines: 1,
              maxLines: 6,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: "We'd love to know!",
                border: InputBorder.none,
              ),
              onChanged: (txt) {
                _engine.setAnswer(p.id, txt);
              },
            ),
          ),
        );
    }
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? theme.primaryContainer : theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.primary : theme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: theme.primary.withOpacity(.25), blurRadius: 10)]
              : const [],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _ChipCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChipCard({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? theme.primaryContainer : theme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? theme.primary : theme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

