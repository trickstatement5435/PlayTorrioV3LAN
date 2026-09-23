import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/lan_cast/lan_cast_service.dart';
import '../../services/web_ui/web_ui_server.dart';

/// Settings > Web Player: shows the link to open PlayTorrio in a browser on
/// another device, plus on/off, port and "new link".
class WebUiSettingsPage extends StatefulWidget {
  const WebUiSettingsPage({super.key});

  @override
  State<WebUiSettingsPage> createState() => _WebUiSettingsPageState();
}

class _WebUiSettingsPageState extends State<WebUiSettingsPage> {
  final _svc = WebUiServer.instance;
  late final TextEditingController _portCtrl =
      TextEditingController(text: _svc.status.value.port.toString());
  bool _busy = false;
  bool? _ffmpeg;

  static const _bg = Color(0xFF080A0F);
  static const _card = Color(0xFF12151E);
  static const _accent = Color(0xFF7C5CFF);
  static const _good = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _svc.refreshUrls();
    LanCastService.instance.savedFfmpegPath().then((p) => LanCastService.instance.findFfmpeg(p)).then((f) {
      if (mounted) setState(() => _ffmpeg = f != null);
    });
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    super.dispose();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Link copied'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmNewLink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Make a new link?'),
        content: const Text('The old link stops working, including any bookmarks on other devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('New link')),
        ],
      ),
    );
    if (ok == true) await _run(_svc.resetLink);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Web Player', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ValueListenableBuilder<WebUiStatus>(
            valueListenable: _svc.status,
            builder: (context, st, _) => ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _box(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.connected_tv_rounded, color: _accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Watch in a browser on your network',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              st.running
                                  ? (st.activeStreams > 0
                                      ? 'On · ${st.activeStreams} streaming now'
                                      : 'On · starts automatically with PlayTorrio')
                                  : 'Off',
                              style: TextStyle(
                                  color: st.running ? _good : Colors.white54, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: st.enabled,
                        activeColor: _accent,
                        onChanged: _busy ? null : (v) => _run(() => _svc.setEnabled(v)),
                      ),
                    ],
                  ),
                ),
                if (st.error != null) ...[
                  const SizedBox(height: 12),
                  _box(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    child: Text(st.error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                ],
                if (st.running) ...[
                  const SizedBox(height: 16),
                  const _Label('Open this link on your other computer, phone or TV browser'),
                  const SizedBox(height: 8),
                  if (st.urls.isEmpty)
                    _box(
                      child: const Text('No home network found. Connect this PC to Wi-Fi or Ethernet.',
                          style: TextStyle(color: Colors.orangeAccent)),
                    )
                  else
                    for (final (i, u) in st.urls.indexed) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _box(
                        color: i == 0 ? _accent.withValues(alpha: 0.12) : null,
                        border: i == 0 ? _accent.withValues(alpha: 0.5) : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(u.url,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
                                  Text(u.adapter,
                                      style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy',
                              icon: const Icon(Icons.copy_rounded, size: 19),
                              onPressed: () => _copy(u.url),
                            ),
                            IconButton(
                              tooltip: 'Open here',
                              icon: const Icon(Icons.open_in_new_rounded, size: 19),
                              onPressed: () => launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication),
                            ),
                          ],
                        ),
                      ),
                    ],
                  const SizedBox(height: 10),
                  const Text(
                    'The link never changes, so bookmark it. It only works on your home network, and the '
                    'random code in it keeps other people on the network out. Keep PlayTorrio open (it can '
                    'be minimized) while you watch.',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4),
                  ),
                  if (_ffmpeg == false) ...[
                    const SizedBox(height: 12),
                    _box(
                      color: Colors.orange.withValues(alpha: 0.12),
                      child: const Text(
                        'FFmpeg was not found, so most videos can\'t be converted for the browser. '
                        'Put ffmpeg.exe and ffprobe.exe next to PlayTorrio, or set the FFmpeg path in the '
                        'player\'s "Stream to LAN" panel under Advanced.',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12.5),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 22),
                const _Label('Advanced'),
                const SizedBox(height: 8),
                _box(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            helperText: 'Default ${WebUiServer.defaultPort}. Changing it changes the link.',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                final p = int.tryParse(_portCtrl.text.trim());
                                if (p != null) _run(() => _svc.setPort(p));
                              },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _box(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Make a new link (cuts off anyone using the old one)',
                            style: TextStyle(fontSize: 13.5)),
                      ),
                      TextButton(
                        onPressed: _busy || !st.running ? null : _confirmNewLink,
                        child: const Text('New link'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box({required Widget child, Color? color, Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color ?? _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border ?? Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      );
}
