// lib/widgets/via_overlay.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/via_service.dart';
import '../services/analytics_service.dart';
import '../services/journey/journey_service.dart';

/// Premium floating assistant overlay for "Via".
/// Overlay-only: access bubble lives in HomeScreen.
/// States: peek card ↔ expanded chat (no collapsed bubble state).
class ViaOverlay extends StatefulWidget {
  final String contextLabel;
  final Map<String, dynamic> state;

  /// Optional: invoked when Via suggests making a plan.
  final VoidCallback? onMakePlan;

  /// Optional: invoked when Via suggests opening the visualizer.
  final VoidCallback? onVisualize;

  /// Optional: if you want to pass the user's display name directly.
  final String? userDisplayName;

  /// Optional: start in expanded state (defaults to peek).
  final bool startOpen;

  /// Optional: Use this to handle sending messages yourself.
  /// Should return Via's reply text.
  final Future<String> Function(
    String message, {
    String? contextLabel,
    Map<String, dynamic>? state,
  })? onAsk;

  const ViaOverlay({
    super.key,
    required this.contextLabel,
    this.state = const {},
    this.onMakePlan,
    this.onVisualize,
    this.userDisplayName,
    this.startOpen = false,
    this.onAsk,
  });

  @override
  State<ViaOverlay> createState() => _ViaOverlayState();
}

enum _OverlayStage { peek, expanded }

class _ViaOverlayState extends State<ViaOverlay> with TickerProviderStateMixin {
  _OverlayStage _stage = _OverlayStage.peek;

  final TextEditingController _composer = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _listController = ScrollController();



  bool _sending = false;
  final List<_ChatBubble> _messages = <_ChatBubble>[];

  static const _brandPeach = Color(0xFFF2B897);

  // --- Layout tuning ---------------------------------------------------------
  // Reserve space so the overlay panel does NOT cover the bottom circular nav.
  static const double _kBottomNavGuard = 86; // ~56 button + paddings + buffer
  static const double _kSideGutter = 14;
  static const double _kPanelRadius = 28;

  // Stronger dim behind the panel (adds on top of showDialog barrierColor).
  static const double _kBackdropOpacity = 0.38;

  @override
  void initState() {
    super.initState();

    // Overlay appears immediately; default to peek or expanded based on startOpen.
    _stage = widget.startOpen ? _OverlayStage.expanded : _OverlayStage.peek;
    _seedGreeting();

    // Focus composer if starting expanded.
    if (_stage == _OverlayStage.expanded) {
      Future.delayed(const Duration(milliseconds: 80), _focusNode.requestFocus);
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _focusNode.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _closeOverlay() {
    AnalyticsService.instance.log('via_close', {'context': widget.contextLabel});
    Navigator.of(context).maybePop();
  }

  void _expand() {
    if (_stage == _OverlayStage.expanded) return;
    setState(() => _stage = _OverlayStage.expanded);
    // Focus the composer when expanded.
    Future.delayed(const Duration(milliseconds: 80), _focusNode.requestFocus);
  }

  void _collapseToPeek() {
    if (_stage == _OverlayStage.peek) return;
    setState(() => _stage = _OverlayStage.peek);
    FocusScope.of(context).unfocus();
  }

  // --- Messaging -------------------------------------------------------------

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.insert(0, _ChatBubble(text: text.trim(), fromUser: true, timestamp: DateTime.now()));
    });

    _composer.clear();
    _scrollToBottomSoon();

    AnalyticsService.instance.log('via_send', {
      'context': widget.contextLabel,
      'len': text.length,
    });

    String reply = 'Working on that…';
    try {
      if (widget.onAsk != null) {
        reply = await widget.onAsk!(text,
            contextLabel: widget.contextLabel, state: widget.state);
      } else {
        // Try the app's ViaService if available.
        final service = ViaService() as dynamic;
        final res = await service.ask(
          text,
          contextLabel: widget.contextLabel,
          state: widget.state,
        );
        reply = (res?.toString() ?? reply);
      }
    } catch (_) {
      reply =
          "Here’s a first suggestion based on what I know. (I couldn’t reach the network just now.)";
    }

    setState(() {
      _messages.insert(0, _ChatBubble(text: reply, fromUser: false, timestamp: DateTime.now()));
      _sending = false;
    });

