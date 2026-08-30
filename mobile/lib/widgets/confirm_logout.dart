import 'package:flutter/material.dart';

import '../core/auth_service.dart';

Future<void> confirmAndLogout(BuildContext context, AuthService auth) async {
  final onayli = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Çıkış yap'),
      content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Çıkış yap')),
      ],
    ),
  );
  if (onayli == true) await auth.logout();
}
