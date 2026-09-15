import 'package:flutter/material.dart';

enum DotState { ok, warn, missing }

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.state});

  final DotState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      DotState.ok => const Color(0xFF4ADE80),
      DotState.warn => const Color(0xFFFBBF24),
      DotState.missing => const Color(0xFFEF4444),
    };

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
