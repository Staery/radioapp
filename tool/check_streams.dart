// Checks every stream of the bundled station list from this computer.
//
//   dart run tool/check_streams.dart            # assets/stations.json
//   dart run tool/check_streams.dart my.json    # another list in the same format
//
// Prints one line per station and exits with code 1 when a stream fails.
// Run it from the network you care about: some stations only work from
// Belarus, others only from abroad.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final file = File(args.isEmpty ? 'assets/stations.json' : args.first);
  final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  final stations = (json['stations']! as List<Object?>)
      .cast<Map<String, Object?>>();

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  var failed = 0;
  for (final station in stations) {
    final name = station['name']! as String;
    final url = station['streamUrl']! as String;
    final result = await _check(client, url);
    if (!result.ok) failed++;
    stdout.writeln(
      '${result.ok ? 'OK  ' : 'FAIL'}  ${name.padRight(26)} ${result.detail.padRight(28)} $url',
    );
  }
  client.close(force: true);
  stdout.writeln(
    '\n${stations.length - failed} of ${stations.length} streams work from this network.',
  );
  exitCode = failed == 0 ? 0 : 1;
}

Future<({bool ok, String detail})> _check(HttpClient client, String url) async {
  try {
    final request = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    request.headers.set('Icy-MetaData', '0');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final type = response.headers.contentType?.mimeType ?? '?';
    if (response.statusCode != 200) {
      unawaited(response.drain<void>().catchError((Object _) {}));
      return (ok: false, detail: 'HTTP ${response.statusCode}');
    }
    var bytes = 0;
    await for (final chunk in response.timeout(const Duration(seconds: 8))) {
      bytes += chunk.length;
      if (bytes >= 4096) break;
    }
    final audio =
        type.startsWith('audio/') ||
        type.contains('ogg') ||
        type.contains('mpegurl') ||
        type.contains('octet-stream') ||
        type.contains('aac') ||
        type.contains('mpeg');
    return (ok: audio && bytes > 0, detail: '$type, ${bytes}B');
  } on TimeoutException {
    return (ok: false, detail: 'timeout');
  } on Object catch (error) {
    final text = error.toString().split('\n').first;
    return (ok: false, detail: text.length > 28 ? text.substring(0, 28) : text);
  }
}
