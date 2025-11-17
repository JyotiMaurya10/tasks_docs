import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> shareTaskLink(String taskId) async {
    final link = 'mytodo://task/$taskId';
    await Share.share('Open this task: $link');
  }
}
