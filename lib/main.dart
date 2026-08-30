import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================================
//  FachriMusic - pemutar musik offline bergaya hacker
//  Background gradient bergerak + matrix rain + daftar lagu dari memori HP
// ============================================================================

void main() => runApp(const FachriMusicApp());

class FachriMusicApp extends StatelessWidget {
  const FachriMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FachriMusic',
      theme: _darkTheme(),
      home: const HomePage(),
    );
  }
}

ThemeData _darkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: const Color(0xFF00E5FF),
      secondary: const Color(0xFF00FFAA),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: const Color(0xFF00E5FF),
      thumbColor: const Color(0xFF00FFAA),
      overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
      inactiveTrackColor: Colors.white12,
    ),
  );
}

// ============================================================================
//  Peta warna untuk gradient yang "bernafas" (animasi)
// ============================================================================
const _palette = <Color>[
  Color(0xFF3A00B8), // ungu dalam
  Color(0xFF00E5FF), // cyan
  Color(0xFF7C00E0), // ungu terang
  Color(0xFF00FFAA), // hijau neon
  Color(0xFF15005A), // biru malam
  Color(0xFFFF2BD6), // magenta
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gradCtrl;
  late final AudioPlayer _player;
  final AudioQuery _audioQuery = AudioQuery();

  List<SongModel>? _songs;
  bool _granted = false;
  bool _loading = true;

  int _currentIndex = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  // ---------- deklarasi stream subscription ----------
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _gradCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..repeat();
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
    // Android 13+ pakai izin audio; yang lama pakai izin penyimpanan
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
      if (mounted) {
        setState(() => _songs = songs);
      }
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
    final next = (_currentIndex + 1) % _songs!.length;
    await _playIndex(next);
  }

  Future<void> _prev() async {
    if (_songs == null || _songs!.isEmpty) return;
    final prev = (_currentIndex - 1) < 0 ? _songs!.length - 1 : _currentIndex - 1;
    await _playIndex(prev);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    _gradCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  //  UI
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1) background gradient animasi
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gradCtrl,
              builder: (_, __) {
                final t = _gradCtrl.value;
                final a = _palette[(t * _palette.length).floor() % _palette.length];
                final b =
                    _palette[((t * _palette.length).floor() + 1) % _palette.length];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(2 * t - 1, -1),
                      end: Alignment(1 - 2 * t, 1),
                      colors: [Color.lerp(a, b, t)!, Color.lerp(b, a, t)!],
                    ),
                  ),
                );
              },
            ),
          ),
          // 2) efek hujan digital (matrix rain)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gradCtrl,
              builder: (_, __) => CustomPaint(painter: _MatrixRain(_gradCtrl.value)),
            ),
          ),
          // 3) konten
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF7C00E0)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.black, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FACHRI_MUSIC',
                  style: const TextStyle(
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00FFAA),
                    fontSize: 19,
                  ),
                ),
                Row(
                  children: const [
                    Icon(Icons.circle, size: 7, color: Color(0xFF00E5FF)),
                    SizedBox(width: 5),
                    Text(
                      'SECURE AUDIO NETWORK',
                      style: TextStyle(
                        letterSpacing: 2,
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang daftar lagu',
            onPressed: _loadSongs,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArea() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                color: Color(0xFF00E5FF),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 18),
            Text('MEN-SCAN LAGU...', style: TextStyle(letterSpacing: 3, color: Colors.white70)),
          ],
        ),
      );
    }

    if (!_granted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFF00E5FF), size: 56),
              const SizedBox(height: 16),
              const Text(
                'IZIN DIBUTUHKAN',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              const Text(
                'FachriMusic butuh akses ke file musik HP kamu supaya bisa membaca & memutar lagu secara offline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await _requestPermission();
                  await _loadSongs();
                },
                icon: const Icon(Icons.key),
                label: const Text('BERI IZIN SEKARANG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final songs = _songs ?? [];
    if (songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_off, color: Colors.white54, size: 52),
              SizedBox(height: 16),
              Text(
                'Belum ada lagu ditemukan.\n\nPastikan ada file MP3 di penyimpanan HP,\nlalu tekan tombol refresh di kanan atas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: songs.length,
      itemBuilder: (ctx, i) {
        final s = songs[i];
        final dur = Duration(milliseconds: s.duration ?? 0);
        final isCurrent = i == _currentIndex;
        return InkWell(
          onTap: () => _playIndex(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF00E5FF).withOpacity(0.12) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: isCurrent
                  ? Border.all(color: const Color(0xFF00E5FF), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                _roundAvatar(s),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? const Color(0xFF00E5FF) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmt(Duration(milliseconds: s.duration ?? 0)),
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.play_arrow, size: 20, color: Color(0xFF00FFAA)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roundAvatar(SongModel s) {
    final letter = (s.title.isNotEmpty) ? s.title[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF1A1230),
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF00E5FF),
          fontSize: 20,
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
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xCC2A0A6B), Color(0xCC0B3A44)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              s.artist ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60),
            ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_position), style: const TextStyle(fontSize: 11, color: Colors.white60)),
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _prev,
                      icon: const Icon(Icons.skip_previous),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00FFAA)]),
                      ),
                      child: IconButton(
                        onPressed: _togglePlay,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        color: Colors.black,
                        iconSize: 30,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _next,
                      icon: const Icon(Icons.skip_next),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              Text(_fmt(_duration), style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  Efek "hujan digital" (matrix rain) - CustomPainter
// ============================================================================
class _MatrixRain extends CustomPainter {
  final double progress;
  _MatrixRain(this.progress);

  static const _chars = ['0', '1', '<', '>', '/', '#', '\$', '%', '&', '*', '=', '+'];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    const charW = 16.0;
    final columns = (size.width / charW).floor();
    for (int c = 0; c < columns; c++) {
      final speed = 0.6 + (rng.nextDouble() * 0.7);
      final seed = rng.nextDouble();
      final head = ((progress * speed + seed) % 1.0) * (size.height * 1.2);

      for (int row = 0; row < 12; row++) {
        final y = head - row * 22.0;
        if (y < -22 || y > size.height) continue;
        final ch = _chars[rng.nextInt(_chars.length)];
        final opacity = row == 0 ? 1.0 : (1.0 - row / 14.0).clamp(0.0, 1.0);
        final color = row == 0
            ? const Color(0xFFB3FFE8)
            : Color.lerp(const Color(0xFF00FFAA), const Color(0xFF6A00FF), row / 14.0)!
                .withOpacity(opacity);
        final tp = TextPainter(
          text: TextSpan(text: ch, style: TextStyle(color: color, fontSize: 16)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c * charW + 2, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRain oldDelegate) => oldDelegate.progress != progress;
}

// ============================================================================
//  Util
// ============================================================================
String _fmt(Duration d) {
  final mm = (d.inMinutes.remainder(60)).toString().padLeft(2, '0');
  final ss = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
  return '$mm:$ss';
}
