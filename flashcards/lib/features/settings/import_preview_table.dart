import 'package:flutter/material.dart';

import '../../core/constants/languages.dart';
import 'import_service.dart';

/// Two-column preview of parsed CSV rows, with each column labelled by the
/// language it will be stored as, so a wrong column order in the file is
/// obvious before anything is imported.
class ImportPreviewTable extends StatelessWidget {
  const ImportPreviewTable({
    super.key,
    required this.rows,
    required this.languages,
  });

  final List<ParsedCsvCard> rows;

  /// (source, target) language codes of the destination deck, or null while
  /// no destination has been chosen yet.
  final (String, String)? languages;

  static String columnLabel(String role, String? code) => code == null
      ? role
      : '$role · ${languageFlag(code)} ${languageName(code)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    columnLabel('SOURCE', languages?.$1),
                    style: headerStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    columnLabel('TARGET', languages?.$2),
                    style: headerStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 18),
              ],
            ),
            const Divider(height: 12),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.sourceText,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.targetText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 18,
                      child: r.notes != null
                          ? const Icon(Icons.note_outlined, size: 16)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
