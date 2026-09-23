import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/lan_cast/lan_cast_service.dart';
import 'player_glass.dart';

/// Opens the "Stream to LAN" dialog.
///
/// The player passes in what it is currently playing plus a few live
/// callbacks so the restream can start where the viewer is.
Future<void> showLanCastDialog(
  BuildContext context, {
  required String sourceUrl,
  required Map<String, String> headers,
  required String title,
  required Duration Function() positionProvider,
  required int? Function() audioTrackProvider,
  required VoidCallback onPauseLocal,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => LanCastDialog(
      sourceUrl: sourceUrl,
      headers: headers,
      title: title,
      positionProvider: positionProvider,
      audioTrackProvider: audioTrackProvider,
      onPauseLocal: onPauseLocal,
    ),
  );
}

class LanCastDialog extends StatefulWidget {
  final String sourceUrl;
  final Map<String, String> headers;
  final String title;
  final Duration Function() positionProvider;
  final int? Function() audioTrackProvider;
  final VoidCallback onPauseLocal;

  const LanCastDialog({
    super.key,
    required this.sourceUrl,
    required this.headers,
    required this.title,
    required this.positionProvider,
    required this.audioTrackProvider,
    required this.onPauseLocal,
  });

  @override
  State<LanCastDialog> createState() => _LanCastDialogState();
}