    _scrollToBottomSoon();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) {
        _listController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _seedGreeting() {
    if (_messages.isNotEmpty) return;
    final name = (widget.userDisplayName ??
            widget.state['firstName'] ??
            widget.state['userName'] ??
            '')
        .toString()
        .trim();
    final hi = name.isEmpty ? "Hi there" : "Hi $name";
    final msg = "$hi — how can I help today?";
    setState(() {
      _messages.add(_ChatBubble(text: msg, fromUser: false, timestamp: DateTime.now(), isSystem: true));
    });
  }

  // --- Suggestions -----------------------------------------------------------

  List<_Suggestion> _buildSuggestions() {
    final step = JourneyService.instance.state.value?.currentStepId;
    switch (step) {
      case 'interview.basic':
        return [
          _Suggestion('How do I answer?', 'Give me tips for the interview.'),
          _Suggestion('Suggest a palette', 'Suggest a starting palette.'),
        ];
      case 'roller.build':
        return [
          _Suggestion('Balance undertones', 'Help me balance undertones.'),
          _Suggestion('Add bridge color', 'Suggest a bridge color between hues.'),
        ];
      case 'visualizer.photo':
        return [
          _Suggestion('Pick a good photo', 'What makes a good reference photo?'),
        ];
      case 'visualizer.generate':
        return [
          _Suggestion('Refine edges', 'Sharpen mask edges and fix spill.'),
          _Suggestion('Try 10% darker', 'Show a slightly darker simulation.'),
        ];
      case 'plan.create':
        return [
          _Suggestion('Room plan tips', 'How should I use these colors?'),
        ];
      case 'guide.export':
        return [
          _Suggestion('What\'s next?', 'How do I share this guide?'),
        ];
      default:
        return [
          _Suggestion('Suggest a paint color',
              'Suggest a paint color for my space.'),
          _Suggestion('Talk about lighting',
              'Consider my room\'s orientation and time of day.'),
        ];
    }
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom; // keyboard
    final media = MediaQuery.of(context).size;
    final isExpanded = _stage == _OverlayStage.expanded;

    // Heights for peek/expanded relative to screen.
    // Peek is a touch bigger for breathing room (was 0.46).
    final double peekHeight = media.height * 0.54;
    final double expandedHeight = media.height * 0.86;

    // When keyboard is up, let the panel sit near the bottom (14).
    // Otherwise, hold it above the custom bottom nav by reserving extra space.
    final double bottomOffset = viewInsets > 0 ? _kSideGutter : (_kSideGutter + _kBottomNavGuard);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Interactive backdrop with a stronger scrim to fix "too transparent".
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (isExpanded) {
                  _collapseToPeek();
                } else {
                  _closeOverlay();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                color: Colors.black.withAlpha((255 * _kBackdropOpacity).round()),
              ),
            ),
          ),

          // Feathered glass overlay (peek/expanded)
          Positioned(
            left: _kSideGutter,
            right: _kSideGutter,
            bottom: bottomOffset,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: (_stage == _OverlayStage.peek ? peekHeight : expandedHeight) + viewInsets,
              child: _FeatheredGlass(
                blurSigma: 18,
                feather: 38,
                // Slightly more opaque interior so content pops against the dim.
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xCCFFFFFF), // ~80% white
                    Color(0xA6FFFFFF), // ~65% white
                    Color(0x80FFFFFF), // ~50% white
                  ],
                ),
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: false,
                  child: Column(
                    children: [
                      _OverlayHeader(
                        onClose: _closeOverlay,
                        onExpand: _expand,
                        onCollapse: _collapseToPeek,
                        isExpanded: isExpanded,
                      ),
                      const SizedBox(height: 6),

                      // Greeting + chips (peek state)
                      if (_stage == _OverlayStage.peek)
                        _GreetingAndChips(
                          greeting: _messages.isNotEmpty
                              ? _messages.last.text
                              : "Hi — how can I help today?",
                          suggestions: _buildSuggestions(),
                          onChip: (s) {
                            AnalyticsService.instance
                                .log('via_chip', {'label': s.label, 'context': widget.contextLabel});
                            if (s.onTapOverride != null) {
                              s.onTapOverride!();
                              return;
                            }
                            _send(s.prompt);
                            _expand();
                          },
                        ),

                      // Chat area (expanded)
                      if (_stage == _OverlayStage.expanded) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: _ChatList(
                              messages: _messages,
                              controller: _listController,
                            ),
                          ),
                        ),
                        _ComposerBar(
                          controller: _composer,
                          focusNode: _focusNode,
                          sending: _sending,
                          onSend: _send,
                          onMic: () {
                            AnalyticsService.instance
                                .log('via_mic', {'context': widget.contextLabel});
                          },
                          onAttachImage: () {
                            AnalyticsService.instance
                                .log('via_attach_image', {'context': widget.contextLabel});
                          },
                          onAttachDoc: () {
                            AnalyticsService.instance
                                .log('via_attach_doc', {'context': widget.contextLabel});
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// == UI Pieces ================================================================

class _OverlayHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final bool isExpanded;
  const _OverlayHeader({
    required this.onClose,
    required this.onExpand,
    required this.onCollapse,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
      child: Row(
        children: [
          const Icon(Icons.flash_on_rounded, size: 22, color: _ViaOverlayState._brandPeach),
          const SizedBox(width: 8),
          const Text(
            "Assistant",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: isExpanded ? onCollapse : onExpand,
            icon: Icon(isExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _GreetingAndChips extends StatelessWidget {
  final String greeting;
  final List<_Suggestion> suggestions;
  final void Function(_Suggestion) onChip;

  const _GreetingAndChips({
    required this.greeting,
    required this.suggestions,
    required this.onChip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.take(6).map((s) {
              return _ChipButton(
                label: s.label,
                onTap: () => onChip(s),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<_ChatBubble> messages;
  final ScrollController controller;

  const _ChatList({required this.messages, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      controller: controller,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
        final bg = m.fromUser ? const Color(0xFFEFE8E1) : Colors.white.withValues(alpha: 209 / 255.0);

        return Align(
          alignment: align,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Text(m.text, style: const TextStyle(color: Colors.black87, height: 1.35)),
          ),
        );
      },
    );
  }
}

class _ComposerBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final ValueChanged<String> onSend;
  final VoidCallback onMic;
  final VoidCallback onAttachImage;
  final VoidCallback onAttachDoc;

  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.onMic,
    required this.onAttachImage,
    required this.onAttachDoc,
  });

  @override
  State<_ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<_ComposerBar> {
  void _submit() {
    final text = widget.controller.text;
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          _GhostIconButton(icon: Icons.image_rounded, onTap: widget.onAttachImage),
          const SizedBox(width: 6),
          _GhostIconButton(icon: Icons.folder_open_rounded, onTap: widget.onAttachDoc),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 209 / 255.0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: "Type your question…",
                  isDense: true,
                  border: InputBorder.none,
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _GhostIconButton(icon: Icons.mic_none_rounded, onTap: widget.onMic),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: widget.sending ? null : _submit,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _ViaOverlayState._brandPeach,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: widget.sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_upward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

// == Visual Helpers ===========================================================

/// Feathered, frosted container with soft, transparent edges.
/// Uses BackdropFilter + radial ShaderMask to dissolve borders.
class _FeatheredGlass extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double feather; // width of the fade at the edges
  final Gradient gradient;

  const _FeatheredGlass({
    required this.child,
    required this.blurSigma,
    required this.feather,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        // Radial gradient mask: solid center → transparent edges.
        return const RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.72, 0.92, 1.0],
        ).createShader(bounds);
      },
      child: ClipRRect(
        // Mild rounding—actual edge softness comes from the mask.
        borderRadius: BorderRadius.circular(_ViaOverlayState._kPanelRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Frosted glass effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: const SizedBox.expand(),
            ),
            // Tint + ambient wash
            Container(
              decoration: BoxDecoration(gradient: gradient),
            ),
            // Subtle inner highlight + outer ambient glow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_ViaOverlayState._kPanelRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 30,
                    spreadRadius: -8,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 217 / 255.0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ViaOverlayState._brandPeach.withValues(alpha: 115 / 255.0), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GhostIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 209 / 255.0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

// == Models ===================================================================

class _ChatBubble {
  final String text;
  final bool fromUser;
  final DateTime timestamp;
  final bool isSystem;
  _ChatBubble({
    required this.text,
    required this.fromUser,
    required this.timestamp,
    this.isSystem = false,
  });
}

class _Suggestion {
  final String label;
  final String prompt;
  final bool requiresCallback;
  final VoidCallback? onTapOverride;

  _Suggestion(this.label, this.prompt,
      {this.onTapOverride, bool? requiresCallback})
      : requiresCallback = requiresCallback ?? (onTapOverride != null);
}
