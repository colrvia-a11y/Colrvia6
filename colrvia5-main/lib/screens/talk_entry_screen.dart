import 'package:flutter/material.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/live_talk_service.dart';
import 'package:color_canvas/screens/live_talk_call_screen.dart';

class TalkEntryScreen extends StatefulWidget { const TalkEntryScreen({super.key}); @override State<TalkEntryScreen> createState() => _TalkEntryScreenState(); }
class _TalkEntryScreenState extends State<TalkEntryScreen> {
  DateTime? _scheduled;
  bool _busy = false;

  Future<void> _startNow() async {
    setState(() => _busy = true);
    final answers = JourneyService.instance.state.value?.artifacts['answers'] as Map<String, dynamic>?;
    final sessionId = await LiveTalkService.instance.createSession(answers: answers);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveTalkCallScreen(sessionId: sessionId)));
    setState(() => _busy = false);
  }

  Future<void> _schedule() async {
    setState(() => _busy = true);
    final when = _scheduled ?? DateTime.now().add(const Duration(hours: 2));
    final answers = JourneyService.instance.state.value?.artifacts['answers'] as Map<String, dynamic>?;
    await LiveTalkService.instance.createSession(answers: answers, when: when);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled! We’ll remind you.')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Call')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Talk through your interview', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Choose start now or schedule a time. You can switch back to text any time.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _busy ? null : _startNow, icon: const Icon(Icons.call), label: const Text('Start now')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _schedule, icon: const Icon(Icons.calendar_today), label: const Text('Schedule for later'))),
          ]),
        ]),
      ),
    );
  }
}
