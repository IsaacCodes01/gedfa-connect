import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/widgets/dashed_border.dart';

/// A file slot: a PDF or IMG badge, a title, a second line and a button.
/// Dashed while empty, solid once a file is there (boards R1 and R7).
class FileUploadRow extends StatelessWidget {
  const FileUploadRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    required this.hasFile,
    this.isPdf = true,
    this.onRemove,
    this.showError = false,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool hasFile;

  /// The badge: red "PDF" or blue "IMG".
  final bool isPdf;

  /// Shown as a small × when an optional file can be taken away.
  final VoidCallback? onRemove;

  /// Red outline and red second line, e.g. the letter is missing.
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final redBg = isDark ? const Color(0xFF4A1820) : const Color(0xFFFDE7EA);
    final chipBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA);
    final chipInk = isDark ? const Color(0xFFCFE4FB) : const Color(0xFF0B3F7A);
    final link = isDark ? const Color(0xFF7DBBFA) : scheme.primary;
    final lineColor = showError ? scheme.error : scheme.outline;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPdf ? redBg : chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isPdf ? 'PDF' : 'IMG',
              style: TextStyle(
                color: isPdf ? scheme.error : chipInk,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: showError ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const StadiumBorder(),
              side: BorderSide(color: scheme.outline),
              foregroundColor: link,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            child: Text(buttonLabel),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove $title',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    final background = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: hasFile ? Border.all(color: lineColor, width: 1.5) : null,
      ),
      child: content,
    );

    return hasFile
        ? background
        : DashedBorder(color: lineColor, child: background);
  }
}
