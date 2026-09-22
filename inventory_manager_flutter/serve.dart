import 'dart:io';

// Minimal static file server for the Flutter web build.
// Usage: dart run serve.dart <webRoot> [port]
void main(List<String> args) async {
  final webRoot = args.isNotEmpty ? args[0] : 'build/web';
  final port = args.length > 1 ? int.parse(args[1]) : 8080;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Serving "$webRoot" at http://localhost:$port');

  await for (final request in server) {
    final path = request.uri.path;
    final filePath = '$webRoot${path == '/' ? '/index.html' : path}';
    var file = File(filePath);

    if (!await file.exists()) {
      // SPA fallback: serve index.html for client-side routes
      file = File('$webRoot/index.html');
    }
    final type = _mimeType(file.path);
    request.response.headers.contentType = ContentType.parse(type);
    await request.response.addStream(file.openRead());
    await request.response.close();
  }
}

String _mimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
  if (lower.endsWith('.js')) return 'application/javascript';
  if (lower.endsWith('.mjs')) return 'application/javascript';
  if (lower.endsWith('.wasm')) return 'application/wasm';
  if (lower.endsWith('.css')) return 'text/css';
  if (lower.endsWith('.json')) return 'application/json';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.ico')) return 'image/x-icon';
  if (lower.endsWith('.txt')) return 'text/plain; charset=utf-8';
  if (lower.endsWith('.woff')) return 'font/woff';
  if (lower.endsWith('.woff2')) return 'font/woff2';
  if (lower.endsWith('.ttf')) return 'font/ttf';
  if (lower.endsWith('.otf')) return 'font/otf';
  return 'application/octet-stream';
}
