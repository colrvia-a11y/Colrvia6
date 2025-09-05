// lib/widgets/via_overlay.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/via_service.dart';
import '../services/analytics_service.dart';
import '../theme.dart';
import 'colr_via_icon_button.dart';

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
  static const double _kBottomNavGuard = 86;
  static const double _kSideGutter = AppDims.gap * 2;
  static const double _kPanelRadius = AppDims.radiusLarge;
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
    AnalyticsService.instance.viaOpened(widget.contextLabel);

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

    Future<String> ask(String q) async {
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

    final reply = await ask(trimmed);
    if (!mounted) return;
    setState(() {
      _msgs.insert(0, _ChatBubble(text: reply, fromUser: false, timestamp: DateTime.now()));
      _sending = false;
    });
    _scrollToBottomSoon();
  }

  List<_Suggestion> _suggestions() {
    switch (widget.contextLabel) {
      case 'paint_detail':
        return [
          const _Suggestion('Similar shades', 'Show me similar shades'),
          const _Suggestion('Save color', 'How can I save this color?'),
          const _Suggestion('Next steps', 'What should I do next?'),
        ];
      case 'roller':
        return [
          const _Suggestion('Palette ideas', 'Suggest a palette for me'),
          const _Suggestion('Color meaning', 'What does this color represent?'),
          const _Suggestion('Next steps', 'What should I do next?'),
        ];
      default:
        return [
          const _Suggestion('Name my palette', 'Can you suggest names for this palette?'),
          const _Suggestion('Lighting advice', 'How will these colors look at night?'),
          const _Suggestion('Next steps', 'What should I do next?'),
        ];
    }
  }

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
                    ? Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(0.96)
                    : Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withOpacity(0.95),
                topFadeStart: (isExpanded ? null : 0.5),
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: false,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: insets + AppDims.gap),
                    child: Column(
                      children: [
                        _OverlayHeader(
                          onClose: _close,
                          onExpand: _expand,
                          onCollapse: _collapse,
                          isExpanded: isExpanded,
                        ),
                        const SizedBox(height: AppDims.gap),
                        if (!isExpanded)
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) => Stack(
                                children: [
                                  Positioned(
                                    top: constraints.maxHeight * 0.5,
                                    left: 0,
                                    right: 0,
                                    child: _GreetingAndChips(
                                      greeting: _msgs.isNotEmpty
                                          ? _msgs.last.text
                                          : 'Hi — how can I help today?',
                                      suggestions: _suggestions(),
                                      onChip: (s) {
                                        AnalyticsService.instance
                                            .log('via_chip', {'label': s.label, 'context': widget.contextLabel});
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
                                            Future.delayed(const Duration(milliseconds: 50), () => _focus.requestFocus());
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
                          ),
                        if (isExpanded) ...[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppDims.gap * 2),
                              child: _ChatList(messages: _msgs, controller: _list),
                            ),
                          ),
                          _ComposerBar(
                            controller: _composer,
                            focusNode: _focus,
                            sending: _sending,
                            onSend: _send,
                            onMic: () => AnalyticsService.instance.log('via_mic', {'context': widget.contextLabel}),
                            onAttachImage: () => AnalyticsService.instance
                                .log('via_attach_image', {'context': widget.contextLabel}),
                            onAttachDoc: () => AnalyticsService.instance
                                .log('via_attach_doc', {'context': widget.contextLabel}),
                          ),
                          const SizedBox(height: AppDims.gap),
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
    final iconColor = Theme.of(context).colorScheme.primary;
    final textStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Icon(Icons.flash_on_rounded,
              size: 22, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: AppDims.gap),
          Text('Assistant', style: textStyle),
          const Spacer(),
          ColrViaIconButton(
            icon: Icons.close_rounded,
            color: iconColor,
            semanticLabel: 'Close assistant',
            onPressed: onClose,
            size: 40,
          ),
          const SizedBox(width: AppDims.gap),
          ColrViaIconButton(
            icon: isExpanded
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded,
            color: iconColor,
            onPressed: isExpanded ? onCollapse : onExpand,
            semanticLabel: isExpanded ? 'Collapse' : 'Expand',
            size: 40,
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
          Text(
            greeting,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDims.gap),
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
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      reverse: true,
      controller: controller,
      padding: const EdgeInsets.only(bottom: AppDims.gap),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
        final bg = m.fromUser ? scheme.secondaryContainer : scheme.surface;
        final fg = m.fromUser ? scheme.onSecondaryContainer : scheme.onSurface;
        return Align(
          alignment: align,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.symmetric(vertical: AppDims.gap),
            padding: EdgeInsets.symmetric(
                horizontal: AppDims.gap * 1.5, vertical: AppDims.gap * 1.25),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 6)),
              ],
            ),
            child: Text(m.text, style: TextStyle(color: fg, height: 1.35)),
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
      padding: EdgeInsets.fromLTRB(
          AppDims.gap * 1.5, AppDims.gap, AppDims.gap * 1.5, AppDims.gap * 1.5),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppDims.radiusLarge),
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
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: AppDims.gap * 1.25, vertical: AppDims.gap * 1.25),
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
  final double? topFadeStart; // 0..1 from bottom to top (e.g., 0.5)
  const _SolidSurface({required this.blurSigma, required this.color, required this.child, this.topFadeStart});

  @override
  Widget build(BuildContext context) {
    Widget surface = Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: const SizedBox.expand(),
        ),
        Container(color: color),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_ViaOverlayState._kPanelRadius),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 30, spreadRadius: -8, offset: Offset(0, 16)),
            ],
          ),
        ),
        Material(type: MaterialType.transparency, child: child),
      ],
    );

    if (topFadeStart != null) {
      final double s = topFadeStart!.clamp(0.0, 1.0);
      const double topAlpha = 0.88; // keep ~88% opacity at top for a subtle fade
      surface = ShaderMask(
        shaderCallback: (Rect bounds) => LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black,
            Colors.black,
            Colors.black.withValues(alpha: topAlpha),
          ],
          stops: [0.0, s, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: surface,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(_ViaOverlayState._kPanelRadius),
      child: surface,
    );
  }
}class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDims.radiusMedium),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDims.gap * 2, vertical: AppDims.gap),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDims.radiusMedium),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withOpacity(115 / 255.0),
              width: 1),
        ),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
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
      radius: AppDims.radiusLarge,
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
  _ChatBubble({required this.text, required this.fromUser, required this.timestamp});
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
      borderRadius: BorderRadius.circular(AppDims.radiusMedium),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDims.radiusMedium),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}












