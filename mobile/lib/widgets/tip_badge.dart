import 'package:flutter/material.dart';

import '../models/work_order.dart';

/// İş emrinin arıza mı bakım mı kontrol mü olduğunu StatusBadge'e benzer
/// renkli bir rozetle açıkça gösterir.
class TipBadge extends StatelessWidget {
  const TipBadge({super.key, required this.tip});

  final String tip;

  Color get _color {
    switch (tip) {
      case 'ariza':
        return Colors.red;
      case 'bakim':
        return Colors.indigo;
      case 'kontrol':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        WorkOrder.tipLabels[tip] ?? tip,
        style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
