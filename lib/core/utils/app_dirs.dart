import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:streak/core/database/data_location.dart';

const appDataFolder = 'Streak';

bool get isMobile => Platform.isAndroid || Platform.isIOS;

bool get hasAppIcons => isMobile;

bool get hasHomeWidgets =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

bool get hasBiometricLock => !Platform.isLinux;

Future<Directory>? _dataDir;

String _dataPath = '';

String get dataPath => _dataPath;

Future<Directory> appDataDir() => _dataDir ??= _resolveDataDir().then((dir) {
      _dataPath = dir.path;
      return dir;
    });

@visibleForTesting
void forgetAppDataDir() => _dataDir = null;

Future<Directory> _resolveDataDir() async {
  const wait = Duration(seconds: 15);
  if (isMobile) return getApplicationDocumentsDirectory().timeout(wait);

  final support = await getApplicationSupportDirectory().timeout(wait);
  final chosen = await DataLocation.resolve(support);
  if (chosen != null) return chosen;
  if (Platform.isLinux) return support;

  final fallback = File('${support.path}/.documents-unavailable');
  final used = File('${support.path}/.documents-used');
  if (fallback.existsSync()) return support;

  final documents = await _documentsFolder(wait);
  if (documents != null) {
    if (!used.existsSync()) used.createSync(recursive: true);
    return documents;
  }
  if (used.existsSync()) {
    throw FileSystemException(
      'Your Streak data lives in Documents\\$appDataFolder, which Windows is not letting the app open right now',
    );
  }
  fallback.createSync(recursive: true);
  return support;
}

Future<Directory?> _documentsFolder(Duration wait) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final root = await getApplicationDocumentsDirectory().timeout(wait);
      final dir = Directory('${root.path}/$appDataFolder');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    } catch (error) {
      debugPrint('Documents folder unavailable: $error');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }
  return null;
}
