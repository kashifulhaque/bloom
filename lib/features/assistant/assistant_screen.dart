/// Offline, scripted health assistant, set as a quiet correspondence.
///
/// Chat history is saved under the `assistant` feature key as
/// `{messages: [{from: 'bot' | 'user', text, ts, ai?, model?, error?}], node: nodeId}`,
/// capped at 200 messages. `ai` marks typed questions sent to the AI model
/// and its answers; `model` names the free model that answered; `error`
/// marks a failed AI answer.
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../insights/article_screen.dart';
import '../insights/widgets.dart';
import 'ai/ai_chat.dart';
import 'ai/ai_settings_screen.dart';
import 'ai/openrouter_client.dart' show AiException;
import 'scripts.dart';
import 'symptom_checker.dart';

const _maxMessages = 200;

class _Msg {
  const _Msg(this.fromBot, this.text, this.ts, {this.ai = false, this.model, this.error = false});
  final bool fromBot;
  final String text;
  final String ts;

  /// A typed question sent to the AI model, or the model's answer.
  final bool ai;

  /// The free model that answered.
  final String? model;

  /// A failed AI answer; [text] is the error message.
  final bool error;

  Map<String, dynamic> toJson() => {
        'from': fromBot ? 'bot' : 'user',
        'text': text,
        'ts': ts,
        if (ai) 'ai': true,
        if (model != null) 'model': model,
        if (error) 'error': true,
      };

