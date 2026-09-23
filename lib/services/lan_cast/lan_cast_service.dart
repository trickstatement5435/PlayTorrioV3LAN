import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A bitrate preset for the LAN restream.
///
/// [videoKbps] == 0 means "Original": no re-encode, the source bytes are
/// proxied as-is (seekable in VLC, zero CPU cost, but no bitrate control).
class LanCastQuality {
  final String id;
  final String label;
  final int videoKbps;
  final int audioKbps;

  /// Max output height. The source is never upscaled.
  final int maxHeight;

  const LanCastQuality({
    required this.id,
    required this.label,
    required this.videoKbps,
    required this.audioKbps,
    required this.maxHeight,
  });

  bool get isOriginal => videoKbps <= 0;
  int get totalKbps => videoKbps + audioKbps;

  String get bitrateLabel {
    if (isOriginal) return 'Source bitrate';
    final mbps = totalKbps / 1000.0;
    return '${mbps.toStringAsFixed(mbps >= 10 ? 0 : 1)} Mbps';
  }

  static const original = LanCastQuality(
    id: 'original', label: 'Original', videoKbps: 0, audioKbps: 0, maxHeight: 0);

  static const presets = <LanCastQuality>[
    original,
    LanCastQuality(id: 'low', label: '480p', videoKbps: 1200, audioKbps: 128, maxHeight: 480),
    LanCastQuality(id: 'medium', label: '720p', videoKbps: 2800, audioKbps: 160, maxHeight: 720),
    LanCastQuality(id: 'high', label: '1080p', videoKbps: 5500, audioKbps: 192, maxHeight: 1080),
    LanCastQuality(id: 'ultra', label: '1080p+', videoKbps: 10000, audioKbps: 256, maxHeight: 1080),
  ];

  /// The preset used the first time the feature is opened. 1080p at ~5.7 Mbps
  /// is comfortably inside what 5 GHz Wi-Fi or any wired LAN can sustain and
  /// still looks close to the source on a TV.
  static const defaultPreset = 'high';

  /// Builds a custom quality from a total bitrate in kbps, picking a
  /// sensible resolution cap and audio bitrate for it.
  factory LanCastQuality.custom(int totalKbps) {
    final total = totalKbps.clamp(500, 60000);
    final audio = total < 1500 ? 96 : (total < 4000 ? 128 : (total < 8000 ? 192 : 256));
    final video = total - audio;
    final int height;
    if (video < 1000) {
      height = 360;
    } else if (video < 2000) {
      height = 480;
    } else if (video < 4000) {
      height = 720;
    } else if (video < 15000) {
      height = 1080;
    } else if (video < 25000) {
      height = 1440;
    } else {
      height = 2160;
    }
    return LanCastQuality(
      id: 'custom',
      label: 'Custom',
      videoKbps: video,
      audioKbps: audio,
      maxHeight: height,
    );
  }
}

/// A single network address the stream can be reached on.
class LanCastEndpoint {
  final String interfaceName;
  final String address;
  final String streamUrl;
  final String playlistUrl;
  final String pageUrl;

  const LanCastEndpoint({
    required this.interfaceName,
    required this.address,
    required this.streamUrl,
    required this.playlistUrl,
    required this.pageUrl,
  });
}

class LanCastStatus {
  final bool running;
  final List<LanCastEndpoint> endpoints;
  final LanCastQuality? quality;
  final int activeClients;
  final List<String> clientAddresses;
  final String? error;
  final String? note;

  const LanCastStatus({
    this.running = false,
    this.endpoints = const [],
    this.quality,
    this.activeClients = 0,
    this.clientAddresses = const [],
    this.error,
    this.note,
  });

  LanCastStatus copyWith({
    bool? running,
    List<LanCastEndpoint>? endpoints,
    LanCastQuality? quality,
    int? activeClients,
    List<String>? clientAddresses,
    String? error,
    bool clearError = false,
    String? note,
  }) {
    return LanCastStatus(
      running: running ?? this.running,
      endpoints: endpoints ?? this.endpoints,
      quality: quality ?? this.quality,
      activeClients: activeClients ?? this.activeClients,
      clientAddresses: clientAddresses ?? this.clientAddresses,
      error: clearError ? null : (error ?? this.error),
      note: note ?? this.note,
    );
  }
}

/// Where the restream should start from when a LAN client connects.
enum LanCastStartMode { followPlayer, beginning }

