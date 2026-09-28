import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/media/camera_capture.dart';
import '../../../core/media/photo_picker.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../domain/local_attachment.dart';

/// Brouillons de messages, par conversation (mémoire).
final chatDraftsProvider = NotifierProvider<ChatDrafts, Map<int, String>>(
  ChatDrafts.new,
);

class ChatDrafts extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() {
    ref.watch(currentDriverIdProvider);
    return const {};
  }

  void save(int idConversation, String text) {
    if ((state[idConversation] ?? '') == text) return;
    state = {...state, idConversation: text};
  }
}

/// Zone de saisie : texte, pièces jointes (photo, galerie, fichier).
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.idConversation,
    required this.onSend,
  });

  final int idConversation;
  final void Function(String text, List<LocalAttachment> files) onSend;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  static const _maxFiles = 5;

  late final ChatDrafts _drafts = ref.read(chatDraftsProvider.notifier);
  late final TextEditingController _text = TextEditingController(
    text: ref.read(chatDraftsProvider)[widget.idConversation],
  )..addListener(_onTextChanged);
  List<LocalAttachment> _files = const [];

  bool get _canSend => _text.text.trim().isNotEmpty || _files.isNotEmpty;

  void _onTextChanged() {
    _drafts.save(widget.idConversation, _text.text);
    setState(() {});
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    if (!_canSend) return;
    widget.onSend(_text.text, _files);
    _text.clear();
    setState(() => _files = const []);
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (CameraCapture.isAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.of(sheet).pop('camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir des photos'),
              onTap: () => Navigator.of(sheet).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Joindre un document (PDF, image)'),
              onTap: () => Navigator.of(sheet).pop('file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final remaining = _maxFiles - _files.length;
    final picked = switch (choice) {
      'camera' => await _pickPhotos(ImageSource.camera, remaining),
      'gallery' => await _pickPhotos(ImageSource.gallery, remaining),
      _ => await _pickDocuments(remaining),
    };
    if (!mounted || picked.isEmpty) return;
    setState(() => _files = [..._files, ...picked.take(remaining)]);
  }

  Future<List<LocalAttachment>> _pickPhotos(
    ImageSource source,
    int remaining,
  ) async {
    final result = source == ImageSource.camera
        ? await CameraCapture.capture(context)
        : await PhotoPicker().pick(source: source, remaining: remaining);
    if (result.error case final message? when mounted) {
      showInfoMessage(context, message);
    }
    return [
      for (final p in result.photos)
        LocalAttachment.fromPath(p.path, size: p.size),
    ];
  }

  Future<List<LocalAttachment>> _pickDocuments(int remaining) async {
    try {
      // Types acceptés par le backend : JPEG, PNG, WEBP ou PDF.
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      final result = <LocalAttachment>[];
      for (final file in files.take(remaining)) {
        final path = file.path;
        if (path == null) continue;
        result.add(
          LocalAttachment(
            path: path,
            name: file.name,
            size: await File(path).length(),
          ),
        );
      }
      return result;
    } on Exception {
      if (mounted) {
        showInfoMessage(context, 'Impossible de joindre ce fichier.');
      }
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_files.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    itemCount: _files.length,
                    separatorBuilder: (_, _) => AppSpacing.gapSm,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final size = file.size;
                      return InputChip(
                        avatar: Icon(
                          file.isImage
                              ? Icons.image_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 18,
                        ),
                        label: Text(
                          size == null
                              ? file.name
                              : '${file.name} · ${AppFormat.fileSize(size)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () => setState(
                          () => _files = [..._files]..removeAt(index),
                        ),
                        deleteButtonTooltipMessage: 'Retirer',
                      );
                    },
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Joindre un fichier',
                    onPressed: _files.length >= _maxFiles ? null : _attach,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Écrire un message…',
                        isDense: true,
                        fillColor: scheme.surfaceContainer,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapXs,
                  AnimatedScale(
                    scale: _canSend ? 1 : 0.9,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton.filled(
                      tooltip: 'Envoyer',
                      onPressed: _canSend ? _send : null,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
