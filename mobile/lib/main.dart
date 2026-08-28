import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'core/navigation.dart';
import 'screens/employer_home_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web'de Firebase.initializeApp() ayrı bir FirebaseOptions (web config) ister ve
  // push kapsamımız Android/iOS ile sınırlı — bu yüzden web'de tamamen atlanır.
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const AbbKontrolApp());
}

class AbbKontrolApp extends StatelessWidget {
  const AbbKontrolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        // `previous` korunur: aksi halde her AuthService bildiriminde (ör. token yenileme)
        // yeni bir örnek oluşturulur ve LocationService/NotificationService'in çalışan
        // Timer'ları sızıntı olarak birikir.
        ProxyProvider<AuthService, ApiClient>(update: (_, auth, previous) => previous ?? ApiClient(auth)),
        ProxyProvider<ApiClient, LocationService>(update: (_, api, previous) => previous ?? LocationService(api)),
        ChangeNotifierProxyProvider<ApiClient, NotificationService>(
          create: (context) => NotificationService(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? NotificationService(api),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'ABB Kontrol',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2563EB), useMaterial3: true),
        home: const _RootGate(),
      ),
    );
  }
}

/// Giriş durumuna göre login/ana ekran arasında yönlendirir; girişten sonra
/// bildirim polling'i (her iki taraf), alt yüklenici için arka plan konum
/// gönderimi ve (Android/iOS'ta) push bildirim kaydı başlatılır; uygulama
/// arka plandan öne dönünce bildirimler tazelenir.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> with WidgetsBindingObserver {
  bool _servicesStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _servicesStarted) {
      context.read<NotificationService>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isLoggedIn) {
      _servicesStarted = false;
      return const LoginScreen();
    }

    if (!_servicesStarted) {
      _servicesStarted = true;
      final isAltYuklenici = auth.currentUser!.isAltYuklenici;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notificationService = context.read<NotificationService>();
        notificationService.start();
        if (isAltYuklenici) {
          context.read<LocationService>().start();
        }
        if (!kIsWeb) {
          PushService(context.read<ApiClient>(), onForegroundMessage: notificationService.refresh).init();
        }
      });
    }

    if (!auth.currentUser!.isAltYuklenici) {
      return const EmployerHomeScreen();
    }

    return const HomeScreen();
  }
}
