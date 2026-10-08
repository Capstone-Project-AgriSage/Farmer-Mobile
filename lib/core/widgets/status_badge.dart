import 'package:flutter/material.dart';

import '../labels/status_label.dart';

/// A small coloured pill with a status in words.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final StatusLabel status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: status.tone.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.tone.foreground.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.tone.foreground),
      ),
    );
  }
}
