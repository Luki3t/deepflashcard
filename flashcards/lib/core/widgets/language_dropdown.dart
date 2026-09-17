import 'package:flutter/material.dart';

import '../constants/languages.dart';

/// Dropdown for picking one side of a source/target language pair.
///
/// [disabledCode] is the language held by the other side of the pair: it stays
/// visible but greyed out and cannot be selected, so a deck can never end up
/// with the same source and target language.
class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.disabledCode,
  });

  final String label;
  final String value;
  final String? disabledCode;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      // Lets long names ("🇵🇹 Portuguese", large font scales) ellipsize
      // instead of running under the dropdown arrow.
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: supportedLanguages.map((l) {
        final disabled = l.code == disabledCode;
        return DropdownMenuItem(
          value: l.code,
          enabled: !disabled,
          child: Text(
            '${l.flag} ${l.name}',
            overflow: TextOverflow.ellipsis,
            style: disabled
                ? TextStyle(color: Theme.of(context).disabledColor)
                : null,
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null && v != disabledCode) onChanged(v);
      },
    );
  }
}