/// Re-serves whatever the in-app player is currently playing on the local
/// network so it can be opened in VLC (or mpv, Kodi, a smart TV browser...)
/// on another machine.
///
///  * **Original** quality proxies the source bytes with HTTP Range support,
///    so VLC can seek freely. Works on every platform, including Android.
///  * **Any other quality** pipes the source through FFmpeg
///    (H.264 + AAC in MPEG-TS) at the chosen bitrate. Each connecting client
///    gets its own encoder that starts at the in-app player's current
///    position (or the beginning, if configured).
///
/// URLs contain a random token so other people on the network can't
/// stumble onto the stream by scanning ports.
class LanCastService {
  LanCastService._();
  static final LanCastService instance = LanCastService._();

  static const int defaultPort = 8766;
  static const int maxConcurrentClients = 4;

  static const _prefQuality = 'lan_cast_quality';
  static const _prefCustomKbps = 'lan_cast_custom_kbps';
  static const _prefPort = 'lan_cast_port';
  static const _prefFfmpegPath = 'lan_cast_ffmpeg_path';
  static const _prefStartMode = 'lan_cast_start_mode';
  static const _prefPauseLocal = 'lan_cast_pause_local';
  static const _prefToken = 'lan_cast_token';

  final ValueNotifier<LanCastStatus> status = ValueNotifier(const LanCastStatus());

  HttpServer? _server;
  int? _requestedPort;
  String _token = '';
  String _title = 'PlayTorrio';

  String? _sourceUrl;
  Map<String, String> _sourceHeaders = const {};
  LanCastQuality _quality = LanCastQuality.original;
  LanCastStartMode _startMode = LanCastStartMode.followPlayer;
  Duration Function()? _positionProvider;
  int? Function()? _audioTrackProvider;
  VoidCallback? _onClientConnected;

