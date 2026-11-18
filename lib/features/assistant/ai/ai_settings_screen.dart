/// The "AI answers" settings page and the consent sheet shown the first
/// time the user turns AI answers on.
library;

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/store.dart';
import '../../../widgets/widgets.dart';
import '../../settings/settings_widgets.dart' show SettingsPage;
import 'ai_chat.dart' show modelDisplayName;
import 'ai_settings.dart';
import 'cycle_summary.dart';
import 'openrouter_client.dart';

/// Opens the AI answers settings page.
Future<void> openAiSettings(BuildContext context, {http.Client? httpClient}) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiSettingsScreen(httpClient: httpClient)),
    );

/// A one-line status for menus: "Off", "On", or "No key".
String aiStatusLabel(AppStore store) {
  final s = AiSettings.of(store);
  if (!s.enabled || !s.hasConsent) return 'Off';
  return aiSource(s) == KeySource.none ? 'No key' : 'On';
}

/// A plain sentence that says where AI answers come from.
String aiSourceLabel(KeySource source) => switch (source) {
      KeySource.user => 'Using your own OpenRouter key. Questions go straight to OpenRouter.',
      KeySource.buildTime => 'Using the key built into this copy of Bloom, for development. '
          'Questions go straight to OpenRouter.',
      KeySource.proxy => "Using Bloom's shared free AI service. You don't need a key.",
      KeySource.none => 'No key yet. Create a free key at openrouter.ai/keys and paste it here.',
    };

/// Where questions go first, in the consent text: the proxy's host name,
/// or OpenRouter.
String _firstHop(AiEndpoint? e) {
  if (e == null || !e.isProxy) return 'OpenRouter, and from there to whichever free AI model provider answers';
  return "Bloom's AI service at ${e.url.host}, then to OpenRouter, and from there to whichever free "
      'AI model provider answers';
}

