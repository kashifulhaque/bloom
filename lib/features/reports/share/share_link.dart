/// Share links the user has made, kept in the `report_shares` feature key.
///
/// Each entry holds the full link (so the user can copy it again), the token
/// that turns it off, and its expiry. The feature syncs end-to-end encrypted
/// like the rest of the app's data, so another signed-in device can turn a
/// link off too.
library;

import '../../../core/store.dart';

/// The store feature key for share links.
const String kReportSharesKey = 'report_shares';

/// How long a link lasts.
enum ShareExpiry {
  day(1, '1 day'),
  week(7, '7 days'),
  month(30, '30 days');

  const ShareExpiry(this.days, this.label);
  final int days;
  final String label;

  static const fallback = ShareExpiry.week;
}

class SharedReportLink {
  const SharedReportLink({
    required this.id,
    required this.url,
    required this.revokeToken,
    required this.createdAt,
    required this.expiresAt,
  });

  /// The server's id for the encrypted report.
  final String id;

  /// The full link, including the key in the fragment.
  final String url;

  /// Proves to the server that this device may turn the link off.
  final String revokeToken;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isActive(DateTime now) => expiresAt.isAfter(now);

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'revokeToken': revokeToken,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  static SharedReportLink? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], url = j['url'], token = j['revokeToken'];
    final created = DateTime.tryParse('${j['createdAt']}');
    final expires = DateTime.tryParse('${j['expiresAt']}');
    if (id is! String || url is! String || token is! String || created == null || expires == null) return null;
    return SharedReportLink(id: id, url: url, revokeToken: token, createdAt: created, expiresAt: expires);
  }
}

/// Builds the link a clinician opens: `<origin>/r/<id>#<key>`.
Uri buildShareLink(Uri api, String id, String key) =>
    Uri(scheme: api.scheme, host: api.host, port: api.hasPort ? api.port : null, path: '/r/$id', fragment: key);

/// Reads and writes the list in the store.
extension ReportShareStore on AppStore {
  /// Every saved link, newest first, including expired ones.
  List<SharedReportLink> get sharedReportLinks {
    final raw = feature<List>(kReportSharesKey) ?? const [];
    return raw.map(SharedReportLink.fromJson).whereType<SharedReportLink>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Links that haven't expired yet, newest first.
  List<SharedReportLink> activeReportLinks(DateTime now) =>
      sharedReportLinks.where((l) => l.isActive(now)).toList();

  /// Adds [link] and drops links that expired more than a day ago.
  void addReportLink(SharedReportLink link, DateTime now) {
    final keep = sharedReportLinks.where((l) => l.id != link.id && l.expiresAt.isAfter(now.subtract(const Duration(days: 1))));
    _saveLinks([link, ...keep]);
  }

  void removeReportLink(String id) => _saveLinks(sharedReportLinks.where((l) => l.id != id));

  void _saveLinks(Iterable<SharedReportLink> links) {
    final list = links.map((l) => l.toJson()).toList();
    setFeature(kReportSharesKey, list.isEmpty ? null : list);
  }
}
