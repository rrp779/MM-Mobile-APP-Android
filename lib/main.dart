import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

/// ✅ GLOBAL NAVIGATOR KEY
final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

/// ✅ BACKGROUND HANDLER
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();   // 🔥 ADD THIS

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp();              // 🔥 ADD THIS

  await Hive.initFlutter();
  Hive.registerAdapter(AppNotificationAdapter());

  await Future.wait([
    Hive.openBox('products'),
    Hive.openBox('sections'),
    Hive.openBox<AppNotification>('notifications'),
  ]);

  final authProvider = AuthProvider();

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

      try {
        final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

        if (initialMessage != null) {
          handleNotificationNavigation(initialMessage);
        }
      } catch (e) {
        print("Notification error: $e");
      }
    });
  }

  void setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    String? token = await messaging.getToken();
    print("🔥 FCM Token: $token");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final provider =
        Provider.of<NotificationProvider>(context, listen: false);
        provider.addNotification(
          AppNotification(
            title: message.notification?.title ?? "No Title",
            body: message.notification?.body ?? "No Body",
            time: DateTime.now(),
            type: message.data['type'],
            handle: message.data['handle'],
            titleArg: message.data['title'],
          ),
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationNavigation(message);
    });
  }
  void handleNotificationNavigation(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) {
      navigatorKey.currentState?.pushNamed('/notifications');
      return;
    }
    final type = data['type'];
    if (type == 'product') {
      navigatorKey.currentState?.pushNamed(
        '/product',
        arguments: data['handle'],
      );
    } else if (type == 'collection') {
      navigatorKey.currentState?.pushNamed(
        '/collection',
        arguments: {
          "collectionId": data['handle'],
          "handle": data['handle'],
          "title": data['title'] ?? "Collection",
        },
      );
    } else if (type == 'cart') {
      navigatorKey.currentState?.pushNamed('/cart');
    } else {
      navigatorKey.currentState?.pushNamed('/notifications');
    }
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
        '/notifications': (context) => const NotificationScreen(),
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
