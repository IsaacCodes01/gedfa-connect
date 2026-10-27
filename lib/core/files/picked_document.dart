import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:image_picker/image_picker.dart';

/// Letters and licences can be up to 5 MB (the storage rules agree).
const maxDocumentBytes = 5 * 1024 * 1024;

/// A file the club picked but hasn't uploaded yet. It is uploaded when
/// the registration is sent, like the logo.
class PickedDocument {
  const PickedDocument({
    required this.bytes,
    required this.name,
    required this.isPdf,
  });

  final Uint8List bytes;
  final String name;
  final bool isPdf;

  String get contentType => isPdf ? 'application/pdf' : 'image/jpeg';

  /// "240 KB" or "1.2 MB".
  String get sizeText {
    final kb = bytes.length / 1024;
    return kb < 1000
        ? '${kb.round()} KB'
        : '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

enum _Source { camera, gallery, pdf }

/// Lets the club choose a PDF (and, if [allowPhoto], a photo).
/// Returns null if they cancel or the file is too big.
Future<PickedDocument?> pickDocument(
  BuildContext context, {
  required bool allowPhoto,
}) async {
  var source = _Source.pdf;
  if (allowPhoto) {
    final chosen = await showModalBottomSheet<_Source>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A browser has no camera choice here; "photo" opens the files
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, _Source.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(sheetContext, _Source.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF'),
              onTap: () => Navigator.pop(sheetContext, _Source.pdf),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return null;
    source = chosen;
  }

  try {
    final PickedDocument picked;
    if (source == _Source.pdf) {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (file == null) return null;
      picked = PickedDocument(
        bytes: await file.readAsBytes(),
        name: file.name,
        isPdf: true,
      );
    } else {
      // Photos are shrunk on the phone, so they upload quickly
      final file = await ImagePicker().pickImage(
        source:
            source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return null;
      picked = PickedDocument(
        bytes: await file.readAsBytes(),
        name: file.name,
        isPdf: false,
      );
    }

    if (picked.bytes.length > maxDocumentBytes) {
      if (context.mounted) {
        AppToast.error(context, 'That file is over 5 MB. Choose a smaller one.');
      }
      return null;
    }
    return picked;
  } catch (_) {
    if (context.mounted) {
      AppToast.error(context, "Couldn't open that file. Try another one.");
    }
    return null;
  }
}