  factory _Msg.fromJson(Map<String, dynamic> j) => _Msg(
        j['from'] != 'user',
        j['text'] as String? ?? '',
        j['ts'] as String? ?? '',
        ai: j['ai'] == true,
        model: j['model'] as String?,
        error: j['error'] == true,
      );
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.httpClient});

  /// The HTTP client for AI answers. Tests pass a mock client.
  final http.Client? httpClient;

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
      _options = _node == 'ai' ? const [] : buildStep(_node, _store).options;
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

  void _userSays(String text, {bool ai = false}) {
    setState(() => _messages.add(_Msg(false, text, DateTime.now().toIso8601String(), ai: ai)));
    _save();
    _afterFrame();
  }

  /// Earlier AI turns, oldest first, ending with the latest question.
  List<AiTurn> _aiHistory() => [
        for (final m in _messages)
          if (m.ai && !m.error) AiTurn(fromUser: !m.fromBot, text: m.text),
      ];

  /// Sends the AI history to the model and adds its answer, or an error
  /// with a retry link.
  Future<void> _askAi(AiRoute route) async {
    final run = ++_run;
    setState(() {
      _options = [];
      _typing = true;
    });
    _afterFrame();
    _Msg msg;
    try {
      final reply = await askAi(route, _store, _aiHistory(), httpClient: widget.httpClient);
      msg = _Msg(true, reply.text, DateTime.now().toIso8601String(), ai: true, model: reply.model);
    } on AiException catch (e) {
      msg = _Msg(true, e.message, DateTime.now().toIso8601String(), ai: true, error: true);
    }
    if (!mounted || run != _run) return;
    setState(() {
      _typing = false;
      _messages.add(msg);
      _node = 'ai';
      _options = [];
    });
    _save();
    _afterFrame();
  }

  /// Removes the failed answer and asks again.
  void _retry() {
    if (_typing || _messages.isEmpty || !_messages.last.error) return;
    final route = routeFreeText(_lastAiQuestion() ?? '', _store);
    setState(() => _messages.removeLast());
    if (route is AiRoute) {
      _askAi(route);
    } else {
      _save();
      _reply(route is LocalRoute ? route.step : buildStep('menu', _store));
    }
  }

  String? _lastAiQuestion() {
    for (final m in _messages.reversed) {
      if (m.ai && !m.fromBot) return m.text;
    }
    return null;
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
    // Crisis and emergency words get the offline safety answer first, and
    // are never sent to the AI model.
    final route = routeFreeText(text, _store);
    switch (route) {
      case LocalRoute(:final step):
        _userSays(text);
        _reply(step);
      case AiRoute():
        _userSays(text, ai: true);
        _askAi(route);
    }
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
    final p = BloomColors.of(context);
    final options = [
      ..._options,
      if (_node != 'menu' && _node != 'start' && _node != 'fallback' && !_options.any((o) => o.next == 'menu'))
        const BotOption('Other topics', next: 'menu'),
    ];
    final showTray = options.isNotEmpty && !_typing;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final aiOn = aiStatusLabel(context.watch<AppStore>()) == 'On';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // Header: a mono eyebrow, the serif title, and thin tools.
          MaxWidth(
            child: Padding(
              padding: EdgeInsets.fromLTRB(canPop ? Space.sm : Space.gutter, Space.sm, Space.sm, Space.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (canPop) const BackButton(),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      child: MonoLabel(
                        _typing ? 'Writing…' : (aiOn ? 'AI answers on' : 'Offline · private'),
                        key: ValueKey((_typing, aiOn)),
                        maxLines: 1,
                      ),
                    ),
                    Gap.v8,
                    Text('Ask', style: Theme.of(context).textTheme.headlineLarge),
                  ]),
                ),
                IconButton(
                  tooltip: 'Symptom checker',
                  icon: Icon(Icons.fact_check_outlined, size: 21, color: p.ink2),
                  onPressed: () => openCheckerList(context),
                ),
                IconButton(
                  tooltip: 'Explain my cycle',
                  icon: Icon(Icons.timeline, size: 21, color: p.ink2),
                  onPressed: _typing ? null : () => _choose(const BotOption('Explain my cycle', next: 'report')),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: Icon(Icons.more_horiz, size: 22, color: p.ink2),
                  onSelected: (v) {
                    if (v == 'clear') _clear();
                    if (v == 'urgent') _choose(const BotOption('Urgent warning signs', next: 'urgent'));
                    if (v == 'ai') openAiSettings(context, httpClient: widget.httpClient);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'urgent', child: Text('Urgent warning signs')),
                    PopupMenuItem(value: 'ai', child: Text('AI answers')),
                    PopupMenuItem(value: 'clear', child: Text('Clear chat history')),
                  ],
                ),
              ]),
            ),
          ),
          const MaxWidth(child: Padding(padding: Insets.pageH, child: Hairline())),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.md),
              itemCount: _messages.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return const MaxWidth(width: Space.maxContentWidth - Space.gutter * 2, child: _SafetyNote());
                if (i == _messages.length + 1) {
                  return MaxWidth(
                    width: Space.maxContentWidth - Space.gutter * 2,
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      child: _typing ? const _Typing() : const SizedBox(width: double.infinity),
                    ),
                  );
                }
                final m = _messages[i - 1];
                final next = i < _messages.length ? _messages[i] : null;
                final lastInGroup = next == null ? !(m.fromBot && _typing) : next.fromBot != m.fromBot;
                final prev = i >= 2 ? _messages[i - 2] : null;
                final firstInGroup = prev == null || prev.fromBot != m.fromBot;
                return MaxWidth(
                  width: Space.maxContentWidth - Space.gutter * 2,
                  child: _Letter(
                    msg: m,
                    lastInGroup: lastInGroup,
                    firstInGroup: firstInGroup,
                    animate: i == _messages.length,
                    onRetry: m.error && i == _messages.length && !_typing ? _retry : null,
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
                      constraints: const BoxConstraints(maxHeight: 176),
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                      child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const MonoLabel('Reply with', size: 9.5),
                          Gap.v8,
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                              for (final o in options)
                                HairlineTag(
                                  label: o.label,
                                  icon: o.articleId != null
                                      ? Icons.menu_book_outlined
                                      : o.checkerId != null
                                          ? Icons.fact_check_outlined
                                          : null,
                                  dot: o.next == 'urgent' ? BloomColors.period : null,
                                  onTap: () => _choose(o),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
          ),
          // Input: an underline field and an ink "Send" link.
          SafeArea(
            top: false,
            child: MaxWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.md, Space.md),
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        style: Almanac.sans(size: 16, color: p.ink),
                        decoration: InputDecoration(
                          hintText: 'Write a question…',
                          hintStyle: Almanac.italic(context, size: 17, color: p.ink2),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
                        ),
                      ),
                    ),
                    Gap.h8,
                    _SendLink(enabled: _hasText && !_typing, onPressed: _send),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// "Send →" as an underlined ink link.
class _SendLink extends StatelessWidget {
  const _SendLink({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Tooltip(
      message: 'Send',
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled ? 1 : 0.4,
        child: Pressable(
          onTap: onPressed,
          borderRadius: Radii.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            child: Center(
              child: Text.rich(TextSpan(children: [
                TextSpan(
                  text: 'Send',
                  style: Almanac.sans(size: 15, weight: FontWeight.w600, color: p.ink).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: p.ink.withValues(alpha: 0.55),
                  ),
                ),
                TextSpan(text: ' →', style: Almanac.sans(size: 15, weight: FontWeight.w600, color: p.ink)),
              ])),
            ),
          ),
        ),
      ),
    );
  }
}

/// The safety note at the top of the conversation, set as a footnote.
class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: Space.xxl),
        child: Footnote(
          'An offline assistant for general education, not a doctor. '
          'In an emergency, call your local emergency number.',
        ),
      );
}

