import 'dart:async';

import 'package:http/http.dart' as http;

/// Result of opening a stream from the listener's own network.
enum StreamHealth { ok, failed }

/// Checks whether a stream answers with audio. Geo-blocked streams fail here
/// even when a public directory lists them as working, and vice versa.
abstract interface class StreamProbe {
  Future<StreamHealth> check(String url);
}

class HttpStreamProbe implements StreamProbe {
  HttpStreamProbe({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Bytes to read before deciding that audio is flowing.
  static const _enoughBytes = 2048;

  static bool looksLikeAudio(String? contentType) {
    final type = (contentType ?? '').toLowerCase();
    return type.startsWith('audio/') ||
        type.contains('ogg') ||
        type.contains('mpegurl') || // HLS playlists
        type.contains('octet-stream') ||
        type.contains('aac') ||
        type.contains('mpeg');
  }

  @override
  Future<StreamHealth> check(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return StreamHealth.failed;
    StreamSubscription<List<int>>? subscription;
    try {
      final request = http.Request('GET', uri)..headers['Icy-MetaData'] = '0';
      final response = await _client.send(request).timeout(timeout);
      if (response.statusCode != 200 && response.statusCode != 206) {
        return StreamHealth.failed;
      }
      if (!looksLikeAudio(response.headers['content-type'])) {
        return StreamHealth.failed;
      }

      var received = 0;
      final enough = Completer<StreamHealth>();
      subscription = response.stream.listen(
        (chunk) {
          received += chunk.length;
          if (received >= _enoughBytes && !enough.isCompleted) {
            enough.complete(StreamHealth.ok);
          }
        },
        onError: (Object _) {
          if (!enough.isCompleted) enough.complete(StreamHealth.failed);
        },
        onDone: () {
          // Playlists are short and end quickly; that is fine.
          if (!enough.isCompleted) {
            enough.complete(
              received > 0 ? StreamHealth.ok : StreamHealth.failed,
            );
          }
        },
        cancelOnError: true,
      );
      return await enough.future.timeout(
        timeout,
        onTimeout: () => StreamHealth.failed,
      );
    } on Object {
      return StreamHealth.failed;
    } finally {
      unawaited(subscription?.cancel());
    }
  }
}
