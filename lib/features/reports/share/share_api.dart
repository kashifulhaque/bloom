/// Talks to the report share service at `/api/share` on Bloom's web server.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/store.dart';
import '../../assistant/ai/ai_settings.dart' show resolveProxyUrl;
import 'share_crypto.dart';
import 'share_link.dart';

/// The share service, from `--dart-define=BLOOM_SHARE_API=...`. A relative
/// path such as `/api/share` resolves against the page's address on the web.
/// Phones need an absolute URL, such as `https://bloom.ifkash.dev/api/share`.
/// Empty means the build has no sharing, and the button is hidden.
const String kShareApiSetting = String.fromEnvironment('BLOOM_SHARE_API');

/// The share service URL, or null when this build has none.
Uri? resolveShareApi([String raw = kShareApiSetting, Uri? base]) => resolveProxyUrl(raw, base: base);

/// What the server returns for a new upload.
class CreatedShare {
  const CreatedShare({required this.id, required this.revokeToken, required this.expiresAt});
  final String id;
  final String revokeToken;
  final DateTime expiresAt;
}

/// A request to the share service failed. [message] is safe to show.
class ShareApiException implements Exception {
  const ShareApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

abstract class ReportShareApi {
  /// The service's address. Links are built on its origin.
  Uri get endpoint;

  Future<CreatedShare> create(Uint8List box, ShareExpiry expiry);

  /// Fetches the encrypted report. Throws [ShareApiException] with status 404
  /// when the link has expired or was turned off.
  Future<Uint8List> fetch(String id);

  Future<void> revoke(String id, String revokeToken);
}

class HttpReportShareApi implements ReportShareApi {
  HttpReportShareApi(this.endpoint, {http.Client? client}) : _client = client ?? http.Client();

  @override
  final Uri endpoint;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  Uri _item(String id) => endpoint.replace(pathSegments: [...endpoint.pathSegments.where((s) => s.isNotEmpty), id]);

  @override
  Future<CreatedShare> create(Uint8List box, ShareExpiry expiry) async {
    final res = await _send(() => _client.post(
          endpoint.replace(queryParameters: {'days': '${expiry.days}'}),
          headers: {'Content-Type': 'application/octet-stream'},
          body: box,
        ));
    if (res.statusCode != 201) throw _failure(res);
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return CreatedShare(
        id: j['id'] as String,
        revokeToken: j['revokeToken'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
    } catch (_) {
      throw const ShareApiException('The share service sent an unexpected reply.');
    }
  }

  @override
  Future<Uint8List> fetch(String id) async {
    final res = await _send(() => _client.get(_item(id)));
    if (res.statusCode != 200) throw _failure(res);
    return res.bodyBytes;
  }

  @override
  Future<void> revoke(String id, String revokeToken) async {
    final res = await _send(() => _client.delete(_item(id), headers: {'X-Bloom-Revoke-Token': revokeToken}));
    if (res.statusCode != 204 && res.statusCode != 404) throw _failure(res);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } catch (_) {
      throw const ShareApiException('Couldn\'t reach the share service. Check your connection, then try again.');
    }
  }

  static ShareApiException _failure(http.Response res) {
    String? message;
    try {
      message = ((jsonDecode(res.body) as Map)['error'] as Map)['message'] as String?;
    } catch (_) {}
    return ShareApiException(
      message ?? switch (res.statusCode) {
        404 => 'This link has expired or was turned off.',
        413 => 'The report is too large to share.',
        429 => 'Too many links in a short time. Wait a few minutes, then try again.',
        503 => 'Sharing isn\'t available right now. Try again later.',
        _ => 'The share service returned an error (${res.statusCode}).',
      },
      status: res.statusCode,
    );
  }
}

/// Creates and revokes links, and keeps the store's list in step.
class ReportSharer {
  ReportSharer(this.api, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ReportShareApi api;
  final DateTime Function() _clock;

  /// Encrypts [pdf] with a fresh key, uploads only the ciphertext, saves the
  /// link in [store], and returns it.
  Future<SharedReportLink> create(AppStore store, Uint8List pdf, ShareExpiry expiry) async {
    final sealed = await ReportShareCrypto.seal(pdf);
    final created = await api.create(sealed.box, expiry);
    final now = _clock();
    final link = SharedReportLink(
      id: created.id,
      url: buildShareLink(api.endpoint, created.id, ReportShareCrypto.encodeKey(sealed.key)).toString(),
      revokeToken: created.revokeToken,
      createdAt: now,
      expiresAt: created.expiresAt,
    );
    store.addReportLink(link, now);
    return link;
  }

  /// Turns [link] off on the server, then forgets it.
  Future<void> revoke(AppStore store, SharedReportLink link) async {
    // An expired link is already unreadable, so only forget it.
    if (link.isActive(_clock())) await api.revoke(link.id, link.revokeToken);
    store.removeReportLink(link.id);
  }
}