/// Shows the consent sheet for [endpoint] (where questions would go).
/// Returns true when the user agrees.
Future<bool> showAiConsentSheet(BuildContext context, {AiEndpoint? endpoint}) async {
  final ok = await showAppBottomSheet<bool>(
    context,
    builder: (c) {
      final theme = Theme.of(c);
      Widget point(String label, String text) => Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Marginalia(
              label: label,
              labelWidth: 100,
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          );
      return AppBottomSheet(
        eyebrow: 'Before you turn this on',
        title: 'AI answers use the internet',
        subtitle: 'Read this once. You can turn AI answers off at any time.',
        actions: [
          InkButton.outlined(label: 'Not now', onPressed: () => Navigator.pop(c, false)),
          InkButton(label: 'Turn on', onPressed: () => Navigator.pop(c, true)),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          point('Sent', 'The questions you type in Ask go over the internet to ${_firstHop(endpoint)}.'),
          if (endpoint != null && endpoint.isProxy)
            point(
              'Shared',
              '${endpoint.url.host} sees your IP address, which it uses to limit how many questions '
                  'each person can ask. Add your own OpenRouter key to skip it.',
            ),
          point(
            'Logged',
            'Free model providers might log your questions or use them to train their models. '
                "Don't type anything you want to keep private, such as your name.",
          ),
          point(
            'Accuracy',
            "Answers can be wrong. They're general information, not medical advice. "
                'Talk to a clinician about any health concern.',
          ),
          point(
            'Stays here',
            'Nothing else in Bloom leaves this device. Your cycle summary is sent only if you '
                'turn on "Include my cycle summary". Urgent and crisis messages always get '
                'the offline safety answer.',
          ),
        ]),
      );
    },
  );
  return ok == true;
}

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key, this.httpClient, this.buildKey = kBuildTimeKey, this.proxy = kProxySetting});

  /// Used by "Test connection". Tests pass a mock client.
  final http.Client? httpClient;

  /// The build-time key and proxy setting. Tests override them.
  final String buildKey;
  final String proxy;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _keyField = TextEditingController();
  bool _hasTyped = false;
  bool _testing = false;

  /// The last test result: (ok, message).
  (bool, String)? _test;

  @override
  void initState() {
    super.initState();
    _keyField.addListener(() {
      final has = _keyField.text.trim().isNotEmpty;
      if (has != _hasTyped) setState(() => _hasTyped = has);
    });
  }

  @override
  void dispose() {
    _keyField.dispose();
    super.dispose();
  }

  AppStore get _store => context.read<AppStore>();

  AiEndpoint? _endpoint(AiSettings s) => resolveAiEndpoint(s, buildKey: widget.buildKey, proxy: widget.proxy);

  Future<void> _setEnabled(bool on) async {
    var s = AiSettings.of(_store);
    if (on && !s.hasConsent) {
      final ok = await showAiConsentSheet(context, endpoint: _endpoint(s));
      if (!ok || !mounted) return;
      s = s.copyWith(consentAt: DateTime.now().toIso8601String());
    }
    s.copyWith(enabled: on).save(_store);
  }

  void _saveKey() {
    final key = _keyField.text.trim();
    if (key.isEmpty) return;
    AiSettings.of(_store).withUserKey(key).save(_store);
    _keyField.clear();
    FocusScope.of(context).unfocus();
    setState(() => _test = null);
  }

  void _removeKey() {
    AiSettings.of(_store).withUserKey(null).save(_store);
    setState(() => _test = null);
  }

  Future<void> _testConnection() async {
    final endpoint = _endpoint(AiSettings.of(_store));
    if (endpoint == null || _testing) return;
    setState(() {
      _testing = true;
      _test = null;
    });
    final client = OpenRouterClient.to(endpoint, httpClient: widget.httpClient);
    (bool, String) result;
    try {
      final reply = await client.complete(
        const [AiMessage.user('Reply with the single word: ready')],
        maxTokens: 300,
        allowEmpty: true,
      );
      result = (true, 'Connected. ${modelDisplayName(reply.model)} answered.');
    } on AiException catch (e) {
      result = (false, e.message);
    } finally {
      client.close();
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _test = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final s = AiSettings.of(store);
    final on = s.enabled && s.hasConsent;
    final source = _endpoint(s)?.source ?? KeySource.none;
    // Whether the app has a source to fall back on without the user's key.
    final hasFallback = resolveAiEndpoint(s.withUserKey(null), buildKey: widget.buildKey, proxy: widget.proxy) != null;

    return SettingsPage(
      eyebrow: 'Ask · Optional',
      title: 'AI answers',
      subtitle: 'Answer typed questions with a free AI model through OpenRouter. '
          'The topics, checkers, and safety answers stay offline.',
      children: [
        MenuSection(
          title: 'Answers',
          footer: on && source == KeySource.none ? 'Add a key to start getting AI answers.' : null,
          children: [
            MenuTile.toggle(
              title: 'AI answers',
              subtitle: on ? 'Typed questions go to a free model' : 'Off. Ask answers offline.',
              value: on,
              onChanged: _setEnabled,
            ),
            MenuTile.toggle(
              title: 'Include my cycle summary',
              subtitle: 'Sends the summary under "What\'s shared" with each question',
              value: s.shareSummary,
              onChanged: (v) => s.copyWith(shareSummary: v).save(store),
            ),
          ],
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MonoLabel(hasFallback ? 'Your OpenRouter key · optional' : 'OpenRouter key'),
          Gap.v8,
          TextField(
            key: const ValueKey('ai-key-field'),
            controller: _keyField,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            style: Almanac.mono(size: 15, color: p.ink),
            decoration: InputDecoration(
              hintText: source == KeySource.user ? 'Saved. Paste a new key to replace it.' : 'Paste your key',
              hintStyle: Almanac.italic(context, size: 16, color: p.ink2),
            ),
            onSubmitted: (_) => _saveKey(),
          ),
          Gap.v8,
          Text(
            source == KeySource.user || source == KeySource.none
                ? aiSourceLabel(source)
                : 'Optional. A free key from openrouter.ai/keys sends your questions straight to OpenRouter.',
            style: theme.textTheme.bodySmall,
          ),
          Gap.v16,
          Wrap(spacing: Space.md, runSpacing: Space.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
            InkButton(label: 'Save key', onPressed: _hasTyped ? _saveKey : null),
            InkButton.outlined(
              label: 'Test connection',
              loading: _testing,
              onPressed: source == KeySource.none || _testing ? null : _testConnection,
            ),
            if (source == KeySource.user) InkLink('Remove my key', onTap: _removeKey),
          ]),
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.curve,
            alignment: Alignment.topLeft,
            child: _test == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.lg),
                    child: InfoBanner(
                      tone: _test!.$1 ? BannerTone.success : BannerTone.warning,
                      title: _test!.$1 ? 'It works' : "Couldn't connect",
                      message: _test!.$2,
                    ),
                  ),
          ),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Hairline(),
          Gap.v16,
          Marginalia(
            label: 'Source',
            child: Text(
              aiSourceLabel(source),
              key: const ValueKey('ai-source'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Gap.v16,
          Marginalia(
            label: 'Model',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kAiModel, style: Almanac.data(context, color: p.ink, size: 13.5)),
              Gap.v4,
              Text(
                "OpenRouter's free router picks an available free model for each question. "
                'Bloom only uses free models.',
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
        ]),
        _SharedPreview(summary: buildCycleSummary(store), included: s.shareSummary),
        const Disclaimer(
          text: 'AI answers can be wrong and are not medical advice. Talk to a clinician about any '
              'health concern. In an emergency, call your local emergency number.',
        ),
      ],
    );
  }
}

/// "What's shared": the exact text sent with each question.
class _SharedPreview extends StatelessWidget {
  const _SharedPreview({required this.summary, required this.included});
  final String summary;
  final bool included;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader("What's shared", label: 'Preview'),
      Gap.v8,
      Text(
        included
            ? 'Each question is sent with Bloom\'s instructions, your last few typed questions '
                'and AI answers, and this summary:'
            : 'Each question is sent with Bloom\'s instructions and your last few typed questions '
                'and AI answers. This summary is sent only when "Include my cycle summary" is on:',
        style: theme.textTheme.bodyMedium!.copyWith(color: p.ink2),
      ),
      Gap.v12,
      AnimatedOpacity(
        duration: Motion.medium,
        opacity: included ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.only(left: Space.md, top: Space.xs, bottom: Space.xs),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: p.ink2.withValues(alpha: 0.5)))),
          child: SelectableText(
            summary,
            key: const ValueKey('ai-summary-preview'),
            style: Almanac.data(context, color: p.ink, size: 12.5).copyWith(height: 1.7),
          ),
        ),
      ),
      Gap.v8,
      Text(
        'Never sent: your name, notes, journal, birth year, or any dates.',
        style: theme.textTheme.bodySmall,
      ),
    ]);
  }
}
