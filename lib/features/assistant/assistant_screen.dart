/// Offline, scripted health assistant in a chat UI.
///
/// Chat history is saved under the `assistant` feature key as
/// `{messages: [{from: 'bot' | 'user', text, ts}], node: nodeId}`, capped at
/// 200 messages.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../insights/article_screen.dart';
import '../insights/widgets.dart';
import 'scripts.dart';
import 'symptom_checker.dart';

const _maxMessages = 200;

class _Msg {
  const _Msg(this.fromBot, this.text, this.ts);
  final bool fromBot;
  final String text;
  final String ts;

  Map<String, dynamic> toJson() => {'from': fromBot ? 'bot' : 'user', 'text': text, 'ts': ts};

  factory _Msg.fromJson(Map<String, dynamic> j) =>
      _Msg(j['from'] != 'user', j['text'] as String? ?? '', j['ts'] as String? ?? '');
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  List<_Msg> _messages = [];
  List<BotOption> _options = [];
  String _node = 'start';
  bool _typing = false;
  bool _hasText = false;

  /// Bumped to cancel a running reply sequence (for example, on clear).
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  AppStore get _store => context.read<AppStore>();

  void _load() {
    final raw = _store.feature<Map>('assistant');
    final list = (raw?['messages'] as List?) ?? const [];
    _messages = [for (final m in list) _Msg.fromJson(Map<String, dynamic>.from(m as Map))];
    // With no history, show the greeting without saving it until the user replies.
    if (_messages.isEmpty) {
      final step = buildStep('start', _store);
      final now = DateTime.now().toIso8601String();
      _messages = [for (final m in step.messages) _Msg(true, m, now)];
      _options = step.options;
      _node = 'start';
    } else {
      _node = raw?['node'] as String? ?? 'menu';
      _options = buildStep(_node, _store).options;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom(jump: true));
  }

  void _save() {
    if (_messages.length > _maxMessages) {
      _messages = _messages.sublist(_messages.length - _maxMessages);
    }
    _store.setFeature('assistant', {
      'messages': [for (final m in _messages) m.toJson()],
      'node': _node,
    });
  }

  void _toBottom({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    jump
        ? _scroll.jumpTo(target)
        : _scroll.animateTo(target, duration: Motion.medium, curve: Motion.curve);
  }

  void _afterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());

  Future<void> _reply(BotStep step) async {
    final run = ++_run;
    setState(() => _options = []);
    for (final m in step.messages) {
      setState(() => _typing = true);
      _afterFrame();
      final ms = (350 + m.length * 4).clamp(450, 1300);
      await Future<void>.delayed(Duration(milliseconds: ms));
      if (!mounted || run != _run) return;
      setState(() {
        _typing = false;
        _messages.add(_Msg(true, m, DateTime.now().toIso8601String()));
      });
      _afterFrame();
    }
    if (!mounted || run != _run) return;
    setState(() {
      _node = step.id;
      _options = step.options;
    });
    _save();
    _afterFrame();
  }

  void _userSays(String text) {
    setState(() => _messages.add(_Msg(false, text, DateTime.now().toIso8601String())));
    _save();
    _afterFrame();
  }

