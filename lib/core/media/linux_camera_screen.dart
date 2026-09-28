import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_spacing.dart';
import '../logging/app_logger.dart';

/// Caméra sous Linux (image_picker ne gère pas la webcam sur desktop) :
/// aperçu en direct lu depuis `ffmpeg` ou GStreamer (flux MJPEG), puis
/// capture de l'image affichée. Renvoie le chemin du fichier JPEG.
class LinuxCameraScreen extends StatefulWidget {
  const LinuxCameraScreen({super.key});

  static Future<String?> open(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const LinuxCameraScreen(),
        ),
      );

  @override
  State<LinuxCameraScreen> createState() => _LinuxCameraScreenState();
}

class _LinuxCameraScreenState extends State<LinuxCameraScreen> {
  Process? _process;
  StreamSubscription<List<int>>? _output;
  final _buffer = BytesBuilder(copy: false);
  Uint8List? _frame;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_output?.cancel());
    _process?.kill();
    super.dispose();
  }

  Future<void> _start() async {
    final device = _findDevice();
    if (device == null) {
      setState(() => _error = 'Aucune caméra détectée sur cet ordinateur.');
      return;
    }
    final command = await _captureCommand(device);
    if (command == null) {
      setState(
        () => _error =
            'Pour utiliser la webcam, installez ffmpeg ou GStreamer '
            '(gst-plugins-good).',
      );
      return;
    }
    try {
      final process = await Process.start(command.$1, command.$2);
      _process = process;
      _output = process.stdout.listen(_onBytes);
      unawaited(process.stderr.drain<void>());
      unawaited(
        process.exitCode.then((code) {
          if (mounted && _frame == null && code != 0) {
            setState(
              () => _error =
                  'Impossible d’ouvrir la caméra (déjà utilisée ou accès refusé).',
            );
          }
        }),
      );
    } on ProcessException catch (e) {
      AppLogger.warning('Caméra', 'Démarrage impossible', e);
      if (mounted) setState(() => _error = "Impossible d'ouvrir la caméra.");
    }
  }

  /// Premier périphérique vidéo (`/dev/video0`, `/dev/video1`…).
  static String? _findDevice() {
    for (var i = 0; i < 10; i++) {
      final path = '/dev/video$i';
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  /// `ffmpeg` si présent, sinon `gst-launch-1.0`.
  static Future<(String, List<String>)?> _captureCommand(String device) async {
    if (await _hasTool('ffmpeg')) {
      return (
        'ffmpeg',
        [
          '-hide_banner', '-loglevel', 'error', //
          '-f', 'v4l2', '-i', device,
          '-f', 'image2pipe', '-vcodec', 'mjpeg', '-q:v', '4', '-',
        ],
      );
    }
    if (await _hasTool('gst-launch-1.0')) {
      return (
        'gst-launch-1.0',
        [
          '-q', 'v4l2src', 'device=$device', '!', 'videoconvert', //
          '!', 'jpegenc', 'quality=85', '!', 'fdsink', 'fd=1',
        ],
      );
    }
    return null;
  }

  static Future<bool> _hasTool(String name) async {
    try {
      final result = await Process.run('which', [name]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// Découpe le flux en images JPEG (marqueurs FFD8 … FFD9).
  void _onBytes(List<int> chunk) {
    _buffer.add(chunk);
    final data = _buffer.toBytes();
    Uint8List? latest;
    var consumed = 0;
    var start = _indexOf(data, 0xD8, 0);
    while (start >= 0) {
      final end = _indexOf(data, 0xD9, start + 2);
      if (end < 0) break;
      latest = Uint8List.sublistView(data, start, end + 2);
      consumed = end + 2;
      start = _indexOf(data, 0xD8, consumed);
    }
    _buffer.clear();
    if (consumed < data.length) {
      _buffer.add(Uint8List.sublistView(data, consumed));
    }
    final frame = latest;
    if (frame != null && mounted) {
      setState(() => _frame = Uint8List.fromList(frame));
    }
  }

  /// Position du marqueur `0xFF [marker]` à partir de [from].
  static int _indexOf(Uint8List data, int marker, int from) {
    for (var i = from; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == marker) return i;
    }
    return -1;
  }

  Future<void> _capture() async {
    final frame = _frame;
    if (frame == null || _saving) return;
    setState(() => _saving = true);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/parkauto_camera_'
      '${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(frame, flush: true);
    if (mounted) Navigator.of(context).pop(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    final error = _error;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Appareil photo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: error != null
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : frame == null
                  ? const CircularProgressIndicator(color: Colors.white54)
                  : Image.memory(
                      frame,
                      gaplessPlayback: true,
                      fit: BoxFit.contain,
                      semanticLabel: 'Aperçu de la caméra',
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Semantics(
                button: true,
                label: 'Prendre la photo',
                child: GestureDetector(
                  onTap: frame == null ? null : _capture,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: frame == null ? 0.4 : 1,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _saving
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