  final Set<Process> _encoders = {};
  final Map<Object, String> _clients = {};
  final Set<String> _seenAddresses = {};
  final HttpClient _http = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15)
    // mpv (the in-app player) doesn't verify TLS either, so a source that
    // plays in the app must also be reachable here.
    ..badCertificateCallback = (_, _, _) => true;

  bool get isRunning => _server != null;

  /// FFmpeg only exists as a separate binary on desktop.
  static bool get transcodeSupportedOnPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // ─────────────────────────────────────────────────────────────────────────
  // Persisted preferences
  // ─────────────────────────────────────────────────────────────────────────

  Future<LanCastPrefs> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    return LanCastPrefs(
      qualityId: p.getString(_prefQuality) ??
          (transcodeSupportedOnPlatform ? LanCastQuality.defaultPreset : LanCastQuality.original.id),
      customKbps: p.getInt(_prefCustomKbps) ?? 4000,
      port: p.getInt(_prefPort) ?? defaultPort,
      ffmpegPath: p.getString(_prefFfmpegPath) ?? '',
      startMode: LanCastStartMode.values.firstWhere(
        (m) => m.name == p.getString(_prefStartMode),
        orElse: () => LanCastStartMode.followPlayer,
      ),
      pauseLocalOnConnect: p.getBool(_prefPauseLocal) ?? true,
    );
  }

  Future<void> savePrefs(LanCastPrefs prefs) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefQuality, prefs.qualityId);
    await p.setInt(_prefCustomKbps, prefs.customKbps);
    await p.setInt(_prefPort, prefs.port);
    await p.setString(_prefFfmpegPath, prefs.ffmpegPath);
    await p.setString(_prefStartMode, prefs.startMode.name);
    await p.setBool(_prefPauseLocal, prefs.pauseLocalOnConnect);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FFmpeg discovery
  // ─────────────────────────────────────────────────────────────────────────

  String? _ffmpegCache;
  String? _ffmpegCacheKey;

  /// Finds a usable ffmpeg binary: the user override, one bundled next to
  /// the app executable, common install folders, then PATH.
  Future<String?> findFfmpeg([String? overridePath]) async {
    if (!transcodeSupportedOnPlatform) return null;
    final key = overridePath ?? '';
    if (_ffmpegCacheKey == key && _ffmpegCache != null) return _ffmpegCache;

    final exe = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final candidates = <String>[];
    if (overridePath != null && overridePath.trim().isNotEmpty) {
      var o = overridePath.trim();
      if (o.startsWith('"') && o.endsWith('"') && o.length > 1) o = o.substring(1, o.length - 1);
      if (Directory(o).existsSync()) {
        candidates.add('$o${Platform.pathSeparator}$exe');
        candidates.add('$o${Platform.pathSeparator}bin${Platform.pathSeparator}$exe');
      } else {
        candidates.add(o);
      }
    }
    try {
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final sep = Platform.pathSeparator;
      candidates.add('$appDir$sep$exe');
      candidates.add('$appDir${sep}ffmpeg$sep$exe');
      candidates.add('$appDir${sep}ffmpeg${sep}bin$sep$exe');
    } catch (_) {}
    if (Platform.isMacOS) {
      candidates.addAll(['/opt/homebrew/bin/ffmpeg', '/usr/local/bin/ffmpeg']);
    } else if (Platform.isLinux) {
      candidates.addAll(['/usr/bin/ffmpeg', '/usr/local/bin/ffmpeg', '/snap/bin/ffmpeg']);
    } else if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      candidates.addAll([
        r'C:\ffmpeg\bin\ffmpeg.exe',
        r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
        if (local != null) '$local\\Microsoft\\WinGet\\Links\\ffmpeg.exe',
        r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
      ]);
    }

    String? found;
    for (final c in candidates) {
      if (File(c).existsSync()) {
        found = c;
        break;
      }
    }

    if (found == null) {
      try {
        final r = await Process.run(Platform.isWindows ? 'where' : 'which', ['ffmpeg']);
        if (r.exitCode == 0) {
          final line = r.stdout.toString().split(RegExp(r'[\r\n]+')).firstWhere(
                (l) => l.trim().isNotEmpty,
                orElse: () => '',
              );
          if (line.trim().isNotEmpty) found = line.trim();
        }
      } catch (_) {}
    }

    if (found != null) {
      // Sanity-check the binary, but don't reject it just for being slow:
      // on Windows the first launch of a big unsigned exe can sit behind an
      // antivirus scan for a long time. Only a real failure disqualifies it.
      try {
        final r = await Process.run(found, ['-hide_banner', '-version'])
            .timeout(const Duration(seconds: 45));
        if (r.exitCode != 0) {
          debugPrint('[LanCast] $found -version exited ${r.exitCode}: ${r.stderr}');
          found = null;
        }
      } on TimeoutException {
        debugPrint('[LanCast] $found -version timed out; assuming it works');
      } catch (e) {
        debugPrint('[LanCast] could not run $found: $e');
        found = null;
      }
    }

    _ffmpegCacheKey = key;
    _ffmpegCache = found;
    return found;
  }

  /// ffprobe usually ships next to ffmpeg; used by the web player to read
  /// duration, codecs and audio tracks.
  Future<String?> findFfprobe([String? ffmpegOverride]) async {
    final ff = await findFfmpeg(ffmpegOverride);
    if (ff == null) return null;
    final exe = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
    final sibling = '${File(ff).parent.path}${Platform.pathSeparator}$exe';
    if (File(sibling).existsSync()) return sibling;
    try {
      final r = await Process.run(Platform.isWindows ? 'where' : 'which', ['ffprobe']);
      if (r.exitCode == 0) {
        final line = r.stdout.toString().split(RegExp(r'[\r\n]+')).firstWhere(
              (l) => l.trim().isNotEmpty,
              orElse: () => '',
            );
        if (line.trim().isNotEmpty) return line.trim();
      }
    } catch (_) {}
    return null;
  }

  /// The FFmpeg path saved in the LAN settings (may be empty).
  Future<String> savedFfmpegPath() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_prefFfmpegPath) ?? '';
    } catch (_) {
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts (or reconfigures) the LAN server.
  ///
  /// [sourceUrl] is exactly what the in-app player opened: a remote URL,
  /// the local TorrServer URL, or a local file path.
  Future<LanCastStatus> start({
    required String sourceUrl,
    Map<String, String> headers = const {},
    required String title,
    required LanCastQuality quality,
    required int port,
    String? ffmpegPath,
    LanCastStartMode startMode = LanCastStartMode.followPlayer,
    Duration Function()? positionProvider,
    int? Function()? audioTrackProvider,
    VoidCallback? onClientConnected,
  }) async {
    String? ffmpeg;
    final isHls = _looksLikeHls(sourceUrl);
    final needsFfmpeg = !quality.isOriginal || isHls;
    if (needsFfmpeg) {
      ffmpeg = await findFfmpeg(ffmpegPath);
      if (ffmpeg == null) {
        final msg = !transcodeSupportedOnPlatform
            ? (isHls
                ? 'This source is an HLS playlist, which needs FFmpeg to restream. FFmpeg is only available on desktop.'
                : 'Re-encoding at a custom bitrate needs FFmpeg, which is only available on desktop. Use "Original" on this device.')
            : 'FFmpeg was not found. Install it (winget install ffmpeg / brew install ffmpeg / apt install ffmpeg) '
                'or point to ffmpeg in Advanced settings.';
        status.value = status.value.copyWith(error: msg);
        return status.value;
      }
    }

    _sourceUrl = sourceUrl;
    _sourceHeaders = Map.of(headers);
    _title = title;
    _quality = quality;
    _startMode = startMode;
    _positionProvider = positionProvider;
    _audioTrackProvider = audioTrackProvider;
    _onClientConnected = onClientConnected;
    _ffmpegPathResolved = ffmpeg;

    // Changing settings while running: drop current viewers so they
    // reconnect with the new bitrate. Keep the same port + token.
    _killEncoders();

    if (_server == null || _requestedPort != port) {
      await _closeServer();
      _requestedPort = port;
      _token = await _loadOrCreateToken();
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: false);
      } on SocketException catch (e) {
        debugPrint('[LanCast] port $port unavailable ($e), falling back to a free port');
        try {
          _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
        } catch (e2) {
          _requestedPort = null;
          status.value = LanCastStatus(error: 'Could not open a network port: $e2');
          return status.value;
        }
      }
      _server!.autoCompress = false;
      _server!.idleTimeout = null;
      _server!.listen(_handle, onError: (e) => debugPrint('[LanCast] server error: $e'));
      debugPrint('[LanCast] listening on 0.0.0.0:${_server!.port}');
    }

    final endpoints = await _buildEndpoints(_server!.port);
    String? note;
    if (endpoints.isEmpty) {
      note = 'No LAN network adapter was found. Connect to Wi-Fi or Ethernet.';
    } else if (Platform.isWindows) {
      note = 'If VLC can\'t connect, allow PlayTorrio through Windows Firewall on Private networks.';
    } else if (Platform.isMacOS) {
      note = 'If VLC can\'t connect, allow incoming connections for PlayTorrio in System Settings > Network > Firewall.';
    }
    if (_server!.port != port) {
      note = 'Port $port was busy, so port ${_server!.port} is used instead.${note != null ? '\n$note' : ''}';
    }

    status.value = LanCastStatus(
      running: true,
      endpoints: endpoints,
      quality: quality,
      activeClients: _clients.length,
      clientAddresses: _clients.values.toList(),
      note: note,
    );
    return status.value;
  }

  /// Point an already running server at a new source (e.g. next episode),
  /// keeping the same URL so VLC can just reconnect.
  Future<void> updateSource(String sourceUrl, Map<String, String> headers, String title) async {
    if (!isRunning) return;
    _sourceUrl = sourceUrl;
    _sourceHeaders = Map.of(headers);
    _title = title;
    _killEncoders();
    // An HLS source needs FFmpeg even at "Original" quality.
    if (_ffmpegPathResolved == null && _looksLikeHls(sourceUrl)) {
      _ffmpegPathResolved = await findFfmpeg(_ffmpegCacheKey);
    }
    // The stream path (video vs stream.ts) can change with the source type.
    if (isRunning) {
      final endpoints = await _buildEndpoints(_server!.port);
      status.value = status.value.copyWith(endpoints: endpoints);
    }
  }

  Future<void> stop() async {
    _killEncoders();
    await _closeServer();
    _requestedPort = null;
    _clients.clear();
    _seenAddresses.clear();
    _sourceUrl = null;
    _positionProvider = null;
    _audioTrackProvider = null;
    _onClientConnected = null;
    status.value = const LanCastStatus();
  }

  Future<void> _closeServer() async {
    final s = _server;
    _server = null;
    if (s != null) {
      try {
        await s.close(force: true);
      } catch (_) {}
    }
  }

  void _killEncoders() {
    for (final p in _encoders.toList()) {
      try {
        p.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
    _encoders.clear();
  }

  String? _ffmpegPathResolved;

  // ─────────────────────────────────────────────────────────────────────────
  // Networking helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// The link token is saved so the URL stays the same across shows, app
  /// restarts and reboots. VLC can keep it in its recent list for good.
  Future<String> _loadOrCreateToken() async {
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

  /// Makes a brand-new link, cutting off anyone using the old one.
  Future<void> resetLink() async {
    final t = _randomToken();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefToken, t);
    } catch (_) {}
    if (!isRunning) return;
    _token = t;
    _killEncoders();
    final endpoints = await _buildEndpoints(_server!.port);
    status.value = status.value.copyWith(endpoints: endpoints);
  }

  static String _randomToken() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static bool _isPrivate(InternetAddress a) {
    final b = a.rawAddress;
    if (b.length != 4) return false;
    if (b[0] == 10) return true;
    if (b[0] == 192 && b[1] == 168) return true;
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
    if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return true; // CGNAT / Tailscale
    return false;
  }

  static const _vpnNameHints = [
    'wireguard', 'surfshark', 'nordlynx', 'nordvpn', 'proton', 'mullvad',
    'expressvpn', 'openvpn', 'tap-windows', 'tap-', 'wintun', 'pia', 'cyberghost',
    'windscribe', 'vpn', 'wg', 'tun', 'utun', 'ppp', 'ipsec',
  ];

  /// This machine's LAN IPv4 addresses, best first, as (adapterName, address).
  /// VPN tunnels and virtual adapters are left out: other devices at home
  /// can't reach them, and listing them only causes confusion.
  static Future<List<(String, String)>> lanAddresses() async {
    final result = <(String, String)>[];
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final scored = <(int, String, String)>[];
      for (final i in ifaces) {
        final n = i.name.toLowerCase();
        if (n.contains('docker') || n.startsWith('br-') || n.startsWith('veth') ||
            n.contains('vmnet') || n.contains('virtualbox') || n.contains('vbox') ||
            n.contains('wsl') || n.contains('hyper-v') || n.contains('vethernet')) {
          continue;
        }
        final isMesh = n.contains('tailscale') || n.contains('zerotier');
        if (!isMesh && _vpnNameHints.any((h) => n == h || n.startsWith(h) || (h.length > 3 && n.contains(h)))) {
          continue;
        }
        for (final a in i.addresses) {
          if (a.isLoopback || a.isLinkLocal) continue;
          var score = 0;
          if (a.address.startsWith('192.168.')) score += 30;
          if (a.address.startsWith('10.')) score += 20;
          if (_isPrivate(a)) score += 10;
          if (n.contains('wlan') || n.contains('wi-fi') || n.contains('wifi') ||
              n.startsWith('en') || n.startsWith('eth') || n.contains('ethernet')) {
            score += 5;
          }
          if (isMesh) score -= 15;
          scored.add((score, i.name, a.address));
        }
      }
      scored.sort((x, y) => y.$1.compareTo(x.$1));
      for (final (_, name, addr) in scored) {
        result.add((name, addr));
      }
    } catch (e) {
      debugPrint('[LanCast] could not list interfaces: $e');
    }
    return result;
  }

  Future<List<LanCastEndpoint>> _buildEndpoints(int port) async {
    final result = <LanCastEndpoint>[];
    for (final (name, addr) in await lanAddresses()) {
      final base = 'http://$addr:$port/$_token';
      result.add(LanCastEndpoint(
        interfaceName: name,
        address: addr,
        streamUrl: '$base/${_streamPath()}',
        playlistUrl: '$base/playlist.m3u',
        pageUrl: '$base/',
      ));
    }
    return result;
  }

  static bool _isLoopbackUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == '127.0.0.1' || host == 'localhost' || host == '::1' || host == '[::1]';
  }

  static bool _looksLikeHls(String url) {
    final l = url.toLowerCase();
    return l.contains('.m3u8') || l.contains('/hls/') || l.contains('type=m3u8');
  }

  static bool _isLocalFile(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return false;
    try {
      return File(url).existsSync();
    } catch (_) {
      return false;
    }
  }

  void _registerClient(Object key, HttpRequest req) {
    final addr = req.connectionInfo?.remoteAddress.address ?? '?';
    _clients[key] = addr;
    _publishClients();
    // VLC opens a new connection on every seek, so only fire for a device's
    // first connection. Otherwise resuming here would get paused again.
    if (_seenAddresses.add(addr)) {
      try {
        _onClientConnected?.call();
      } catch (_) {}
    }
  }

  void _unregisterClient(Object key) {
    if (_clients.remove(key) != null) _publishClients();
  }

  void _publishClients() {
    if (!isRunning) return;
    final addrs = _clients.values.toSet().toList();
    status.value = status.value.copyWith(activeClients: _clients.length, clientAddresses: addrs);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Request routing
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final segs = req.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isEmpty || segs.first != _token || _sourceUrl == null) {
        res.statusCode = HttpStatus.notFound;
        res.write('Not found');
        await res.close();
        return;
      }
      final route = segs.length > 1 ? segs[1] : '';
      res.headers.set('Access-Control-Allow-Origin', '*');
      res.headers.set('Cache-Control', 'no-store');

      switch (route) {
        case '':
        case 'index.html':
          await _serveIndex(req);
          return;
        case 'playlist.m3u':
        case 'playlist.m3u8':
          await _servePlaylist(req);
          return;
        case 'video':
          if (_quality.isOriginal && !_looksLikeHls(_sourceUrl!)) {
            await _servePassthrough(req);
          } else {
            await _serveTranscode(req);
          }
          return;
        case 'stream.ts':
          if (_quality.isOriginal && !_looksLikeHls(_sourceUrl!)) {
            // Original + non-HLS: the /video route is the right one, but be
            // forgiving if someone typed stream.ts.
            await _servePassthrough(req);
          } else {
            await _serveTranscode(req);
          }
          return;
        default:
          res.statusCode = HttpStatus.notFound;
          await res.close();
      }
    } catch (e) {
      debugPrint('[LanCast] request error: $e');
      try {
        res.statusCode = HttpStatus.internalServerError;
        await res.close();
      } catch (_) {}
    }
  }

  String _streamPath() =>
      (_quality.isOriginal && !_looksLikeHls(_sourceUrl ?? '')) ? 'video' : 'stream.ts';

  String _hostFor(HttpRequest req) {
    final h = req.headers.host;
    final p = req.headers.port ?? _server?.port ?? defaultPort;
    if (h != null && h.isNotEmpty) return '$h:$p';
    final local = req.connectionInfo?.localPort ?? p;
    return 'localhost:$local';
  }

  Future<void> _servePlaylist(HttpRequest req) async {
    final res = req.response;
    final url = 'http://${_hostFor(req)}/$_token/${_streamPath()}';
    final safeTitle = _title.replaceAll(RegExp(r'[\r\n]'), ' ');
    res.headers.contentType = ContentType('audio', 'x-mpegurl', charset: 'utf-8');
    res.headers.set('Content-Disposition', 'inline; filename="playtorrio.m3u"');
    res.write('#EXTM3U\n#EXTINF:-1,$safeTitle\n$url\n');
    await res.close();
  }

  Future<void> _serveIndex(HttpRequest req) async {
    final res = req.response;
    final streamUrl = 'http://${_hostFor(req)}/$_token/${_streamPath()}';
    final playlist = 'http://${_hostFor(req)}/$_token/playlist.m3u';
    const esc = HtmlEscape();
    res.headers.contentType = ContentType.html;
    res.write('''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc.convert(_title)} · PlayTorrio LAN</title>
<style>body{font-family:system-ui,sans-serif;background:#0b0d12;color:#e8e8ee;max-width:640px;margin:40px auto;padding:0 16px}
a{color:#9d84ff}code{background:#1c1f29;padding:6px 8px;border-radius:6px;display:block;word-break:break-all;margin:6px 0 14px}
.b{display:inline-block;background:#7c5cff;color:#fff;padding:10px 16px;border-radius:10px;text-decoration:none;margin:6px 6px 6px 0}</style></head>
<body><h2>${esc.convert(_title)}</h2>
<p>Quality: <b>${esc.convert(_quality.label)}</b> (${esc.convert(_quality.bitrateLabel)})</p>
<p><a class="b" href="vlc://$streamUrl">Open in VLC</a><a class="b" href="$playlist">Download .m3u</a></p>
<p>Or in VLC: <i>Media → Open Network Stream</i> and paste:</p>
<code>$streamUrl</code>
</body></html>''');
    await res.close();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Original quality: byte-for-byte proxy with Range support
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _servePassthrough(HttpRequest req) async {
    final res = req.response;
    final src = _sourceUrl!;
    final key = Object();
    final isHead = req.method == 'HEAD';

    if (_isLocalFile(src)) {
      await _serveLocalFile(req, File(src), key);
      return;
    }

    HttpClientRequest upReq;
    try {
      upReq = await _http.openUrl(isHead ? 'HEAD' : 'GET', Uri.parse(src));
    } catch (e) {
      res.statusCode = HttpStatus.badGateway;
      res.write('Upstream error: $e');
      await res.close();
      return;
    }
    upReq.followRedirects = true;
    upReq.maxRedirects = 8;
    _sourceHeaders.forEach((k, v) {
      try {
        upReq.headers.set(k, v);
      } catch (_) {}
    });
    final range = req.headers.value(HttpHeaders.rangeHeader);
    if (range != null) upReq.headers.set(HttpHeaders.rangeHeader, range);

    HttpClientResponse up;
    try {
      up = await upReq.close();
    } catch (e) {
      res.statusCode = HttpStatus.badGateway;
      res.write('Upstream error: $e');
      await res.close();
      return;
    }

    res.statusCode = up.statusCode;
    for (final h in const [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentEncodingHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.lastModifiedHeader,
      HttpHeaders.etagHeader,
    ]) {
      final v = up.headers.value(h);
      if (v != null) res.headers.set(h, v);
    }
    if (up.headers.value(HttpHeaders.acceptRangesHeader) == null) {
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    }
    if (up.contentLength >= 0) {
      res.contentLength = up.contentLength;
    }
    res.bufferOutput = false;

    if (isHead) {
      await up.drain<void>().catchError((_) {});
      await res.close();
      return;
    }

    _registerClient(key, req);
    try {
      await res.addStream(up);
    } catch (_) {
      // Client hung up or seeked; VLC does this constantly.
    } finally {
      _unregisterClient(key);
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _serveLocalFile(HttpRequest req, File file, Object key) async {
    final res = req.response;
    final len = await file.length();
    var start = 0;
    var end = len - 1;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.contentType = _guessMime(file.path);
    if (m != null) {
      final s = m.group(1) ?? '';
      final e = m.group(2) ?? '';
      if (s.isEmpty && e.isNotEmpty) {
        start = max(0, len - int.parse(e));
      } else {
        start = int.tryParse(s) ?? 0;
        if (e.isNotEmpty) end = min(len - 1, int.parse(e));
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
    _registerClient(key, req);
    try {
      await res.addStream(file.openRead(start, end + 1));
    } catch (_) {
    } finally {
      _unregisterClient(key);
      try {
        await res.close();
      } catch (_) {}
    }
  }

  static ContentType _guessMime(String path) {
    final l = path.toLowerCase();
    if (l.endsWith('.mkv')) return ContentType('video', 'x-matroska');
    if (l.endsWith('.webm')) return ContentType('video', 'webm');
    if (l.endsWith('.avi')) return ContentType('video', 'x-msvideo');
    if (l.endsWith('.ts')) return ContentType('video', 'mp2t');
    if (l.endsWith('.mov')) return ContentType('video', 'quicktime');
    return ContentType('video', 'mp4');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Custom bitrate: FFmpeg → MPEG-TS
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the FFmpeg argument list. Public for testing.
  static List<String> buildFfmpegArgs({
    required String input,
    required Map<String, String> headers,
    required LanCastQuality quality,
    Duration start = Duration.zero,
    int? audioStreamIndex,
  }) {
    final isNetwork = input.startsWith('http://') || input.startsWith('https://');
    final args = <String>['-hide_banner', '-loglevel', 'error', '-nostdin'];

    if (isNetwork) {
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
      args.addAll([
        '-reconnect', '1',
        '-reconnect_streamed', '1',
        '-reconnect_on_network_error', '1',
        '-reconnect_delay_max', '10',
        // The in-app torrent engine (TorrServer on 127.0.0.1) holds a read
        // open until the pieces arrive from peers, which can take a while on
        // a thin swarm. Give it far longer than a CDN before giving up.
        '-rw_timeout', _isLoopbackUrl(input) ? '180000000' : '30000000',
      ]);
    }

    if (start > const Duration(seconds: 1)) {
      args.addAll(['-ss', (start.inMilliseconds / 1000.0).toStringAsFixed(3)]);
    }
    args.addAll(['-fflags', '+genpts+discardcorrupt', '-i', input]);

    final a = audioStreamIndex != null && audioStreamIndex >= 0 ? audioStreamIndex : 0;
    args.addAll(['-map', '0:v:0', '-map', '0:a:$a?', '-sn', '-dn']);

    if (quality.isOriginal) {
      // HLS source at original quality: just remux to TS.
      args.addAll(['-c', 'copy']);
    } else {
      final v = quality.videoKbps;
      final h = quality.maxHeight;
      args.addAll([
        // Downscale only; keep aspect ratio and even dimensions.
        '-vf', "scale=-2:'min($h,ih)':flags=bicubic,format=yuv420p",
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-profile:v', 'high',
        '-level:v', h > 1080 ? '5.1' : '4.1',
        '-b:v', '${v}k',
        '-maxrate', '${(v * 1.25).round()}k',
        '-bufsize', '${v * 2}k',
        '-g', '96',
        '-keyint_min', '48',
        '-sc_threshold', '0',
        '-c:a', 'aac',
        '-b:a', '${quality.audioKbps}k',
        '-ac', '2',
        '-ar', '48000',
      ]);
    }

    args.addAll([
      '-max_muxing_queue_size', '2048',
      '-muxdelay', '0',
      '-f', 'mpegts',
      '-mpegts_flags', '+resend_headers',
      'pipe:1',
    ]);
    return args;
  }

  Future<void> _serveTranscode(HttpRequest req) async {
    final res = req.response;
    final ffmpeg = _ffmpegPathResolved;
    if (ffmpeg == null) {
      res.statusCode = HttpStatus.serviceUnavailable;
      res.write('FFmpeg not available');
      await res.close();
      return;
    }

    res.headers.contentType = ContentType('video', 'mp2t');
    // A live transcode has no length and can't be byte-seeked.
    res.headers.set(HttpHeaders.acceptRangesHeader, 'none');

    if (req.method == 'HEAD') {
      await res.close();
      return;
    }

    if (_encoders.length >= maxConcurrentClients) {
      res.statusCode = HttpStatus.serviceUnavailable;
      res.write('Too many viewers');
      await res.close();
      return;
    }

    // Some players probe with "Range: bytes=N-" after the first request.
    // We can't honour byte ranges on a live encode; a non-zero range just gets
    // a fresh stream from the current position.
    Duration startAt = Duration.zero;
    if (_startMode == LanCastStartMode.followPlayer) {
      try {
        startAt = _positionProvider?.call() ?? Duration.zero;
      } catch (_) {}
    }
    final qStart = req.uri.queryParameters['t'];
    if (qStart != null) {
      final secs = double.tryParse(qStart);
      if (secs != null && secs >= 0) startAt = Duration(milliseconds: (secs * 1000).round());
    }

    int? audioIdx;
    try {
      final aid = _audioTrackProvider?.call();
      if (aid != null && aid > 0) audioIdx = aid - 1; // mpv aid is 1-based
    } catch (_) {}

    final args = buildFfmpegArgs(
      input: _sourceUrl!,
      headers: _sourceHeaders,
      quality: _quality,
      start: startAt,
      audioStreamIndex: audioIdx,
    );
    debugPrint('[LanCast] ffmpeg ${args.join(' ')}');

    Process proc;
    try {
      proc = await Process.start(ffmpeg, args, runInShell: false);
    } catch (e) {
      res.statusCode = HttpStatus.internalServerError;
      res.write('Failed to start FFmpeg: $e');
      await res.close();
      return;
    }
    _encoders.add(proc);
    final key = Object();
    _registerClient(key, req);

    final errTail = <String>[];
    proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
      debugPrint('[LanCast/ffmpeg] $l');
      errTail.add(l);
      if (errTail.length > 6) errTail.removeAt(0);
    }, onError: (_) {});

    var clientGone = false;
    void killProc() {
      try {
        proc.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }

    // Catch viewers that leave before FFmpeg produced its first byte
    // (e.g. while a torrent is still finding peers).
    unawaited(res.done.then((_) {}, onError: (_) {
      clientGone = true;
      killProc();
    }));

    res.bufferOutput = false;
    try {
      await res.addStream(proc.stdout);
    } catch (_) {
      clientGone = true;
    } finally {
      killProc();
      _encoders.remove(proc);
      _unregisterClient(key);
      try {
        await res.close();
      } catch (_) {}
    }

    if (!clientGone) {
      // stdout ended on its own: FFmpeg finished or failed.
      final code = await proc.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => 0);
      if (code != 0 && errTail.isNotEmpty && isRunning) {
        status.value = status.value.copyWith(error: 'FFmpeg: ${errTail.last}');
      }
    }
  }
}

class LanCastPrefs {
  final String qualityId;
  final int customKbps;
  final int port;
  final String ffmpegPath;
  final LanCastStartMode startMode;
  final bool pauseLocalOnConnect;

  const LanCastPrefs({
    required this.qualityId,
    required this.customKbps,
    required this.port,
    required this.ffmpegPath,
    required this.startMode,
    required this.pauseLocalOnConnect,
  });

  LanCastQuality get quality {
    if (qualityId == 'custom') return LanCastQuality.custom(customKbps);
    return LanCastQuality.presets.firstWhere(
      (p) => p.id == qualityId,
      orElse: () => LanCastQuality.presets.firstWhere((p) => p.id == LanCastQuality.defaultPreset),
    );
  }

  LanCastPrefs copyWith({
    String? qualityId,
    int? customKbps,
    int? port,
    String? ffmpegPath,
    LanCastStartMode? startMode,
    bool? pauseLocalOnConnect,
  }) {
    return LanCastPrefs(
      qualityId: qualityId ?? this.qualityId,
      customKbps: customKbps ?? this.customKbps,
      port: port ?? this.port,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      startMode: startMode ?? this.startMode,
      pauseLocalOnConnect: pauseLocalOnConnect ?? this.pauseLocalOnConnect,
    );
  }
}
