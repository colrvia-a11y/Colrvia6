// lib/widgets/via_overlay.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/via_service.dart';
import '../services/analytics_service.dart';

class ViaOverlay extends StatefulWidget {
  final String contextLabel;
  final Map<String, dynamic> state;
  final VoidCallback? onMakePlan;
  final VoidCallback? onVisualize;
  final String? userDisplayName;
  final bool startOpen;
  final Future<String> Function(String message, {String? contextLabel, Map<String, dynamic>? state})?
      onAsk;

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
  static const _brandPeach = Color(0xFFF2B897);
  static const double _kBottomNavGuard = 86;
  static const double _kSideGutter = 14;
  static const double _kPanelRadius = 28;
  static const double _kBackdropOpacity = 0.48;

  _OverlayStage _stage = _OverlayStage.peek;
  final TextEditingController _composer = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _list = ScrollController();
  bool _sending = false;
  final List<_ChatBubble> _msgs = <_ChatBubble>[];

  @override
  void initState() {
    super.initState();
    _stage = widget.startOpen ? _OverlayStage.expanded : _OverlayStage.peek;
    _seedGreeting();

    if (_stage == _OverlayStage.expanded) {
      Future.delayed(const Duration(milliseconds: 80), _focus.requestFocus);
    }
    _focus.addListener(() {
      if (_focus.hasFocus) _expand();
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    _list.dispose();
    super.dispose();
  }

  void _seedGreeting() {
    final hi = widget.userDisplayName?.trim().isNotEmpty == true
        ? 'Hi ${widget.userDisplayName}'
        : 'Hi there';
    final msg = "$hi — how can I help today?";
    _msgs.add(_ChatBubble(text: msg, fromUser: false, timestamp: DateTime.now()));
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_list.hasClients) return;
      _list.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _close() {
    AnalyticsService.instance.log('via_close', {'context': widget.contextLabel});
    Navigator.of(context).maybePop();
  }

  void _expand() {
    if (_stage == _OverlayStage.expanded) return;
    setState(() => _stage = _OverlayStage.expanded);
    Future.delayed(const Duration(milliseconds: 80), _focus.requestFocus);
  }

  void _collapse() {
    if (_stage == _OverlayStage.peek) return;
    setState(() => _stage = _OverlayStage.peek);
    FocusScope.of(context).unfocus();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _msgs.insert(0, _ChatBubble(text: trimmed, fromUser: true, timestamp: DateTime.now()));
    });
    _composer.clear();
    _scrollToBottomSoon();

    AnalyticsService.instance.log('via_send', {'context': widget.contextLabel, 'chars': trimmed.length});

    Future<String> _ask(String q) async {
      if (widget.onAsk != null) {
        return widget.onAsk!(q, contextLabel: widget.contextLabel, state: widget.state);
      }
      try {
        // Default path: use cloud function based reply using context + state.
        return await ViaService().reply(widget.contextLabel, widget.state);
      } catch (e) {
        return 'Sorry — I ran into an issue. Please try again.';
      }
    }

    final reply = await _ask(trimmed);
    if (!mounted) return;
    setState(() {
      _msgs.insert(0, _ChatBubble(text: reply, fromUser: false, timestamp: DateTime.now()));
      _sending = false;
    });
    _scrollToBottomSoon();
  }

