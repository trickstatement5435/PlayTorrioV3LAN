import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/movie/movie.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/stream/stream_model.dart';
import '../../models/subtitle/subtitle_model.dart';
import '../debrid/debrid_service.dart';
import '../lan_cast/lan_cast_service.dart';
import '../metadata/metadata_service.dart';
import '../player/player_settings.dart';
import '../stream/stream_service.dart';
import '../stream/torrent_stream_service.dart';
import '../subtitles/subtitle_service.dart';
import 'web_ui_page.dart';

/// One address the web player can be opened at.
class WebUiUrl {
  final String adapter;
  final String url;
  const WebUiUrl(this.adapter, this.url);
}

class WebUiStatus {
  final bool enabled;
  final bool running;
  final int port;
  final List<WebUiUrl> urls;
  final String? error;
  final int activeStreams;

  const WebUiStatus({
    this.enabled = false,
    this.running = false,
    this.port = WebUiServer.defaultPort,
    this.urls = const [],
    this.error,
    this.activeStreams = 0,
  });

  WebUiStatus copyWith({int? activeStreams}) => WebUiStatus(
        enabled: enabled,
        running: running,
        port: port,
        urls: urls,
        error: error,
        activeStreams: activeStreams ?? this.activeStreams,
      );
}

/// A browser-based player for other devices on the home network.
///
/// Starts with the app (unless turned off in Settings) and serves a small
/// web app at `http://<this-pc>:8777/<token>/`: browse and search titles,
/// pick episodes and sources, and watch in Chrome/Firefox with a
/// YouTube-style quality menu, audio/subtitle choices and seeking.
///
/// Playback modes:
///  * **Auto / 1080p/720p/480p/360p** (default): this PC re-encodes to plain
///    H.264 + AAC at that size, so the viewing device only plays an easy
///    stream. This PC does the heavy lifting.
///  * **Original**: the video is sent untouched (MP4s the browser supports
///    are proxied with Range for native seeking; others are copied into
///    fragmented MP4), and the viewing device decodes it.
///
/// Seeking in the last two modes restarts FFmpeg at the new time (`t=`).
class WebUiServer {
  WebUiServer._();
  static final WebUiServer instance = WebUiServer._();

  static const int defaultPort = 8777;
  static const String cinemeta = 'https://v3-cinemeta.strem.io';
  static const int _maxSessions = 3;

  static const _prefEnabled = 'web_ui_enabled';
  static const _prefPort = 'web_ui_port';
  static const _prefToken = 'web_ui_token';

  final ValueNotifier<WebUiStatus> status = ValueNotifier(const WebUiStatus());

  HttpServer? _server;
  String _token = '';
  int _port = defaultPort;
  Timer? _janitor;
  bool _initialized = false;