/// The small line-drawn flower beside the assistant's paragraphs.
class _Mark extends StatelessWidget {
  const _Mark({required this.show});
  final bool show;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        child: show
            ? const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Align(alignment: Alignment.topLeft, child: BotanicalGlyph(Botanical.flower, size: 18)),
              )
            : null,
      );
}

/// One message, set like a letter: the assistant's words as typeset
/// paragraphs beside a line-flower mark, the user's in right-aligned
/// italics with a thin rule, and a mono timestamp after each group.
class _Letter extends StatelessWidget {
  const _Letter({
    required this.msg,
    this.lastInGroup = true,
    this.firstInGroup = true,
    this.animate = false,
    this.onRetry,
  });
  final _Msg msg;
  final bool lastInGroup;
  final bool firstInGroup;

  /// Shown as "Try again" under a failed AI answer.
  final VoidCallback? onRetry;

  /// Fades the newest message in.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final bot = msg.fromBot;
    final time = DateTime.tryParse(msg.ts);
    final stamp = time == null ? null : DateFormat.jm().format(time.toLocal());

    final Widget body;
    if (bot) {
      body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Mark(show: firstInGroup),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: Space.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              msg.error
                  ? Text(msg.text, style: Almanac.italic(context, size: 16.5, color: p.ink2).copyWith(height: 1.5))
                  : _LetterText(msg.text),
              if (msg.ai && !msg.error)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    'AI · ${modelDisplayName(msg.model ?? 'free model')} · may be wrong',
                    style: Almanac.data(context, size: 10.5),
                  ),
                ),
              if (onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: InkLink('Try again', arrow: true, onTap: onRetry),
                ),
            ]),
          ),
        ),
      ]);
    } else {
      body = Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.only(left: Space.huge),
            child: Container(
              padding: const EdgeInsets.only(right: Space.md),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: p.ink2.withValues(alpha: 0.6)))),
              child: Text(
                msg.text,
                textAlign: TextAlign.right,
                style: Almanac.italic(context, size: 18.5, weight: 320).copyWith(height: 1.4),
              ),
            ),
          ),
        ),
      );
    }

    Widget row = Padding(
      padding: EdgeInsets.only(bottom: lastInGroup ? Space.xl : Space.sm),
      child: Column(crossAxisAlignment: bot ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
        body,
        if (lastInGroup && stamp != null)
          Padding(
            padding: EdgeInsets.only(top: Space.xs, left: bot ? 28 : 0, right: bot ? 0 : Space.md + 1),
            child: Text(stamp, style: Almanac.data(context, size: 10.5)),
          ),
      ]),
    );

    if (animate) {
      row = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.medium,
        curve: Motion.curve,
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: row,
      );
    }
    return row;
  }
}

/// The assistant's text with the article markup, set as compact paragraphs.
class _LetterText extends StatelessWidget {
  const _LetterText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final base = Almanac.sans(size: 15.5, color: p.ink, height: 1.6);
    final children = <Widget>[];
    for (final raw in text.split('\n')) {
      var line = raw.trimRight();
      final trimmed = line.trimLeft();
      // AI answers can use other markdown: "* " or "• " bullets and "#" headings.
      if (trimmed.startsWith('* ') || trimmed.startsWith('• ')) line = '- ${trimmed.substring(2)}';
      if (trimmed.startsWith('- ')) line = trimmed;
      final heading = RegExp(r'^#{1,6}\s+').firstMatch(trimmed);
      if (heading != null) line = '**${trimmed.substring(heading.end).replaceAll('**', '')}**';
      if (line.trim().isEmpty) {
        children.add(Gap.v8);
      } else if (line.startsWith('- ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 18, child: Text('–', style: base.copyWith(color: p.ink2))),
            Expanded(child: Text.rich(TextSpan(children: ArticleBody.spans(line.substring(2), base)))),
          ]),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.xxs),
          child: Text.rich(TextSpan(children: ArticleBody.spans(line, base))),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// "writing…" in italics beside the mark, with the dots fading in turn.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final style = Almanac.italic(context, size: 16, color: p.ink2);
    return Semantics(
      label: 'The assistant is writing',
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.xl),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Mark(show: true),
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final dots = (_c.value * 4).floor().clamp(0, 3);
              return Text.rich(TextSpan(children: [
                TextSpan(text: 'writing', style: style),
                TextSpan(text: '.' * dots, style: style),
                TextSpan(text: '.' * (3 - dots), style: style.copyWith(color: Colors.transparent)),
              ]));
            },
          ),
        ]),
      ),
    );
  }
}
