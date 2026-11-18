import 'package:web/web.dart' as web;

/// Saves [url] as [fileName] with a same-origin `<a download>` link, so the
/// browser downloads the file instead of opening it.
void saveUrl(Uri url, String fileName) {
  final a = web.HTMLAnchorElement()
    ..href = url.toString()
    ..download = fileName
    ..rel = 'noopener';
  a.style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
}