  List<_Suggestion> _suggestions() => [
        _Suggestion('Name my palette', 'Can you suggest names for this palette?'),
        _Suggestion('Lighting advice', 'How will these colors look at night?'),
        _Suggestion('Next steps', 'What should I do next?'),
      ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final isExpanded = _stage == _OverlayStage.expanded;

    final double peekHeight = media.height * 0.58;
    final double expandedHeight = media.height * 0.96;
    final double bottomOffset = insets > 0 ? 0 : (_kSideGutter + _kBottomNavGuard);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => isExpanded ? _collapse() : _close(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                color: Colors.black.withAlpha((255 * _kBackdropOpacity).round()),
              ),
            ),
          ),

          Positioned(
            left: _kSideGutter,
            right: _kSideGutter,
            bottom: bottomOffset,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: (isExpanded ? expandedHeight : peekHeight),
              child: _SolidSurface(
                blurSigma: 12,
                color: isExpanded
                    ? const Color(0xF5FFFFFF)
                    : _ViaOverlayState._brandPeach.withValues(alpha: 0.95),
                topGradient: isExpanded
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFFFFF), Colors.transparent],
                        stops: [0.0, 1.0],
                      ),
                child: SafeArea(child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: false,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: insets + 8),
                    child: Column(
                      children: [
                        _OverlayHeader(
                          onClose: _close,
                          onExpand: _expand,
                          onCollapse: _collapse,
                          isExpanded: isExpanded,
                        ),
                        const SizedBox(height: 6),

                        if (!isExpanded)
                          Expanded(
                            child: Stack(
                              children: [
                                Align(
                                  alignment: const Alignment(0, 0.1),
                                  child: _GreetingAndChips(
                                    greeting: _msgs.isNotEmpty
                                        ? _msgs.last.text
                                        : 'Hi � how can I help today?',
                                    suggestions: _suggestions(),
                                    onChip: (s) {
                                      AnalyticsService.instance.log(
                                          'via_chip', {'label': s.label, 'context': widget.contextLabel});
                                      _send(s.prompt);
                                      _expand();
                                    },
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  bottom: 8,
                                  child: Row(
                                    children: [
                                      _OutlinedSquareIcon(
                                        icon: Icons.keyboard_rounded,
                                        onTap: () {
                                          _expand();
                                          Future.delayed(
                                              const Duration(milliseconds: 50), () => _focus.requestFocus());
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _OutlinedSquareIcon(
                                        icon: Icons.mic_none_rounded,
                                        onTap: () {
                                          AnalyticsService.instance
                                              .log('via_mic', {'context': widget.contextLabel});
                                          _expand();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (isExpanded) ...[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: _ChatList(messages: _msgs, controller: _list),
                            ),
                          ),
                          _ComposerBar(
                            controller: _composer,
                            focusNode: _focus,
                            sending: _sending,
                            onSend: _send,
                            onMic: () => AnalyticsService.instance.log('via_mic', {'context': widget.contextLabel}),
                            onAttachImage: () => AnalyticsService.instance.log('via_attach_image', {'context': widget.contextLabel}),
                            onAttachDoc: () => AnalyticsService.instance.log('via_attach_doc', {'context': widget.contextLabel}),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
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
          const Text('Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
  final ValueChanged<_Suggestion> onChip;
  const _GreetingAndChips({required this.greeting, required this.suggestions, required this.onChip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                _ChipButton(
                  label: s.label,
                  onTap: () => onChip(s),
                )
            ],
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
        final bg = m.fromUser ? const Color(0xFFEFE8E1) : Colors.white;
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
                BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 6)),
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
  void _submit() => widget.onSend(widget.controller.text);

  Future<void> _showAttachMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx + 16,
      offset.dy - 8,
      offset.dx,
      0,
    );
    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'image', child: Text('Attach Image')),
        const PopupMenuItem(value: 'doc', child: Text('Attach Document')),
      ],
    );
    if (choice == 'image') {
      widget.onAttachImage();
    } else if (choice == 'doc') {
      widget.onAttachDoc();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 2))],
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your message…',
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  prefixIcon: Builder(
                    builder: (ctx) => IconButton(
                      tooltip: 'Attach',
                      icon: const Icon(Icons.attach_file_rounded),
                      onPressed: () => _showAttachMenu(ctx),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Voice',
                        icon: const Icon(Icons.mic_none_rounded),
                        onPressed: widget.sending ? null : widget.onMic,
                      ),
                      widget.sending
                          ? const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              tooltip: 'Send',
                              icon: const Icon(Icons.send_rounded),
                              onPressed: _submit,
                            ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _SolidSurface extends StatelessWidget {
  final double blurSigma;
  final Color color;
  final Widget child;
  final Gradient? topGradient;
  const _SolidSurface({required this.blurSigma, required this.color, required this.child, this.topGradient});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_ViaOverlayState._kPanelRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Optional frosted blur for context continuity
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: const SizedBox.expand(),
          ),
          // Solid high-opacity surface for maximum readability (no gradient)
          Container(color: color),
          // Subtle ambient shadow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_ViaOverlayState._kPanelRadius),
              boxShadow: const [
                BoxShadow(color: Color(0x1A000000), blurRadius: 30, spreadRadius: -8, offset: Offset(0, 16)),
              ],
            ),
          ),
          if (topGradient != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 20,
              child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: topGradient))),
            ),
          Material(type: MaterialType.transparency, child: child),
        ],
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ViaOverlayState._brandPeach.withValues(alpha: 115 / 255.0), width: 1),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
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
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

class _ChatBubble {
  final String text;
  final bool fromUser;
  final DateTime timestamp;
  final bool isSystem;
  _ChatBubble({required this.text, required this.fromUser, required this.timestamp, this.isSystem = false});
}

class _Suggestion {
  final String label;
  final String prompt;
  const _Suggestion(this.label, this.prompt);
}


class _OutlinedSquareIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _OutlinedSquareIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}



