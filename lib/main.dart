import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================================
//  FachriMusic - pemutar musik offline
//  Tampilan: clean, elegan, berkarisma (dark + aksen emas)
// ============================================================================

void main() => runApp(const FachriMusicApp());

class FachriMusicApp extends StatelessWidget {
  const FachriMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FachriMusic',
      theme: _theme(),
      home: const HomePage(),
    );
  }
}

// ---------- palet warna elegan ----------
const _gold = Color(0xFFE8C872);
const _inkTop = Color(0xFF0E1018);
const _inkBottom = Color(0xFF1A1E2E);
const _surface = Color(0xCC232636);
const _muted = Colors.white70;

ThemeData _theme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: _gold,
      secondary: _gold,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: _gold,
      thumbColor: _gold,
      overlayColor: _gold.withOpacity(0.15),
      inactiveTrackColor: Colors.white24,
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AudioPlayer _player;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel>? _songs;
  bool _granted = false;
  bool _loading = true;

  int _currentIndex = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));

    _boot();
  }

  Future<void> _boot() async {
    await _requestPermission();
    await _loadSongs();
  }

  Future<void> _requestPermission() async {
    var status = await Permission.audio.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (mounted) setState(() => _granted = status.isGranted);
  }

  Future<void> _loadSongs() async {
    if (mounted) setState(() => _loading = true);
    try {
      final songs = await _audioQuery.querySongs();
      if (mounted) setState(() => _songs = songs);
    } catch (_) {
      if (mounted) setState(() => _songs = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- logika pemutar ----------
  Future<void> _playIndex(int index) async {
    final songs = _songs;
    if (songs == null || songs.isEmpty) return;
    try {
      await _player.stop();
      await _player.setSource(DeviceFileSource(songs[index].data));
      await _player.resume();
      if (mounted) {
        setState(() {
          _currentIndex = index;
          _position = Duration.zero;
          _playing = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memutar file ini.')),
        );
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_currentIndex < 0 || _songs == null || _songs!.isEmpty) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _next() async {
    if (_songs == null || _songs!.isEmpty) return;
    await _playIndex((_currentIndex + 1) % _songs!.length);
  }

  Future<void> _prev() async {
    if (_songs == null || _songs!.isEmpty) return;
    await _playIndex(_currentIndex - 1 < 0 ? _songs!.length - 1 : _currentIndex - 1);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  // ==========================================================================
  //  BACKGROUND: gelap kalem + cahaya emas lembut di atas (statis, clean)
  // ==========================================================================
  Widget _background() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_inkTop, _inkBottom],
        ),
      ),
      child: Stack(
        children: [
          // cahaya lembut khas premium, tipis & tidak mengganggu
          Positioned(
            top: -140,
            left: -60,
            right: -60,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(600),
                  gradient: RadialGradient(
                    colors: [_gold.withOpacity(0.14), _gold.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _background()),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildMainArea()),
        if (_currentIndex >= 0) _buildPlayerBar(),
      ],
    );
  }

  // ---------- Header ----------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
      child: Row(
        children: [
          // logo kecil elegan
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF2D591), _gold]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _gold.withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.graphic_eq, color: Color(0xFF171A22), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Fachri',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 21,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(
                        text: 'Music',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _gold,
                          fontSize: 21,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'OFFLINE MUSIC PLAYER',
                  style: TextStyle(
                    letterSpacing: 2.2,
                    fontSize: 10,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang daftar lagu',
            onPressed: _loadSongs,
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ---------- Area utama ----------
  Widget _buildMainArea() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(color: _gold, strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text('Memuat daftar lagu...', style: TextStyle(color: _muted)),
          ],
        ),
      );
    }

    if (!_granted) {
      return _buildPermissionCard();
    }

    final songs = _songs ?? [];
    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.music_off, color: Colors.white38, size: 46),
              SizedBox(height: 14),
              Text(
                'Belum ada lagu ditemukan.\n\nPastikan ada file MP3 di penyimpanan HP,\nlalu tekan tombol refresh di kanan atas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      itemCount: songs.length,
      itemBuilder: (ctx, i) => _songTile(songs[i], i),
    );
  }

  Widget _buildPermissionCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, color: _gold, size: 54),
            const SizedBox(height: 16),
            const Text(
              'Akses Musik',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'FachriMusic butuh izin ke file musik di HP kamu untuk membaca & memutar lagu offline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () async {
                await _requestPermission();
                await _loadSongs();
              },
              icon: const Icon(Icons.key, size: 18),
              label: const Text('Beri Izin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF171A22),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songTile(SongModel s, int i) {
    final isCurrent = i == _currentIndex;
    final color = isCurrent ? _gold : Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _playIndex(i),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrent ? _gold.withOpacity(0.10) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: isCurrent ? Border.all(color: _gold.withOpacity(0.6)) : null,
        ),
        child: Row(
          children: [
            _avatar(s, isCurrent),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.artist ?? 'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmt(Duration(milliseconds: s.duration ?? 0)),
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(width: 8),
            Icon(
              isCurrent ? Icons.equalizer : Icons.play_circle_outline_rounded,
              size: 22,
              color: _gold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(SongModel s, bool isCurrent) {
    final letter = (s.title.isNotEmpty) ? s.title[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF2A2E40),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isCurrent ? _gold : Colors.white70,
          fontSize: 18,
        ),
      ),
    );
  }

  // ---------- Player bar (panel bawah) ----------
  Widget _buildPlayerBar() {
    final s = _songs![_currentIndex];
    final max = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final pos = _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withOpacity(0.25)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.music_note_rounded, color: _gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.artist ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: pos,
            min: 0,
            max: max,
            onChanged: (v) {
              final d = Duration(milliseconds: v.round());
              setState(() => _position = d);
              _player.seek(d);
            },
          ),
          Row(
            children: [
              Text(_fmt(_position), style: const TextStyle(fontSize: 11, color: _muted)),
              const Spacer(),
              IconButton(
                onPressed: _prev,
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFF2D591), _gold]),
                ),
                child: IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  color: const Color(0xFF171A22),
                  iconSize: 28,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _next,
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white,
              ),
              const Spacer(),
              Text(_fmt(_duration), style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  Util
// ============================================================================
String _fmt(Duration d) {
  final mm = (d.inMinutes.remainder(60)).toString().padLeft(2, '0');
  final ss = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
  return '$mm:$ss';
}
