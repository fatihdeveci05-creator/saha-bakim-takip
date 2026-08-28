import 'package:flutter/material.dart';

import '../models/work_order.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.durum});

  final String durum;

  Color get _color {
    switch (durum) {
      case 'bekliyor':
      case 'tamamlandi':
      case 'onay_bekliyor':
        return Colors.orange;
      case 'devam_edecek':
        return Colors.blue;
      case 'onaylandi':
        return Colors.green;
      case 'reddedildi':
        return Colors.red;
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
        WorkOrder.durumLabels[durum] ?? durum,
        style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