class _LanCastDialogState extends State<LanCastDialog> {
  final _svc = LanCastService.instance;
  LanCastPrefs? _prefs;
  bool _busy = false;
  bool _ffmpegChecked = false;
  String? _ffmpegFound;
  late final TextEditingController _portCtrl = TextEditingController();
  late final TextEditingController _ffmpegCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _svc.loadPrefs();
    _portCtrl.text = p.port.toString();
    _ffmpegCtrl.text = p.ffmpegPath;
    if (!mounted) return;
    setState(() => _prefs = p);
    _checkFfmpeg();
  }

  Future<void> _checkFfmpeg() async {
    final f = await _svc.findFfmpeg(_ffmpegCtrl.text);
    if (!mounted) return;
    setState(() {
      _ffmpegChecked = true;
      _ffmpegFound = f;
      // Without FFmpeg only passthrough works; don't leave a dead preset selected.
      if (f == null && _prefs != null && _prefs!.qualityId != LanCastQuality.original.id) {
        _prefs = _prefs!.copyWith(qualityId: LanCastQuality.original.id);
      }
    });
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _ffmpegCtrl.dispose();
    super.dispose();
  }

  LanCastPrefs get _p => _prefs!;

  Future<void> _start() async {
    final port = int.tryParse(_portCtrl.text.trim());
    final prefs = _p.copyWith(
      port: (port != null && port > 0 && port < 65536) ? port : LanCastService.defaultPort,
      ffmpegPath: _ffmpegCtrl.text.trim(),
    );
    setState(() {
      _prefs = prefs;
      _busy = true;
    });
    await _svc.savePrefs(prefs);
    await _svc.start(
      sourceUrl: widget.sourceUrl,
      headers: widget.headers,
      title: widget.title,
      quality: prefs.quality,
      port: prefs.port,
      ffmpegPath: prefs.ffmpegPath,
      startMode: prefs.startMode,
      positionProvider: widget.positionProvider,
      audioTrackProvider: widget.audioTrackProvider,
      onClientConnected: () {
        if (prefs.pauseLocalOnConnect) widget.onPauseLocal();
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await _svc.stop();
    if (mounted) setState(() => _busy = false);
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$what copied', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E2028),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: PlayerTheme.elevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PlayerTheme.edge),
            boxShadow: PlayerTheme.menuShadow,
          ),
          child: _prefs == null
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(color: PlayerTheme.accent)),
                )
              : ValueListenableBuilder<LanCastStatus>(
                  valueListenable: _svc.status,
                  builder: (context, st, _) => _buildBody(st),
                ),
        ),
      ),
    );
  }

  Widget _buildBody(LanCastStatus st) {
    final q = _p.quality;
    final running = st.running;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.cast_connected_rounded, color: PlayerTheme.accent, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Stream to LAN (VLC)',
                  style: TextStyle(color: PlayerTheme.ink, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              _statusPill(st),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, color: PlayerTheme.inkMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Serve this video on your network so VLC on another computer, phone or TV can open it.',
            style: TextStyle(color: PlayerTheme.inkMuted, fontSize: 12.5, height: 1.35),
          ),

          if (running) ...[
            const SizedBox(height: 16),
            _buildUrlCard(st),
          ],

          const SizedBox(height: 18),
          _sectionLabel('Bitrate'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in LanCastQuality.presets)
                _qualityChip(
                  label: preset.label,
                  sub: preset.isOriginal ? 'no re-encode' : preset.bitrateLabel,
                  selected: _p.qualityId == preset.id,
                  enabled: preset.isOriginal || _canTranscode,
                  onTap: () => setState(() => _prefs = _p.copyWith(qualityId: preset.id)),
                ),
              _qualityChip(
                label: 'Custom',
                sub: '${(_p.customKbps / 1000).toStringAsFixed(1)} Mbps',
                selected: _p.qualityId == 'custom',
                enabled: _canTranscode,
                onTap: () => setState(() => _prefs = _p.copyWith(qualityId: 'custom')),
              ),
            ],
          ),
          if (_p.qualityId == 'custom') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: PlayerTheme.accent,
                      thumbColor: Colors.white,
                      inactiveTrackColor: PlayerTheme.raised,
                      overlayColor: PlayerTheme.accentSoft,
                    ),
                    child: Slider(
                      min: 500,
                      max: 40000,
                      divisions: 79,
                      value: _p.customKbps.clamp(500, 40000).toDouble(),
                      onChanged: (v) => setState(() => _prefs = _p.copyWith(customKbps: v.round())),
                    ),
                  ),
                ),
                SizedBox(
                  width: 74,
                  child: Text(
                    '${(_p.customKbps / 1000).toStringAsFixed(1)} Mbps',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: PlayerTheme.ink, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _qualityDescription(q),
            style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 12, height: 1.35),
          ),
          if (_ffmpegChecked && !_canTranscode) ...[
            const SizedBox(height: 8),
            _notice(
              LanCastService.transcodeSupportedOnPlatform
                  ? 'FFmpeg not found, so only "Original" is available. Install FFmpeg or set its path under Advanced.'
                  : 'Custom bitrates need FFmpeg, which only runs on the desktop app. "Original" works here.',
              PlayerTheme.warning,
            ),
          ],

          if (!q.isOriginal) ...[
            const SizedBox(height: 18),
            _sectionLabel('When a device connects, start from'),
            const SizedBox(height: 8),
            Row(
              children: [
                _segment('Where I am now', _p.startMode == LanCastStartMode.followPlayer,
                    () => setState(() => _prefs = _p.copyWith(startMode: LanCastStartMode.followPlayer))),
                const SizedBox(width: 8),
                _segment('The beginning', _p.startMode == LanCastStartMode.beginning,
                    () => setState(() => _prefs = _p.copyWith(startMode: LanCastStartMode.beginning))),
              ],
            ),
          ],

          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: PlayerTheme.accent,
            title: const Text('Pause playback here when a device connects',
                style: TextStyle(color: PlayerTheme.ink, fontSize: 13.5)),
            value: _p.pauseLocalOnConnect,
            onChanged: (v) => setState(() => _prefs = _p.copyWith(pauseLocalOnConnect: v)),
          ),

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              iconColor: PlayerTheme.inkMuted,
              collapsedIconColor: PlayerTheme.inkMuted,
              title: const Text('Advanced', style: TextStyle(color: PlayerTheme.inkMuted, fontSize: 13.5)),
              children: [
                _field(_portCtrl, 'Port', 'Default ${LanCastService.defaultPort}', number: true),
                if (LanCastService.transcodeSupportedOnPlatform) ...[
                  const SizedBox(height: 10),
                  _field(_ffmpegCtrl, 'FFmpeg path (optional)', 'Auto-detect from PATH',
                      onSubmitted: (_) => _checkFfmpeg()),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _ffmpegFound != null ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        size: 15,
                        color: _ffmpegFound != null ? PlayerTheme.success : PlayerTheme.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          !_ffmpegChecked
                              ? 'Checking for FFmpeg...'
                              : (_ffmpegFound ?? 'FFmpeg not found'),
                          style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _checkFfmpeg,
                        child: const Text('Re-check', style: TextStyle(color: PlayerTheme.accent, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (st.error != null) ...[
            const SizedBox(height: 6),
            _notice(st.error!, PlayerTheme.danger),
          ],
          if (running && st.note != null) ...[
            const SizedBox(height: 6),
            _notice(st.note!, PlayerTheme.inkMuted),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              if (running)
                TextButton.icon(
                  onPressed: _busy ? null : _stop,
                  icon: const Icon(Icons.stop_circle_outlined, color: PlayerTheme.danger, size: 18),
                  label: const Text('Stop sharing', style: TextStyle(color: PlayerTheme.danger)),
                ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: PlayerTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _busy ? null : _start,
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(running ? Icons.refresh_rounded : Icons.play_arrow_rounded, size: 18),
                label: Text(running ? 'Apply changes' : 'Start sharing'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _canTranscode => _ffmpegFound != null;

  String _qualityDescription(LanCastQuality q) {
    if (q.isOriginal) {
      return 'Sends the exact file the app is playing. Best quality, no CPU cost, and VLC can seek. '
          'Uses whatever bitrate the source has.';
    }
    final mbps = (q.totalKbps / 1000).toStringAsFixed(1);
    return 'Re-encoded live with FFmpeg to H.264 + AAC stereo, up to ${q.maxHeight}p, '
        '~$mbps Mbps total (${q.videoKbps} kbps video + ${q.audioKbps} kbps audio). '
        'Uses the audio track selected in the player. Seeking in VLC isn\'t possible; '
        'seek here and reconnect VLC instead.';
  }

  Widget _buildUrlCard(LanCastStatus st) {
    final eps = st.endpoints;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlayerTheme.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PlayerTheme.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('In VLC: Media → Open Network Stream, paste:',
                  style: TextStyle(color: PlayerTheme.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                st.activeClients == 0
                    ? 'No viewers yet'
                    : '${st.activeClients} connection${st.activeClients == 1 ? '' : 's'}',
                style: TextStyle(
                  color: st.activeClients > 0 ? PlayerTheme.success : PlayerTheme.inkSubtle,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (eps.isEmpty)
            const Text('No network address found.', style: TextStyle(color: PlayerTheme.warning, fontSize: 12.5))
          else
            for (var i = 0; i < eps.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _urlRow(eps[i].streamUrl, eps.length > 1 ? eps[i].interfaceName : null, primary: i == 0),
            ],
          if (eps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _miniButton(Icons.playlist_play_rounded, 'Copy .m3u link', () => _copy(eps.first.playlistUrl, 'Playlist link')),
                _miniButton(Icons.language_rounded, 'Copy web page link', () => _copy(eps.first.pageUrl, 'Page link')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _urlRow(String url, String? iface, {required bool primary}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  url,
                  style: TextStyle(
                    color: primary ? PlayerTheme.ink : PlayerTheme.inkMuted,
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                  ),
                ),
                if (iface != null)
                  Text(iface, style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 10.5)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy_rounded, size: 18, color: PlayerTheme.ink),
          onPressed: () => _copy(url, 'Stream URL'),
        ),
      ],
    );
  }

  Widget _miniButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: PlayerTheme.inkMuted),
      label: Text(label, style: const TextStyle(color: PlayerTheme.inkMuted, fontSize: 11.5)),
    );
  }

  Widget _statusPill(LanCastStatus st) {
    final on = st.running;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (on ? PlayerTheme.success : PlayerTheme.inkDisabled).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: on ? PlayerTheme.success : PlayerTheme.inkSubtle,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(on ? 'LIVE' : 'OFF',
              style: TextStyle(
                  color: on ? PlayerTheme.success : PlayerTheme.inkSubtle,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: PlayerTheme.inkSubtle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      );

  Widget _qualityChip({
    required String label,
    required String sub,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? PlayerTheme.accentSoft : PlayerTheme.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? PlayerTheme.accent : PlayerTheme.edgeSoft,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(color: PlayerTheme.ink, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(sub, style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? PlayerTheme.accentSoft : PlayerTheme.raised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? PlayerTheme.accent : PlayerTheme.edgeSoft),
            ),
            child: Text(label,
                style: TextStyle(
                    color: selected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _notice(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color == PlayerTheme.inkMuted ? PlayerTheme.inkMuted : color, fontSize: 12, height: 1.35)),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool number = false, ValueChanged<String>? onSubmitted}) {
    return TextField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: PlayerTheme.ink, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: const TextStyle(color: PlayerTheme.inkMuted),
        hintStyle: const TextStyle(color: PlayerTheme.inkSubtle),
        filled: true,
        fillColor: PlayerTheme.raised,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}