  void _choose(BotOption o) {
    if (_typing) return;
    if (o.articleId != null) {
      openArticle(context, o.articleId!);
      return;
    }
    if (o.checkerId != null) {
      openChecker(context, o.checkerId!);
      return;
    }
    _userSays(o.label);
    _reply(buildStep(o.next ?? 'menu', _store));
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    _userSays(text);
    _reply(respondToText(text, _store));
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text('This deletes your conversation with the assistant from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _run++;
    _store.setFeature('assistant', null);
    setState(() {
      _typing = false;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final options = [
      ..._options,
      if (_node != 'menu' && _node != 'start' && _node != 'fallback' && !_options.any((o) => o.next == 'menu'))
        const BotOption('Other topics', next: 'menu'),
    ];
    final showTray = options.isNotEmpty && !_typing;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // Header.
          MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.sm, Space.md),
              child: Row(children: [
                if (ModalRoute.of(context)?.impliesAppBarDismissal ?? false) ...[
                  const BackButton(),
                  Gap.h4,
                ],
                const BloomLogo(size: 40),
                Gap.h12,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Assistant', style: theme.textTheme.headlineSmall),
                    Row(children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: BloomColors.success, shape: BoxShape.circle),
                      ),
                      Gap.h4,
                      Flexible(
                        child: Text(
                          _typing ? 'Typing...' : 'Offline and private',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ]),
                  ]),
                ),
                IconButton(
                  tooltip: 'Symptom checker',
                  icon: const Icon(Icons.fact_check_outlined),
                  onPressed: () => openCheckerList(context),
                ),
                IconButton(
                  tooltip: 'Explain my cycle',
                  icon: const Icon(Icons.insights_rounded),
                  onPressed: _typing ? null : () => _choose(const BotOption('Explain my cycle', next: 'report')),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) {
                    if (v == 'clear') _clear();
                    if (v == 'urgent') _choose(const BotOption('Urgent warning signs', next: 'urgent'));
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'urgent', child: Text('Urgent warning signs')),
                    PopupMenuItem(value: 'clear', child: Text('Clear chat history')),
                  ],
                ),
              ]),
            ),
          ),
          Divider(height: 1, thickness: 1, color: tokens.border),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
              itemCount: _messages.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return const MaxWidth(child: _SafetyNote());
                if (i == _messages.length + 1) {
                  return MaxWidth(
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      child: _typing ? const _TypingBubble() : const SizedBox(width: double.infinity),
                    ),
                  );
                }
                final m = _messages[i - 1];
                final next = i < _messages.length ? _messages[i] : null;
                final lastInGroup = next == null ? !(m.fromBot && _typing) : next.fromBot != m.fromBot;
                final prev = i >= 2 ? _messages[i - 2] : null;
                final firstInGroup = prev == null || prev.fromBot != m.fromBot;
                return MaxWidth(
                  child: _Bubble(
                    msg: m,
                    lastInGroup: lastInGroup,
                    firstInGroup: firstInGroup,
                    animate: i == _messages.length,
                  ),
                );
              },
            ),
          ),
          // Quick replies.
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.curve,
            alignment: Alignment.bottomCenter,
            child: !showTray
                ? const SizedBox(width: double.infinity)
                : MaxWidth(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 156),
                      padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.sm),
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                          for (final o in options)
                            SelectChip(
                              label: o.label,
                              selected: false,
                              showCheck: false,
                              icon: o.articleId != null
                                  ? Icons.menu_book_rounded
                                  : o.checkerId != null
                                      ? Icons.fact_check_outlined
                                      : o.next == 'urgent'
                                          ? Icons.warning_amber_rounded
                                          : null,
                              color: o.articleId != null
                                  ? BloomColors.info
                                  : o.checkerId != null
                                      ? BloomColors.luteal
                                      : o.next == 'urgent'
                                          ? BloomColors.period
                                          : null,
                              onSelected: (_) => _choose(o),
                            ),
                        ]),
                        ),
                      ),
                    ),
                  ),
          ),
          // Input bar.
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              border: Border(top: BorderSide(color: tokens.border)),
            ),
            child: SafeArea(
              top: false,
              child: MaxWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm + 2, Space.md, Space.sm + 2),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask about your cycle...',
                          filled: true,
                          fillColor: tokens.subtle,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md + 2),
                          border: const OutlineInputBorder(borderRadius: Radii.pillAll, borderSide: BorderSide.none),
                          enabledBorder:
                              const OutlineInputBorder(borderRadius: Radii.pillAll, borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: Radii.pillAll,
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
                          ),
                        ),
                      ),
                    ),
                    Gap.h8,
                    _SendButton(enabled: _hasText && !_typing, onPressed: _send),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: BloomGradients.brand,
          boxShadow: enabled ? BloomShadows.glow(BloomColors.brand) : null,
        ),
        child: IconButton(
          tooltip: 'Send',
          onPressed: onPressed,
          iconSize: 22,
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

/// The compact safety note at the top of the chat.
class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          decoration: BoxDecoration(color: tokens.subtle, borderRadius: Radii.mdAll),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.health_and_safety_rounded, size: 16, color: tokens.muted),
            ),
            Gap.h8,
            Flexible(
              child: Text(
                'Offline assistant for general education, not a doctor. '
                'In an emergency, call your local emergency number.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The avatar column beside bot bubbles. Only the last bubble of a group
/// shows the logo.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.show});
  final bool show;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30,
        child: show ? const BloomLogo(size: 30) : null,
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, this.lastInGroup = true, this.firstInGroup = true, this.animate = false});
  final _Msg msg;
  final bool lastInGroup;
  final bool firstInGroup;

  /// Slides the bubble in (used for the newest message).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = BloomTokens.of(context);
    final bot = msg.fromBot;
    final fg = bot ? cs.onSurface : cs.onPrimary;
    const big = Radius.circular(20);
    const tail = Radius.circular(6);
    final time = DateTime.tryParse(msg.ts);

    Widget bubble = Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xs),
      decoration: BoxDecoration(
        color: bot ? theme.cardTheme.color : cs.primary,
        border: bot ? Border.all(color: tokens.border) : null,
        boxShadow: bot ? tokens.cardShadow : null,
        borderRadius: BorderRadius.only(
          topLeft: bot && !firstInGroup ? tail : big,
          topRight: !bot && !firstInGroup ? tail : big,
          bottomLeft: bot ? tail : big,
          bottomRight: bot ? big : tail,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: Theme(
          data: theme.copyWith(textTheme: theme.textTheme.apply(bodyColor: fg, displayColor: fg)),
          child: _BubbleText(msg.text),
        ),
      ),
    );

    Widget row = Padding(
      padding: EdgeInsets.only(bottom: lastInGroup ? Space.md : Space.xs),
      child: Column(
        crossAxisAlignment: bot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: bot ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (bot) ...[_Avatar(show: lastInGroup), Gap.h8],
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(padding: EdgeInsets.only(left: bot ? 0 : 56, right: bot ? 32 : 0), child: bubble),
                ),
              ),
            ],
          ),
          if (lastInGroup && time != null)
            Padding(
              padding: EdgeInsets.only(top: Space.xs, left: bot ? 38 + Space.xs : 0, right: Space.xs),
              child: Text(
                DateFormat.jm().format(time.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(color: tokens.muted, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );

    if (animate) {
      row = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.medium,
        curve: Motion.emphasized,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
        ),
        child: row,
      );
    }
    return row;
  }
}

/// Bubble text with the article markup, but tighter than an article.
class _BubbleText extends StatelessWidget {
  const _BubbleText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45, fontSize: 15);
    final lines = text.split('\n');
    final children = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(Gap.v4);
      } else if (line.startsWith('- ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Space.xs),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: base),
            Expanded(child: Text.rich(TextSpan(children: ArticleBody.spans(line.substring(2), base)))),
          ]),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text.rich(TextSpan(children: ArticleBody.spans(line, base))),
        ));
      }
    }
    children.add(Gap.v8);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const _Avatar(show: true),
        Gap.h8,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            border: Border.all(color: tokens.border),
            boxShadow: tokens.cardShadow,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Builder(builder: (_) {
                  // Each dot bounces in turn.
                  final p = ((_c.value - i * 0.15) % 1.0);
                  final lift = p < 0.4 ? math.sin(p / 0.4 * math.pi) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Transform.translate(
                      offset: Offset(0, -4 * lift),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(tokens.muted, theme.colorScheme.primary, lift),
                        ),
                      ),
                    ),
                  );
                }),
            ]),
          ),
        ),
      ]),
    );
  }
}
