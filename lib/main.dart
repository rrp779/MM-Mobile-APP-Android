import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'config/shopify_client.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/login_screen.dart';
import 'screens/cart_page.dart';
import 'screens/brands_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/collection_products_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'customer/customer_orders.dart';
import 'services/notification_service.dart';
import 'services/ota_service.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/product_provider.dart';
import '../providers/home_provider.dart';
import 'providers/collection_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/notification_provider.dart';

// Models
import 'models/notification_model.dart';
import 'customer/customer_model.dart';

class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

/// ✅ GLOBAL NAVIGATOR KEY
final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

/// ✅ BACKGROUND HANDLER
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = AppHttpOverrides();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await dotenv.load(fileName: ".env");

  await Hive.initFlutter();
  Hive.registerAdapter(AppNotificationAdapter());

  await Future.wait([
    Hive.openBox('products'),
    Hive.openBox('sections'),
    Hive.openBox<AppNotification>('notifications'),
  ]);

  final authProvider = AuthProvider();

  // 🚀 Shorebird Over-The-Air (OTA) background update checker
  OtaService().checkForUpdates();

  runApp(
    GraphQLProvider(
      client: ValueNotifier(getShopifyClient()),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => HomeProvider()),
          ChangeNotifierProvider(create: (_) => WishlistProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => CollectionProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => CustomerModel()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

void handleNotificationNavigation(RemoteMessage message) {
  final data = message.data;
  if (data.isEmpty) {
    navigatorKey.currentState?.pushNamed('/notifications');
    return;
  }

  final type = data['type']?.toString().toLowerCase();
  final status = data['status']?.toString().toLowerCase();

  // 1. Payment Failed / Cart Abandoned -> Go to Cart
  if (status == 'payment_failed' || type == 'cart') {
    navigatorKey.currentState?.pushNamed('/cart');
    return;
  }

  // 2. Product deep-link
  if (type == 'product' && data['handle'] != null && data['handle'].toString().isNotEmpty) {
    navigatorKey.currentState?.pushNamed(
      '/product',
      arguments: data['handle'],
    );
    return;
  }

  // 3. Collection / Flash Sale / Promotional deep-link
  if (type == 'collection' ||
      type == 'flash_sale' ||
      type == 'promotional' ||
      status == 'flash_sale' ||
      status == 'promotional') {
    final handle = data['handle']?.toString() ?? "";
    if (handle.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(
        '/collection',
        arguments: {
          "collectionId": handle,
          "handle": handle,
          "title": data['title'] ?? (status == 'flash_sale' ? "⚡ Flash Sale" : "Exclusive Offers"),
        },
      );
      return;
    }
  }

  // 4. Order Updates -> Go to specific Order
  if (type == 'order' || data['order_number'] != null || data['order_id'] != null) {
    String? orderNumber = data['order_number']?.toString();
    if (orderNumber == null || orderNumber.isEmpty) {
      final title = data['title']?.toString() ?? message.notification?.title ?? "";
      final body = data['body']?.toString() ?? message.notification?.body ?? "";
      final match = RegExp(r'#(\d+)').firstMatch("$title $body");
      if (match != null) {
        orderNumber = "#${match.group(1)}";
      }
    }

    navigatorKey.currentState?.pushNamed(
      '/orders',
      arguments: {
        "orderNumber": orderNumber,
        "orderId": data['order_id'] ?? data['handle'],
      },
    );
    return;
  }

  navigatorKey.currentState?.pushNamed('/notifications');
}

void saveNotificationToProvider(RemoteMessage message) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  final notifTitle = message.notification?.title ?? message.data['title'] ?? "Order Update";
  final notifBody = message.notification?.body ?? message.data['body'] ?? "New notification received";
  final notifImage = message.notification?.android?.imageUrl ??
      message.data['imageUrl'] ??
      message.data['image_url'];

  try {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    provider.addNotification(
      AppNotification(
        title: notifTitle,
        body: notifBody,
        time: DateTime.now(),
        type: message.data['type'] ?? message.data['status'],
        handle: message.data['handle'] ?? message.data['order_id'],
        titleArg: message.data['title'] ?? message.data['order_number'],
        imageUrl: notifImage,
      ),
    );
  } catch (e) {
    debugPrint("[main] Error saving notification: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

    setupFCM();

    /// 🔥 SAFE async after UI loads
    Future.microtask(() async {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      try {
        await auth.restoreSession();
      } catch (e) {
        print("Auth error: $e");
      }
    });
  }

  void setupFCM() async {
    await NotificationService().initialize();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      saveNotificationToProvider(message);

      final context = navigatorKey.currentContext;
      final notifTitle = message.notification?.title ?? message.data['title'] ?? "Order Update";
      final notifBody = message.notification?.body ?? message.data['body'] ?? "New notification received";

      if (context != null) {
        // Show in-app banner for instant visual feedback when app is in foreground
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notifTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        notifBody,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEA0180),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: "VIEW",
              textColor: Colors.white,
              onPressed: () {
                handleNotificationNavigation(message);
              },
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      saveNotificationToProvider(message);
      handleNotificationNavigation(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      /// 🔥 FIX: Always start from splash safely
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/category': (context) => const CategoriesScreen(),
        '/brand': (context) => const BrandsScreen(),
        '/cart': (context) => const CartPage(),
        '/login': (context) => const CustomerLoginRegister(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/orders': (context) => const CustomerOrders(),
        '/product': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          return ProductDetailScreen(productId: args as String);
        },
        '/collection': (context) {
          final data =
          ModalRoute.of(context)!.settings.arguments as Map;
          return CollectionProductsScreen(
            collectionId: data['collectionId'],
            collectionTitle: data['title'],
            collectionHandle: data['handle'],
          );
        },
      },
    );
  }
}
