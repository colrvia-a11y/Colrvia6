// lib/screens/interview_voice_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:color_canvas/services/live_talk_service.dart';
import 'package:color_canvas/services/live_talk_types.dart' as lt;
import 'package:color_canvas/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/services/live_talk_recorder.dart';
import 'package:color_canvas/services/errors.dart';
import 'package:permission_handler/permission_handler.dart';

class InterviewVoiceScreen extends StatefulWidget {
  const InterviewVoiceScreen({super.key});

  @override
  State<InterviewVoiceScreen> createState() => _InterviewVoiceScreenState();
}

class _InterviewVoiceScreenState extends State<InterviewVoiceScreen>
    with SingleTickerProviderStateMixin {
  late final LiveTalkService _talk = LiveTalkService.instance;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
        ..repeat(reverse: true);

  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _finalSub;
  String _partial = '';
  final List<String> _assistantTurns = <String>[];
  LiveTalkTranscriptAdapter? _recorder;

  @override
  void initState() {
    super.initState();
    _partialSub = _talk.partialText.stream.listen((t) {
      setState(() => _partial = t);
    });
    _finalSub = _talk.finalText.stream.listen((t) {
      setState(() {
        if (t.trim().isNotEmpty) _assistantTurns.add(t.trim());
        _partial = '';
      });
    });
    _recorder = LiveTalkTranscriptAdapter(_talk)..start();
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _finalSub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _endCall() async {
    // Fire analytics end event
    final started = _talk.sessionStartedAt ?? DateTime.now();
    final durSec = DateTime.now().difference(started).inSeconds;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    await AnalyticsService.instance.voiceSessionEnd(
      uid: uid,
      durationSec: durSec,
      turns: _assistantTurns.length,
      path: _talk.mode.value,
    );
    final rec = _recorder;
    await _talk.disconnect();
    if (rec != null) {
      try { await rec.stopAndPersist(); } catch (_) {}
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  String _statusLabel({
    required lt.LiveTalkConnectionState state,
    required bool speaking,
    required bool reconnecting,
    required String mode,
  }) {
    String base;
    if (reconnecting) {
      base = 'Reconnecting';
    } else {
      switch (state) {
        case lt.LiveTalkConnectionState.connecting:
          base = 'Connecting';
          break;
        case lt.LiveTalkConnectionState.connected:
          base = speaking ? 'Speaking' : 'Listening';
          break;
        case lt.LiveTalkConnectionState.error:
          base = 'Error';
          break;
        case lt.LiveTalkConnectionState.disconnected:
        default:
          base = 'Disconnected';
      }
    }
    if (mode == 'ws-fallback') {
      // Show small hint that we are on the fallback path
      base = '$base - Fallback WS';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        final rec = _recorder;
        try { await _talk.disconnect(); } catch (_) {}
        if (rec != null) {
          try { await rec.stopAndPersist(); } catch (_) {}
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Via Interview'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _endCall,
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status pill
              ValueListenableBuilder<lt.LiveTalkConnectionState>(
                valueListenable: _talk.connectionState,
                builder: (context, s, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _talk.assistantSpeaking,
                    builder: (context, speaking, __) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _talk.reconnecting,
                        builder: (context, reconnecting, ___) {
                          return ValueListenableBuilder<String>(
                            valueListenable: _talk.mode,
                            builder: (context, mode, ____) {
                              final label = _statusLabel(
                                state: s,
                                speaking: speaking,
                                reconnecting: reconnecting,
                                mode: mode,
                              );
                              return Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Error banner with retry CTA
              ValueListenableBuilder<LiveTalkError?>(
                valueListenable: _talk.lastError,
                builder: (context, err, _) {
                  if (err == null) return const SizedBox.shrink();
                  final title = LiveTalkErrorMessages.title(err);
                  final desc = LiveTalkErrorMessages.description(err);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.error_outline, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(desc, style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (LiveTalkErrorMessages.showOpenSettings(err))
                                        TextButton(
                                          onPressed: () {
                                            openAppSettings();
                                          },
                                          child: const Text('Open Settings'),
                                        ),
                                      FilledButton(
                                        onPressed: _talk.retry,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Waveform placeholder
              SizedBox(
                height: 36,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final v = 0.3 + 0.7 * _pulse.value;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(12, (i) {
                        final h = 8 + (i % 4 + 1) * 6 * v;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            width: 3,
                            height: h,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Transcript area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          itemCount: _assistantTurns.length + (_partial.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_partial.isNotEmpty && index == 0) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  _partial,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[700], fontStyle: FontStyle.italic),
                                ),
                              );
                            }
                            final turnIndex = _partial.isNotEmpty ? index - 1 : index;
                            final text = _assistantTurns.reversed.elementAt(turnIndex);
                            return _AssistantBubble(text: text);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Invisible video view to play remote audio
                      SizedBox(
                        height: 1,
                        width: 1,
                        child: RTCVideoView(_talk.remoteRenderer, mirror: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                    label: const Text('Stop'),
                    onPressed: _endCall,
                  ),
                  // Press-to-talk mic
                  ValueListenableBuilder<bool>(
                    valueListenable: _talk.muted,
                    builder: (context, muted, _) {
                      final color = muted
                          ? Colors.grey.shade400
                          : Theme.of(context).colorScheme.primary;
                      final icon = muted ? Icons.mic_off_rounded : Icons.mic_rounded;
                      final label = muted ? 'Tap to unmute\nHold to talk' : 'Tap to mute\nHold to talk';
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: _talk.toggleMute,
                            onLongPressStart: (_) => _talk.holdToTalkStart(),
                            onLongPressEnd: (_) => _talk.holdToTalkEnd(),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.15),
                                border: Border.all(color: color, width: 2),
                              ),
                              child: Icon(icon, color: color, size: 30),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                  OutlinedButton(
                    onPressed: _talk.requestAssistantTurn,
                    child: const Text('Interrupt'),
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

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      ),
    );
  }
}
