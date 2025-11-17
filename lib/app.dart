import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'views/home_view.dart';
import 'services/deep_link_service.dart';
import 'viewmodels/auth_vm.dart';
import 'config/theme.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late DeepLinkService deepLinkService;

  @override
  void initState() {
    super.initState();
    deepLinkService = DeepLinkService(ref: ref);
    deepLinkService.init();
    Future.microtask(() => ref.read(authViewModelProvider).ensureSignedIn());
  }

  @override
  void dispose() {
    deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyTodo',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.system,
      home: const HomeView(),
      navigatorKey: navigatorKey,
    );
  }
}
