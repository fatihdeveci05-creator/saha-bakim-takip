import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import 'work_order_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _tipIcons = {
    'yeni_ariza': Icons.report_problem_outlined,
    'atama': Icons.assignment_outlined,
    'onay': Icons.check_circle_outline,
    'red': Icons.cancel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: RefreshIndicator(
        onRefresh: service.refresh,
        child: service.items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Bildirim yok', style: TextStyle(color: Colors.grey))),
                ],
              )
            : ListView.separated(
                itemCount: service.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = service.items[index];
                  return ListTile(
                    leading: Icon(_tipIcons[n.tip] ?? Icons.notifications_outlined, color: n.okundu ? Colors.grey : Theme.of(context).colorScheme.primary),
                    title: Text(n.mesaj, style: TextStyle(fontWeight: n.okundu ? FontWeight.normal : FontWeight.w600)),
                    subtitle: Text(fmt.format(n.createdAt.toLocal())),
                    trailing: n.okundu ? null : const Icon(Icons.circle, size: 8, color: Colors.blue),
                    onTap: () async {
                      if (!n.okundu) await service.markRead(n.id);
                      if (n.relatedWorkOrderId != null && context.mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: n.relatedWorkOrderId!)),
                        );
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
        if (service.unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${service.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
