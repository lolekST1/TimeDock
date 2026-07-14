import 'package:flutter/material.dart';

/// Shared palette for workspace seeds and project colors, and a reusable
/// picker dialog. ARGB ints (as stored on entities).
const kEntityColors = <int>[
  0xFF1565C0, 0xFF00695C, 0xFF2E7D32, 0xFF6A1B9A,
  0xFFAD1457, 0xFFC62828, 0xFFEF6C00, 0xFFF9A825,
  0xFF4E342E, 0xFF283593, 0xFF00838F, 0xFF546E7A,
];

/// Shows a grid of swatches and returns the chosen ARGB int, or null.
Future<int?> pickEntityColor(BuildContext context, int current) {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Wybierz kolor'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in kEntityColors)
            InkWell(
              onTap: () => Navigator.of(context).pop(c),
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                backgroundColor: Color(c),
                child: c == current
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    ),
  );
}
