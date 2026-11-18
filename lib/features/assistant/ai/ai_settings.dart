/// Settings for the optional AI answers, stored under the `assistant_ai`
/// feature key as `{enabled, shareSummary, userKey, consentAt}`.
library;

import '../../../core/store.dart';

/// The store feature key for these settings.
const String kAiFeatureKey = 'assistant_ai';

/// A key compiled into the app with
/// `--dart-define-from-file=../.env` (`OPENROUTER_API_KEY=...`). Empty when
/// none was given. Anyone with the app can extract it.
const String kBuildTimeKey = String.fromEnvironment('OPENROUTER_API_KEY');

/// The hosted proxy that answers without a key in the app, from
/// `--dart-define=BLOOM_AI_PROXY=...`. A relative path such as
/// `/api/ai/chat` resolves against the page's address on the web. An
/// absolute URL, such as `https://bloom.ifkash.dev/api/ai/chat`, is used as
/// is. Empty when none was given.
const String kProxySetting = String.fromEnvironment('BLOOM_AI_PROXY');

/// Where AI answers come from.
enum KeySource {
  /// A key the user saved in the app, sent straight to OpenRouter.
  user,

  /// A key compiled in for local development, sent straight to OpenRouter.
  buildTime,

  /// Bloom's hosted proxy, which adds its own key.
  proxy,

  /// Nothing is set up, so AI answers are unavailable.
  none,
}

class AiSettings {
  const AiSettings({this.enabled = false, this.shareSummary = false, this.userKey, this.consentAt});

  /// AI answers are off by default.
  final bool enabled;

  /// Sends the cycle summary with each question. Off by default.
  final bool shareSummary;

  /// A key the user entered in the app. Takes priority over [kBuildTimeKey].
  final String? userKey;

  /// ISO time the user accepted the consent sheet.
  final String? consentAt;

  bool get hasConsent => consentAt != null;

  static AiSettings of(AppStore store) => AiSettings.fromJson(store.feature<Map>(kAiFeatureKey));

  factory AiSettings.fromJson(Map? j) {
    if (j == null) return const AiSettings();
    final key = j['userKey'];
    return AiSettings(
      enabled: j['enabled'] == true,
      shareSummary: j['shareSummary'] == true,
      userKey: key is String && key.trim().isNotEmpty ? key.trim() : null,
      consentAt: j['consentAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'shareSummary': shareSummary,
        'userKey': userKey,
        'consentAt': consentAt,
      };

  AiSettings copyWith({bool? enabled, bool? shareSummary, String? consentAt}) => AiSettings(
        enabled: enabled ?? this.enabled,
        shareSummary: shareSummary ?? this.shareSummary,
        userKey: userKey,
        consentAt: consentAt ?? this.consentAt,
      );

  /// A copy with [key] as the user key; null or blank removes it.
  AiSettings withUserKey(String? key) => AiSettings(
        enabled: enabled,
        shareSummary: shareSummary,
        userKey: key == null || key.trim().isEmpty ? null : key.trim(),
        consentAt: consentAt,
      );

  void save(AppStore store) => store.setFeature(kAiFeatureKey, toJson());

  @override
  String toString() => 'AiSettings(enabled: $enabled, shareSummary: $shareSummary, '
      'userKey: ${userKey == null ? 'none' : 'set'}, consentAt: $consentAt)';
}

/// The key to use: the user's key, then the build-time key, then none.
/// The proxy isn't a key; see [resolveAiEndpoint].
({String? key, KeySource source}) resolveApiKey(AiSettings s, {String buildKey = kBuildTimeKey}) {
  if (s.userKey != null) return (key: s.userKey, source: KeySource.user);
  final b = buildKey.trim();
  if (b.isNotEmpty) return (key: b, source: KeySource.buildTime);
  return (key: null, source: KeySource.none);
}

/// The OpenRouter chat completions endpoint.
final Uri kOpenRouterUrl = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

/// Where an AI request goes, and the key to send with it.
class AiEndpoint {
  const AiEndpoint({required this.url, required this.source, this.apiKey});

  /// The chat completions URL: OpenRouter, or the proxy.
  final Uri url;

  /// The OpenRouter key. Null for the proxy, which adds its own.
  final String? apiKey;

  final KeySource source;

  bool get isProxy => source == KeySource.proxy;

  @override
  String toString() => 'AiEndpoint($source, $url)';
}

/// Resolves the proxy setting [raw] to a URL, or null when it's empty or
/// isn't an http or https address. A relative value resolves against
/// [base], which defaults to [Uri.base] (the page's address on the web).
Uri? resolveProxyUrl(String raw, {Uri? base}) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final Uri parsed;
  try {
    parsed = Uri.parse(value);
  } on FormatException {
    return null;
  }
  final url = parsed.hasScheme ? parsed : (base ?? Uri.base).resolveUri(parsed);
  if ((url.scheme != 'https' && url.scheme != 'http') || url.host.isEmpty) return null;
  return url;
}

/// Picks where AI answers come from, in this order: the user's key, then
/// the build-time key (both go straight to OpenRouter), then the hosted
/// proxy. Returns null when none is set up.
AiEndpoint? resolveAiEndpoint(
  AiSettings s, {
  String buildKey = kBuildTimeKey,
  String proxy = kProxySetting,
  Uri? base,
}) {
  final k = resolveApiKey(s, buildKey: buildKey);
  if (k.key != null) return AiEndpoint(url: kOpenRouterUrl, apiKey: k.key, source: k.source);
  final url = resolveProxyUrl(proxy, base: base);
  if (url != null) return AiEndpoint(url: url, source: KeySource.proxy);
  return null;
}

/// The source [resolveAiEndpoint] would pick, or [KeySource.none].
KeySource aiSource(AiSettings s, {String buildKey = kBuildTimeKey, String proxy = kProxySetting, Uri? base}) =>
    resolveAiEndpoint(s, buildKey: buildKey, proxy: proxy, base: base)?.source ?? KeySource.none;

/// The endpoint to answer with, or null when AI answers are off, not
/// consented to, or have no source.
AiEndpoint? activeEndpoint(
  AiSettings s, {
  String buildKey = kBuildTimeKey,
  String proxy = kProxySetting,
  Uri? base,
}) {
  if (!s.enabled || !s.hasConsent) return null;
  return resolveAiEndpoint(s, buildKey: buildKey, proxy: proxy, base: base);
}
