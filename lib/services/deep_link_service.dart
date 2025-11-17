import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../views/task_view.dart';

class DeepLinkService {
  final WidgetRef ref;
  StreamSubscription<Uri>? sub;
  final AppLinks appLinks = AppLinks();

  DeepLinkService({required this.ref});

  Future<void> init() async {
    sub = appLinks.uriLinkStream.listen((uri) => handleUri(uri), onError: (e) {});
  }
 
  void handleUri(Uri uri) {
    if (uri.scheme == 'mytodo' && uri.host == 'task') {
      final taskId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;

      if (taskId != null && taskId.isNotEmpty) {
        Navigator.of(navigatorKey.currentContext!).push(MaterialPageRoute(builder: (_) => TaskView(taskId: taskId)));
      }
    }
  }

  void dispose() => sub?.cancel();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