  final Map<String, _SourceJob> _jobs = {};
  final Map<String, _Session> _sessions = {};
  final HttpClient _http = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 20)
    // Same as the in-app player (mpv), which doesn't verify TLS either.
    ..badCertificateCallback = (_, _, _) => true;

  bool get isRunning => _server != null;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle & settings
  // ─────────────────────────────────────────────────────────────────────────

  /// Called once from main(). Starts the server if it's enabled.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final p = await SharedPreferences.getInstance();
      final enabled = p.getBool(_prefEnabled) ?? true;
      _port = p.getInt(_prefPort) ?? defaultPort;
      if (enabled) {
        await start();
      } else {
        status.value = WebUiStatus(enabled: false, port: _port);
      }
    } catch (e) {
      debugPrint('[WebUI] init failed: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefEnabled, enabled);
    if (enabled) {
      await start();
    } else {
      await stop();
      status.value = WebUiStatus(enabled: false, port: _port);
    }
  }

  Future<void> setPort(int port) async {
    if (port <= 0 || port > 65535) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefPort, port);
    _port = port;
    if (isRunning) {
      await stop();
      await start();
    }
  }

  /// New random link; the old one stops working immediately.
  Future<void> resetLink() async {
    _token = _randomToken();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefToken, _token);
    } catch (_) {}
    if (isRunning) await _publishStatus();
  }

  Future<void> start() async {
    if (_server != null) return;
    _token = await _loadToken();
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
    } on SocketException catch (e) {
      debugPrint('[WebUI] port $_port busy: $e');
      status.value = WebUiStatus(
        enabled: true,
        port: _port,
        error: 'Port $_port is already in use. Pick another port in Settings > Web Player.',
      );
      return;
    }
    _server!.autoCompress = false; // never gzip video/range responses
    _server!.idleTimeout = null;
    _server!.listen(_handle, onError: (e) => debugPrint('[WebUI] server error: $e'));
    _janitor?.cancel();
    _janitor = Timer.periodic(const Duration(minutes: 1), (_) => _sweep());
    debugPrint('[WebUI] listening on 0.0.0.0:$_port');
    await _publishStatus();
  }

  Future<void> stop() async {
    _janitor?.cancel();
    _janitor = null;
    for (final s in _sessions.values.toList()) {
      await _closeSession(s);
    }
    _sessions.clear();
    for (final j in _jobs.values) {
      j.cancel();
    }
    _jobs.clear();
    final s = _server;
    _server = null;
    if (s != null) {
      try {
        await s.close(force: true);
      } catch (_) {}
    }
  }

  Future<void> _publishStatus() async {
    final addrs = await LanCastService.lanAddresses();
    status.value = WebUiStatus(
      enabled: true,
      running: isRunning,
      port: _port,
      urls: [for (final (name, a) in addrs) WebUiUrl(name, 'http://$a:$_port/$_token/')],
      activeStreams: _sessions.values.where((s) => s.encoder != null || s.rawClients > 0).length,
    );
  }

  void _updateActivity() {
    if (!isRunning) return;
    status.value = status.value.copyWith(
      activeStreams: _sessions.values.where((s) => s.encoder != null || s.rawClients > 0).length,
    );
  }

  /// Re-lists network addresses (e.g. after switching Wi-Fi).
  Future<void> refreshUrls() async {
    if (isRunning) await _publishStatus();
  }

  Future<String> _loadToken() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_prefToken);
      if (saved != null && RegExp(r'^[a-z0-9]{6,32}$').hasMatch(saved)) return saved;
      final t = _randomToken();
      await p.setString(_prefToken, t);
      return t;
    } catch (_) {
      return _randomToken();
    }
  }

  static String _randomToken() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }

  void _sweep() {
    final now = DateTime.now();
    for (final s in _sessions.values.toList()) {
      final busy = s.encoder != null || s.rawClients > 0;
      if (!busy && now.difference(s.lastActive) > const Duration(minutes: 20)) {
        _closeSession(s);
      }
    }
    _jobs.removeWhere((_, j) {
      final old = now.difference(j.created) > const Duration(minutes: 30);
      if (old) j.cancel();
      return old;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Routing
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final segs = req.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isEmpty || segs.first != _token) {
        res.statusCode = segs.isEmpty ? HttpStatus.ok : HttpStatus.notFound;
        res.headers.contentType = ContentType.html;
        res.write('<!doctype html><meta name="viewport" content="width=device-width">'
            '<body style="background:#0b0d12;color:#ccc;font-family:system-ui;padding:40px">'
            '<h3>PlayTorrio web player</h3><p>Open the full link shown in PlayTorrio under '
            'Settings &gt; Web Player.</p></body>');
        await res.close();
        return;
      }
      // Make relative URLs in the page work: /<token> -> /<token>/
      if (segs.length == 1 && !req.uri.path.endsWith('/')) {
        res.statusCode = HttpStatus.movedPermanently;
        res.headers.set(HttpHeaders.locationHeader, '/$_token/');
        await res.close();
        return;
      }
      final route = segs.skip(1).join('/');

      if (route.isEmpty || route == 'index.html') {
        res.headers.contentType = ContentType.html;
        res.headers.set('Cache-Control', 'no-cache');
        res.write(kWebUiHtml);
        await res.close();
        return;
      }

      // Media routes: s/<sid>/video.mp4 | s/<sid>/raw
      if (segs.length >= 4 && segs[1] == 's') {
        final s = _sessions[segs[2]];
        if (s == null || s.state != 'ready') {
          res.statusCode = HttpStatus.notFound;
          await res.close();
          return;
        }
        s.lastActive = DateTime.now();
        if (segs[3] == 'raw') {
          await _serveRaw(req, s);
        } else {
          await _serveVideo(req, s);
        }
        return;
      }

      switch (route) {
        case 'api/status':
          final ff = await LanCastService.instance.findFfmpeg(await LanCastService.instance.savedFfmpegPath());
          await _json(res, {'ffmpeg': ff != null, 'version': 1});
          return;
        case 'api/home':
          await _apiHome(req);
          return;
        case 'api/search':
          await _apiSearch(req);
          return;
        case 'api/meta':
          await _apiMeta(req);
          return;
        case 'api/sources/start':
          await _apiSourcesStart(req);
          return;
        case 'api/sources/poll':
          await _apiSourcesPoll(req);
          return;
        case 'api/play':
          await _apiPlay(req);
          return;
        case 'api/session':
          await _apiSession(req);
          return;
        case 'api/session/stop':
          await _apiSessionStop(req);
          return;
        case 'api/subs':
          await _apiSubs(req);
          return;
        case 'api/sub':
          await _apiSub(req);
          return;
        default:
          await _json(res, {'error': 'not found'}, status: HttpStatus.notFound);
      }
    } catch (e, st) {
      debugPrint('[WebUI] request error ${req.uri.path}: $e\n$st');
      try {
        await _json(res, {'error': e.toString()}, status: HttpStatus.internalServerError);
      } catch (_) {}
    }
  }

  Future<void> _json(HttpResponse res, Object? data, {int status = HttpStatus.ok}) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.headers.set('Cache-Control', 'no-store');
    res.write(jsonEncode(data));
    await res.close();
  }

  Future<Map<String, dynamic>> _body(HttpRequest req) async {
    final text = await utf8.decoder.bind(req).join();
    if (text.trim().isEmpty) return {};
    final v = jsonDecode(text);
    return v is Map<String, dynamic> ? v : {};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Catalog API
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _movieJson(Movie m) => {
        'id': m.id,
        'type': m.type,
        'name': m.name,
        'poster': m.poster,
        'year': m.year,
        'rating': m.imdbRating,
      };

  Future<void> _apiHome(HttpRequest req) async {
    Future<List<Movie>> cat(String type, String id) => MetadataService.fetchCatalog(
          baseUrl: cinemeta,
          type: type,
          catalogId: id,
        ).catchError((_) => <Movie>[]);
    final r = await Future.wait([
      cat('movie', 'top'),
      cat('series', 'top'),
      cat('movie', 'imdbRating'),
      cat('series', 'imdbRating'),
    ]);
    await _json(req.response, {
      'rows': [
        {'title': 'Popular Movies', 'items': r[0].take(40).map(_movieJson).toList()},
        {'title': 'Popular Shows', 'items': r[1].take(40).map(_movieJson).toList()},
        {'title': 'Top Rated Movies', 'items': r[2].take(40).map(_movieJson).toList()},
        {'title': 'Top Rated Shows', 'items': r[3].take(40).map(_movieJson).toList()},
      ].where((row) => (row['items'] as List).isNotEmpty).toList(),
    });
  }

  Future<void> _apiSearch(HttpRequest req) async {
    final q = (req.uri.queryParameters['q'] ?? '').trim();
    if (q.isEmpty) {
      await _json(req.response, {'movies': [], 'series': []});
      return;
    }
    final r = await Future.wait([
      MetadataService.search(baseUrl: cinemeta, type: 'movie', catalogId: 'top', query: q)
          .catchError((_) => <Movie>[]),
      MetadataService.search(baseUrl: cinemeta, type: 'series', catalogId: 'top', query: q)
          .catchError((_) => <Movie>[]),
    ]);
    await _json(req.response, {
      'movies': r[0].map(_movieJson).toList(),
      'series': r[1].map(_movieJson).toList(),
    });
  }

  Future<void> _apiMeta(HttpRequest req) async {
    final type = req.uri.queryParameters['type'] ?? 'movie';
    final id = req.uri.queryParameters['id'] ?? '';
    if (id.isEmpty) {
      await _json(req.response, {'error': 'missing id'}, status: HttpStatus.badRequest);
      return;
    }
    final MovieDetail? d = await MetadataService.fetchMeta(baseUrl: cinemeta, type: type, imdbId: id);
    if (d == null) {
      await _json(req.response, {'error': 'Not found'}, status: HttpStatus.notFound);
      return;
    }
    await _json(req.response, {
      'id': d.id,
      'type': d.type,
      'name': d.name,
      'poster': d.poster,
      'background': d.background,
      'logo': d.logo,
      'description': d.description,
      'year': d.year,
      'rating': d.imdbRating,
      'genres': d.genres,
      'runtime': d.runtime,
      'cast': d.cast.take(8).toList(),
      'videos': d.videos
          .map((v) => {
                'id': v.id,
                'title': v.title,
                'season': v.season,
                'episode': v.episode,
                'released': v.released,
                'thumbnail': v.thumbnail,
                'overview': v.overview,
              })
          .toList(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sources API
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _sourceJson(int i, StreamSource s) {
    final kind = s.isDebrid ? 'debrid' : (s.isMagnet ? 'torrent' : 'direct');
    return {
      'i': i,
      'name': s.name,
      'title': s.displayTitle,
      'addon': s.addonName,
      'quality': s.quality,
      'size': s.fileSize,
      'sizeBytes': s.sizeBytes,
      'seeders': s.seeders,
      'kind': kind,
      'hdr': s.isHDR,
      'codec': s.codec,
    };
  }

  Future<void> _apiSourcesStart(HttpRequest req) async {
    final b = await _body(req);
    final type = b['type']?.toString() ?? 'movie';
    final id = b['id']?.toString() ?? '';
    final title = b['title']?.toString() ?? '';
    if (id.isEmpty) {
      await _json(req.response, {'error': 'missing id'}, status: HttpStatus.badRequest);
      return;
    }
    // Only one search at a time (the app's scraper engine is shared).
    for (final j in _jobs.values) {
      j.cancel();
    }
    final job = _SourceJob(_randomId());
    _jobs[job.id] = job;
    try {
      final stream = StreamService.fetchStreams(
        type: type,
        id: id,
        title: title,
        year: _toInt(b['year']),
        season: _toInt(b['season']),
        episode: _toInt(b['episode']),
      );
      job.sub = stream.listen(
        (s) {
          if (s.externalUrl != null && s.externalUrl!.isNotEmpty && (s.url == null || s.url!.isEmpty)) {
            return; // opens a web page, not playable
          }
          job.sources.add(s);
        },
        onError: (_) {},
        onDone: () => job.done = true,
      );
    } catch (e) {
      job.done = true;
      job.error = e.toString();
    }
    job.timeout = Timer(const Duration(seconds: 90), () => job.done = true);
    await _json(req.response, {'job': job.id});
  }

  Future<void> _apiSourcesPoll(HttpRequest req) async {
    final job = _jobs[req.uri.queryParameters['job'] ?? ''];
    if (job == null) {
      await _json(req.response, {'error': 'expired'}, status: HttpStatus.notFound);
      return;
    }
    final since = int.tryParse(req.uri.queryParameters['since'] ?? '0') ?? 0;
    final list = <Map<String, dynamic>>[];
    for (var i = since; i < job.sources.length; i++) {
      list.add(_sourceJson(i, job.sources[i]));
    }
    await _json(req.response, {
      'sources': list,
      'total': job.sources.length,
      'done': job.done,
      'error': job.error,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Playback sessions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _apiPlay(HttpRequest req) async {
    final b = await _body(req);
    final job = _jobs[b['job']?.toString() ?? ''];
    final i = _toInt(b['i']) ?? -1;
    if (job == null || i < 0 || i >= job.sources.length) {
      await _json(req.response, {'error': 'That source list expired. Pick a source again.'},
          status: HttpStatus.badRequest);
      return;
    }
    // Keep a small number of sessions; drop the oldest.
    while (_sessions.length >= _maxSessions) {
      final oldest = _sessions.values.reduce((a, b) => a.lastActive.isBefore(b.lastActive) ? a : b);
      await _closeSession(oldest);
    }
    final s = _Session(
      id: _randomId(),
      source: job.sources[i],
      title: b['title']?.toString() ?? '',
      imdbId: b['imdb']?.toString(),
      season: _toInt(b['season']),
      episode: _toInt(b['episode']),
      year: _toInt(b['year']),
    );
    _sessions[s.id] = s;
    unawaited(_prepare(s));
    await _json(req.response, {'sid': s.id});
  }

  Future<void> _apiSession(HttpRequest req) async {
    final s = _sessions[req.uri.queryParameters['sid'] ?? ''];
    if (s == null) {
      await _json(req.response, {'state': 'error', 'message': 'This stream was closed.'},
          status: HttpStatus.notFound);
      return;
    }
    s.lastActive = DateTime.now();
    final p = s.probe;
    await _json(req.response, {
      'state': s.state,
      'message': s.message,
      if (p != null) ...{
        'duration': p.duration,
        'container': p.format,
        'video': {'codec': p.vcodec, 'pixFmt': p.pixFmt, 'width': p.width, 'height': p.height},
        'audio': [
          for (final a in p.audio)
            {'index': a.index, 'codec': a.codec, 'lang': a.lang, 'title': a.title, 'channels': a.channels}
        ],
        'direct': s.directOk,
        'copyVideo': p.videoCopyable,
        'qualities': [for (final q in _qualitiesFor(p)) q.toJson()],
      },
    });
  }

  Future<void> _apiSessionStop(HttpRequest req) async {
    final b = await _body(req);
    final s = _sessions[b['sid']?.toString() ?? ''];
    if (s != null) await _closeSession(s);
    await _json(req.response, {'ok': true});
  }

  Future<void> _closeSession(_Session s) async {
    if (s.closed) return;
    s.closed = true;
    _sessions.remove(s.id);
    s.killEncoder();
    final hash = s.torrentHash;
    if (hash != null && !_sessions.values.any((o) => o.torrentHash == hash)) {
      try {
        await TorrentStreamService().release(hash);
      } catch (_) {}
    }
    _updateActivity();
  }

  /// Resolves the chosen source to a URL (torrent/debrid/direct), then reads
  /// its codecs and duration. Mirrors PlayerScreen._initStream.
  Future<void> _prepare(_Session s) async {
    try {
      final src = s.source;
      final raw = src.url;
      String? streamUrl;

      final isLocalFile = raw != null && !raw.startsWith('http') && !raw.startsWith('magnet:') &&
          File(raw).existsSync();
      final infoHash = src.infoHash;
      final isMagnetUrl = raw != null && raw.startsWith('magnet:');
      final isTorrent = !isLocalFile && ((infoHash != null && infoHash.isNotEmpty) || isMagnetUrl);

      if (isLocalFile) {
        streamUrl = raw;
      } else if (isTorrent) {
        String magnet;
        if (isMagnetUrl) {
          magnet = raw!;
        } else {
          magnet = 'magnet:?xt=urn:btih:$infoHash';
          for (final source in src.sources ?? const <String>[]) {
            if (source.startsWith('tracker:')) {
              magnet += '&tr=${Uri.encodeComponent(source.replaceFirst('tracker:', ''))}';
            }
          }
        }
        final useDebrid = await DebridService().isDebridActiveForStreams();
        if (useDebrid) {
          final service = await DebridService().getSelectedService();
          s.message = 'Getting link from $service…';
          final files = await DebridService().resolveMagnet(
            magnet: magnet,
            fileIndex: src.fileIdx,
            filename: s.title,
            season: s.season,
            episode: s.episode,
          );
          if (files.isEmpty || files.first.downloadUrl.isEmpty) {
            throw Exception('$service returned no stream link.');
          }
          streamUrl = files.first.downloadUrl;
        } else {
          s.message = 'Finding peers…';
          streamUrl = await TorrentStreamService().streamTorrent(
            magnet,
            season: s.season,
            episode: s.episode,
            fileIdx: src.fileIdx,
          );
          if (streamUrl != null) {
            final hash = TorrentStreamService.hashOf(streamUrl) ?? TorrentStreamService.hashOf(magnet);
            if (hash != null) {
              TorrentStreamService().pin(hash);
              s.torrentHash = hash;
            }
          }
        }
      } else if (raw != null && raw.isNotEmpty) {
        streamUrl = raw;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception(isTorrent
            ? 'Couldn\'t start the torrent (no peers or no video file). Try another source.'
            : 'This source has no playable link.');
      }
      if (s.closed) return;

      final url = streamUrl.contains('::') ? streamUrl.replaceAll('::', '%3A%3A') : streamUrl;
      final headers = <String, String>{};
      if (_isRemote(url)) {
        headers.addAll(PlayerSettings.resolveStreamHeaders(url, src.headers));
        final proxy = src.behaviorHints?['proxyHeaders'];
        if (proxy is Map && proxy['request'] is Map) {
          (proxy['request'] as Map).forEach((k, v) => headers[k.toString()] = v.toString());
        }
        headers.removeWhere((k, _) {
          final l = k.toLowerCase();
          return l == 'connection' || l == 'host' || l == 'content-length';
        });
      }
      s.url = url;
      s.headers = headers;

      s.state = 'probing';
      s.message = 'Reading video info…';
      final probe = await _probe(url, headers);
      if (s.closed) return;
      if (probe == null) {
        throw Exception('Couldn\'t read this video. The source may be dead; try another one.');
      }
      s.probe = probe;
      s.directOk = probe.browserDirect && !_looksLikeHls(url);
      s.state = 'ready';
      s.message = 'Ready';
    } catch (e) {
      debugPrint('[WebUI] prepare failed: $e');
      s.state = 'error';
      s.message = e.toString().replaceFirst('Exception: ', '');
    }
  }

  static bool _isRemote(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return false;
    final h = u.host.toLowerCase();
    return h != '127.0.0.1' && h != 'localhost' && h != '::1';
  }

  static bool _isNetwork(String url) => url.startsWith('http://') || url.startsWith('https://');

  static bool _looksLikeHls(String url) {
    final l = url.toLowerCase();
    return l.contains('.m3u8') || l.contains('/hls/') || l.contains('type=m3u8');
  }

  static List<String> _inputArgs(String url, Map<String, String> headers, {bool forProbe = false}) {
    if (!_isNetwork(url)) return const [];
    final args = <String>[];
    final hdr = StringBuffer();
    String? ua;
    headers.forEach((k, v) {
      if (k.toLowerCase() == 'user-agent') {
        ua = v;
      } else {
        hdr.write('$k: $v\r\n');
      }
    });
    if (ua != null) args.addAll(['-user_agent', ua!]);
    if (hdr.isNotEmpty) args.addAll(['-headers', hdr.toString()]);
    // TorrServer (127.0.0.1) holds reads open until peers deliver pieces.
    final loopback = !_isRemote(url);
    args.addAll(['-rw_timeout', loopback ? '180000000' : '30000000']);
    if (!forProbe) {
      args.addAll([
        '-reconnect', '1',
        '-reconnect_streamed', '1',
        '-reconnect_on_network_error', '1',
        '-reconnect_delay_max', '10',
      ]);
    }
    return args;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Probing
  // ─────────────────────────────────────────────────────────────────────────

  Future<_Probe?> _probe(String url, Map<String, String> headers) async {
    final ffPath = await LanCastService.instance.savedFfmpegPath();
    final ffprobe = await LanCastService.instance.findFfprobe(ffPath);
    if (ffprobe != null) {
      final r = await _run(ffprobe, [
        '-v', 'error',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        ..._inputArgs(url, headers, forProbe: true),
        url,
      ], const Duration(seconds: 150));
      if (r != null && r.$1 == 0) {
        final p = _Probe.fromFfprobeJson(r.$2);
        if (p != null) return p;
      }
    }
    final ffmpeg = await LanCastService.instance.findFfmpeg(ffPath);
    if (ffmpeg != null) {
      final r = await _run(ffmpeg, [
        '-hide_banner',
        ..._inputArgs(url, headers, forProbe: true),
        '-i', url,
      ], const Duration(seconds: 150));
      if (r != null) return _Probe.fromFfmpegBanner(r.$3);
    }
    return null;
  }

  /// Runs a process with a hard timeout. Returns (exitCode, stdout, stderr).
  static Future<(int, String, String)?> _run(String exe, List<String> args, Duration timeout) async {
    Process p;
    try {
      p = await Process.start(exe, args, runInShell: false);
    } catch (e) {
      debugPrint('[WebUI] failed to start $exe: $e');
      return null;
    }
    const dec = Utf8Decoder(allowMalformed: true);
    final out = p.stdout.transform(dec).join();
    final err = p.stderr.transform(dec).join();
    final code = await p.exitCode.timeout(timeout, onTimeout: () {
      p.kill(ProcessSignal.sigkill);
      return -1;
    });
    if (code == -1) return null;
    return (code, await out, await err);
  }

  List<_Quality> _qualitiesFor(_Probe p) {
    final list = <_Quality>[];
    final h = p.height;
    for (final q in _Quality.ladder) {
      if (h <= 0 || q.height <= h || q.height == 360) list.add(q);
    }
    return list;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Media serving
  // ─────────────────────────────────────────────────────────────────────────

  /// Browser-native file: proxied with Range so the <video> element can seek.
  Future<void> _serveRaw(HttpRequest req, _Session s) async {
    final res = req.response;
    final url = s.url!;
    s.rawClients++;
    _updateActivity();
    try {
      if (!_isNetwork(url)) {
        await _serveLocalFile(req, File(url));
        return;
      }
      final up0 = await _http.openUrl(req.method == 'HEAD' ? 'HEAD' : 'GET', Uri.parse(url));
      up0.followRedirects = true;
      up0.maxRedirects = 8;
      s.headers.forEach((k, v) {
        try {
          up0.headers.set(k, v);
        } catch (_) {}
      });
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) up0.headers.set(HttpHeaders.rangeHeader, range);
      final up = await up0.close();
      res.statusCode = up.statusCode;
      for (final h in const [
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
      ]) {
        final v = up.headers.value(h);
        if (v != null) res.headers.set(h, v);
      }
      res.headers.contentType = ContentType('video', 'mp4');
      if (up.headers.value(HttpHeaders.acceptRangesHeader) == null) {
        res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      }
      res.bufferOutput = false;
      if (req.method == 'HEAD') {
        await up.drain<void>().catchError((_) {});
        await res.close();
        return;
      }
      try {
        await res.addStream(up);
      } catch (_) {}
      try {
        await res.close();
      } catch (_) {}
    } catch (e) {
      try {
        res.statusCode = HttpStatus.badGateway;
        await res.close();
      } catch (_) {}
    } finally {
      s.rawClients--;
      s.lastActive = DateTime.now();
      _updateActivity();
    }
  }

  Future<void> _serveLocalFile(HttpRequest req, File file) async {
    final res = req.response;
    final len = await file.length();
    var start = 0;
    var end = len - 1;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.contentType = ContentType('video', 'mp4');
    if (m != null) {
      final a = m.group(1) ?? '';
      final b = m.group(2) ?? '';
      if (a.isEmpty && b.isNotEmpty) {
        start = max(0, len - int.parse(b));
      } else {
        start = int.tryParse(a) ?? 0;
        if (b.isNotEmpty) end = min(len - 1, int.parse(b));
      }
      if (start >= len || start > end) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$len');
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$len');
    }
    res.contentLength = end - start + 1;
    res.bufferOutput = false;
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    try {
      await res.addStream(file.openRead(start, end + 1));
    } catch (_) {}
    try {
      await res.close();
    } catch (_) {}
  }

  /// Fragmented MP4 from FFmpeg, starting at `t` seconds.
  Future<void> _serveVideo(HttpRequest req, _Session s) async {
    final res = req.response;
    final probe = s.probe!;
    final ffmpeg = await LanCastService.instance.findFfmpeg(await LanCastService.instance.savedFfmpegPath());
    if (ffmpeg == null) {
      res.statusCode = HttpStatus.serviceUnavailable;
      res.write('FFmpeg is missing on the PlayTorrio computer.');
      await res.close();
      return;
    }
    res.headers.contentType = ContentType('video', 'mp4');
    res.headers.set(HttpHeaders.acceptRangesHeader, 'none');
    res.headers.set('Cache-Control', 'no-store');
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }

    final qp = req.uri.queryParameters;
    final t = double.tryParse(qp['t'] ?? '0') ?? 0;
    final a = int.tryParse(qp['a'] ?? '0') ?? 0;
    final qId = qp['q'] ?? 'original';
    final quality = _Quality.byId(qId);
    final audio = (a >= 0 && a < probe.audio.length) ? probe.audio[a] : (probe.audio.isEmpty ? null : probe.audio.first);

    final args = _buildVideoArgs(
      input: s.url!,
      inputArgs: _inputArgs(s.url!, s.headers),
      probe: probe,
      quality: quality,
      startSeconds: t,
      audioOrdinal: audio?.index ?? 0,
      audioCopy: audio != null && audio.browserSafe,
    );
    debugPrint('[WebUI] ffmpeg ${args.join(' ')}');

    // One encoder per viewer: a seek or quality change replaces the old one.
    s.killEncoder();
    Process proc;
    try {
      proc = await Process.start(ffmpeg, args, runInShell: false);
    } catch (e) {
      res.statusCode = HttpStatus.internalServerError;
      await res.close();
      return;
    }
    s.encoder = proc;
    _updateActivity();
    proc.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((l) => debugPrint('[WebUI/ffmpeg] ${l.trim()}'),
        onError: (_) {});

    void kill() {
      try {
        proc.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }

    unawaited(res.done.then((_) {}, onError: (_) => kill()));
    res.bufferOutput = false;
    try {
      await res.addStream(proc.stdout);
    } catch (_) {
    } finally {
      kill();
      if (identical(s.encoder, proc)) s.encoder = null;
      s.lastActive = DateTime.now();
      try {
        await res.close();
      } catch (_) {}
      _updateActivity();
    }
  }

  /// Builds the FFmpeg command for a browser stream.
  static List<String> _buildVideoArgs({
    required String input,
    required List<String> inputArgs,
    required _Probe probe,
    required _Quality quality,
    double startSeconds = 0,
    int audioOrdinal = 0,
    bool audioCopy = false,
  }) {
    final args = <String>['-hide_banner', '-loglevel', 'error', '-nostdin', ...inputArgs];
    if (startSeconds > 0.5) {
      args.addAll(['-ss', startSeconds.toStringAsFixed(2)]);
    }
    args.addAll(['-fflags', '+genpts+discardcorrupt', '-i', input]);
    args.addAll(['-map', '0:v:0', '-map', '0:a:$audioOrdinal?', '-sn', '-dn']);

    final copyVideo = quality.id == 'original' && probe.videoCopyable;
    if (copyVideo) {
      args.addAll(['-c:v', 'copy']);
      if (probe.vcodec == 'hevc') args.addAll(['-tag:v', 'hvc1']);
    } else {
      // "Original" for a codec browsers can't play: re-encode at the
      // source size (capped at 1080p to keep the CPU sane).
      final target = quality.id == 'original'
          ? _Quality.ladder.firstWhere((q) => probe.height <= 0 || q.height <= probe.height,
              orElse: () => _Quality.ladder.last)
          : quality;
      final v = target.videoKbps;
      args.addAll([
        '-vf', "scale=-2:'min(${target.height},ih)':flags=bicubic,format=yuv420p",
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-profile:v', 'high',
        '-level:v', '4.1',
        '-b:v', '${v}k',
        '-maxrate', '${(v * 1.3).round()}k',
        '-bufsize', '${v * 2}k',
        '-g', '48',
        '-keyint_min', '48',
        '-sc_threshold', '0',
      ]);
    }
    if (audioCopy) {
      args.addAll(['-c:a', 'copy']);
    } else {
      args.addAll(['-c:a', 'aac', '-b:a', '192k', '-ac', '2', '-ar', '48000']);
    }
    args.addAll([
      '-avoid_negative_ts', 'make_zero',
      '-max_muxing_queue_size', '4096',
      '-f', 'mp4',
      '-movflags', '+frag_keyframe+empty_moov+default_base_moof',
      '-frag_duration', '2000000',
      'pipe:1',
    ]);
    return args;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Subtitles
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<SubtitleVariant>> _subsFor(_Session s) {
    return s.subsFuture ??= () async {
      final all = <SubtitleVariant>[...?s.source.subtitles];
      final imdb = s.imdbId != null && s.imdbId!.startsWith('tt') ? s.imdbId!.split(':').first : null;
      try {
        await for (final batch in SubtitleService()
            .streamSubtitles(s.title, imdbId: imdb, season: s.season, episode: s.episode, year: s.year)
            .timeout(const Duration(seconds: 12), onTimeout: (sink) => sink.close())) {
          all.addAll(batch);
        }
      } catch (_) {}
      final seen = <String>{};
      final list = all.where((v) => seen.add(v.downloadUrl.toLowerCase())).toList();
      int rank(SubtitleVariant v) => v.language.toLowerCase().startsWith('en') ? 0 : 1;
      list.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.language.toLowerCase().compareTo(b.language.toLowerCase());
      });
      return list.take(80).toList();
    }();
  }

  Future<void> _apiSubs(HttpRequest req) async {
    final s = _sessions[req.uri.queryParameters['sid'] ?? ''];
    if (s == null) {
      await _json(req.response, {'subs': []});
      return;
    }
    final list = await _subsFor(s);
    await _json(req.response, {
      'subs': [
        for (var i = 0; i < list.length; i++)
          {'id': i, 'lang': list[i].language, 'label': list[i].title, 'provider': list[i].providerName}
      ],
    });
  }

  Future<void> _apiSub(HttpRequest req) async {
    final s = _sessions[req.uri.queryParameters['sid'] ?? ''];
    final id = int.tryParse(req.uri.queryParameters['id'] ?? '') ?? -1;
    if (s == null) {
      await _json(req.response, {'error': 'closed'}, status: HttpStatus.notFound);
      return;
    }
    final list = await _subsFor(s);
    if (id < 0 || id >= list.length) {
      await _json(req.response, {'error': 'bad id'}, status: HttpStatus.badRequest);
      return;
    }
    final path = await SubtitleService().downloadSubtitle(list[id]);
    if (path == null || !File(path).existsSync()) {
      await _json(req.response, {'error': 'Download failed'}, status: HttpStatus.badGateway);
      return;
    }
    final bytes = await File(path).readAsBytes();
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    final res = req.response;
    res.headers.contentType = ContentType('text', 'vtt', charset: 'utf-8');
    res.write(toWebVtt(text));
    await res.close();
  }

  /// Converts SRT / ASS / VTT text to WebVTT. Public for tests.
  static String toWebVtt(String input) {
    var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.startsWith('﻿')) text = text.substring(1);
    if (text.trimLeft().startsWith('WEBVTT')) return text;

    if (text.contains('[Events]') && text.contains('Dialogue:')) {
      final out = StringBuffer('WEBVTT\n\n');
      final lines = text.split('\n');
      var fmt = <String>[];
      for (final line in lines) {
        if (line.startsWith('Format:') && fmt.isEmpty && line.contains('Text')) {
          final f = line.substring(7).split(',').map((e) => e.trim().toLowerCase()).toList();
          if (f.contains('start') && f.contains('text')) fmt = f;
        }
        if (!line.startsWith('Dialogue:') || fmt.isEmpty) continue;
        final body = line.substring(9).trim();
        final parts = body.split(',');
        if (parts.length < fmt.length) continue;
        final start = parts[fmt.indexOf('start')].trim();
        final end = parts[fmt.indexOf('end')].trim();
        var t = parts.sublist(fmt.indexOf('text')).join(',');
        t = t.replaceAll(RegExp(r'\{[^}]*\}'), '').replaceAll(r'\N', '\n').replaceAll(r'\n', '\n').trim();
        if (t.isEmpty) continue;
        String conv(String a) {
          final m = RegExp(r'(\d+):(\d+):(\d+)[.:](\d+)').firstMatch(a);
          if (m == null) return '00:00:00.000';
          final cs = m.group(4)!.padRight(3, '0').substring(0, 3);
          return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}:${m.group(3)}.$cs';
        }
        out.write('${conv(start)} --> ${conv(end)}\n$t\n\n');
      }
      return out.toString();
    }

    // SRT: "00:01:02,345 --> 00:01:04,000" and optional numeric counters.
    final out = StringBuffer('WEBVTT\n\n');
    final blocks = text.split(RegExp(r'\n\s*\n'));
    final timing = RegExp(r'(\d{1,2}:\d{2}:\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}:\d{2}:\d{2})[,.](\d{1,3})');
    for (final b in blocks) {
      final lines = b.trim().split('\n');
      final idx = lines.indexWhere((l) => timing.hasMatch(l));
      if (idx < 0) continue;
      final m = timing.firstMatch(lines[idx])!;
      String pad(String hms) => hms.length == 7 ? '0$hms' : hms;
      final start = '${pad(m.group(1)!)}.${m.group(2)!.padRight(3, '0')}';
      final end = '${pad(m.group(3)!)}.${m.group(4)!.padRight(3, '0')}';
      final body = lines.sublist(idx + 1).join('\n').trim();
      if (body.isEmpty) continue;
      out.write('$start --> $end\n$body\n\n');
    }
    return out.toString();
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

class _SourceJob {
  final String id;
  final DateTime created = DateTime.now();
  final List<StreamSource> sources = [];
  bool done = false;
  String? error;
  StreamSubscription<StreamSource>? sub;
  Timer? timeout;

  _SourceJob(this.id);

  void cancel() {
    timeout?.cancel();
    try {
      sub?.cancel();
    } catch (_) {}
    done = true;
  }
}

class _Session {
  final String id;
  final StreamSource source;
  final String title;
  final String? imdbId;
  final int? season;
  final int? episode;
  final int? year;

  String state = 'resolving';
  String message = 'Starting…';
  String? url;
  Map<String, String> headers = const {};
  String? torrentHash;
  _Probe? probe;
  bool directOk = false;
  Process? encoder;
  int rawClients = 0;
  DateTime lastActive = DateTime.now();
  bool closed = false;
  Future<List<SubtitleVariant>>? subsFuture;

  _Session({
    required this.id,
    required this.source,
    required this.title,
    this.imdbId,
    this.season,
    this.episode,
    this.year,
  });

  void killEncoder() {
    final e = encoder;
    encoder = null;
    if (e != null) {
      try {
        e.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }
}

class _Quality {
  final String id;
  final String label;
  final int height;
  final int videoKbps;

  const _Quality(this.id, this.label, this.height, this.videoKbps);

  static const original = _Quality('original', 'Original', 0, 0);
  static const ladder = <_Quality>[
    _Quality('1080', '1080p', 1080, 6000),
    _Quality('720', '720p', 720, 3000),
    _Quality('480', '480p', 480, 1400),
    _Quality('360', '360p', 360, 800),
  ];

  static _Quality byId(String id) {
    if (id == 'original') return original;
    return ladder.firstWhere((q) => q.id == id, orElse: () => original);
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'height': height, 'kbps': videoKbps};
}

class _AudioTrack {
  /// Position among the file's audio streams (FFmpeg's `0:a:N`).
  final int index;
  final String codec;
  final String? lang;
  final String? title;
  final int channels;

  const _AudioTrack(this.index, this.codec, this.lang, this.title, this.channels);

  /// Codecs every current browser plays inside MP4.
  bool get browserSafe => codec == 'aac' || codec == 'mp3' || codec == 'opus';
}

class _Probe {
  final double duration;
  final String format;
  final String? vcodec;
  final String? pixFmt;
  final int width;
  final int height;
  final List<_AudioTrack> audio;

  _Probe({
    required this.duration,
    required this.format,
    required this.vcodec,
    required this.pixFmt,
    required this.width,
    required this.height,
    required this.audio,
  });

  bool get _tenBit => (pixFmt ?? '').contains('10') || (pixFmt ?? '').contains('12');

  /// Video that can be copied untouched and still play in a browser.
  /// HEVC/AV1/VP9 depend on the browser; the page checks before using it.
  bool get videoCopyable {
    switch (vcodec) {
      case 'h264':
        return !_tenBit;
      case 'hevc':
      case 'av1':
      case 'vp9':
        return true;
      default:
        return false;
    }
  }

  /// An MP4 the browser can play straight from the file (native seeking).
  bool get browserDirect =>
      (format.contains('mp4') || format.contains('mov')) &&
      vcodec == 'h264' &&
      !_tenBit &&
      (audio.isEmpty || audio.first.browserSafe);

  static _Probe? fromFfprobeJson(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final streams = (j['streams'] as List? ?? const []).whereType<Map>().toList();
      final fmt = (j['format'] as Map?) ?? const {};
      Map? v;
      for (final s in streams) {
        if (s['codec_type'] == 'video') {
          final disp = s['disposition'];
          final isCover = disp is Map && disp['attached_pic'] == 1;
          if (!isCover) {
            v = s;
            break;
          }
        }
      }
      final audio = <_AudioTrack>[];
      for (final s in streams) {
        if (s['codec_type'] != 'audio') continue;
        final tags = s['tags'] is Map ? s['tags'] as Map : const {};
        audio.add(_AudioTrack(
          audio.length,
          (s['codec_name'] ?? '').toString(),
          tags['language']?.toString(),
          tags['title']?.toString(),
          int.tryParse('${s['channels'] ?? 2}') ?? 2,
        ));
      }
      var duration = double.tryParse('${fmt['duration'] ?? ''}') ?? 0;
      if (duration <= 0 && v != null) duration = double.tryParse('${v['duration'] ?? ''}') ?? 0;
      return _Probe(
        duration: duration,
        format: (fmt['format_name'] ?? '').toString(),
        vcodec: v?['codec_name']?.toString(),
        pixFmt: v?['pix_fmt']?.toString(),
        width: int.tryParse('${v?['width'] ?? 0}') ?? 0,
        height: int.tryParse('${v?['height'] ?? 0}') ?? 0,
        audio: audio,
      );
    } catch (e) {
      debugPrint('[WebUI] ffprobe parse error: $e');
      return null;
    }
  }

  /// Fallback when ffprobe isn't installed: parse `ffmpeg -i` output.
  static _Probe? fromFfmpegBanner(String text) {
    final fmtM = RegExp(r'Input #0, (.+?), from').firstMatch(text);
    if (fmtM == null) return null;
    final durM = RegExp(r'Duration: (\d+):(\d+):(\d+(?:\.\d+)?)').firstMatch(text);
    final duration = durM == null
        ? 0.0
        : int.parse(durM.group(1)!) * 3600 + int.parse(durM.group(2)!) * 60 + double.parse(durM.group(3)!);
    String? vcodec;
    String? pix;
    var w = 0;
    var h = 0;
    final audio = <_AudioTrack>[];
    final streamRe = RegExp(r'Stream #0:\d+(?:\[[^\]]*\])?(?:\((\w+)\))?: (Video|Audio): (\w+)([^\n]*)');
    for (final m in streamRe.allMatches(text)) {
      final lang = m.group(1);
      final kind = m.group(2);
      final codec = m.group(3)!;
      final rest = m.group(4) ?? '';
      if (kind == 'Video' && vcodec == null && !rest.contains('attached pic')) {
        vcodec = codec;
        pix = RegExp(r'\b(yuv\w+|nv12|p010\w*)').firstMatch(rest)?.group(1);
        final r = RegExp(r'\b(\d{2,5})x(\d{2,5})\b').firstMatch(rest);
        if (r != null) {
          w = int.parse(r.group(1)!);
          h = int.parse(r.group(2)!);
        }
      } else if (kind == 'Audio') {
        var ch = 2;
        if (rest.contains('mono')) ch = 1;
        if (rest.contains('5.1')) ch = 6;
        if (rest.contains('7.1')) ch = 8;
        audio.add(_AudioTrack(audio.length, codec, lang == 'und' ? null : lang, null, ch));
      }
    }
    return _Probe(
      duration: duration,
      format: fmtM.group(1)!,
      vcodec: vcodec,
      pixFmt: pix,
      width: w,
      height: h,
      audio: audio,
    );
  }
}
