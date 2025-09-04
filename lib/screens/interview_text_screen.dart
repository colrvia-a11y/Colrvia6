// lib/screens/interview_text_screen.dart
import 'package:flutter/material.dart';
import 'package:color_canvas/services/interview_shared_engine.dart';
import 'package:color_canvas/widgets/user_bubble.dart';
import 'package:color_canvas/widgets/via_bubble.dart';

class InterviewTextScreen extends StatefulWidget {
  const InterviewTextScreen({super.key});

  @override
  State<InterviewTextScreen> createState() => _InterviewTextScreenState();
}

class _InterviewTextScreenState extends State<InterviewTextScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final InterviewEngine engine = InterviewEngine();

  @override
  void initState() {
    super.initState();
    engine.startTextMode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    engine.endSession();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> submitAnswer() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    await engine.submitTextAnswer(text);
    setState(() {});
    _scrollToBottom();
  }

  Future<void> showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Interview?'),
        content: const Text('Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (shouldExit == true) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Via Interview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => showExitDialog(context),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: engine.initialTurns.isEmpty
                ? const Center(child: Text('No questions loaded'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: engine.initialTurns.length,
                    itemBuilder: (context, index) {
                      final turn = engine.initialTurns[index];
                      return turn.isUser
                          ? UserBubble(text: turn.text)
                          : ViaBubble(text: turn.text);
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => submitAnswer(),
                    decoration: InputDecoration(
                      hintText: 'Type your answer…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: submitAnswer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
