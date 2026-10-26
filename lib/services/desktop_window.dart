import 'dart:io';

import 'package:flutter/services.dart';

class DesktopWindow {
  const DesktopWindow._();

  static const _channel = MethodChannel('streak/window');

  static Future<void> Function()? _onCloseRequested;

  static Future<void> setFullscreen(bool on) async {
    if (!Platform.isWindows && !Platform.isLinux) return;
    try {
      await _channel.invokeMethod<void>('fullscreen', on);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> installCloseHandler(
    Future<void> Function() onCloseRequested,
  ) async {
    if (!Platform.isWindows) return;
    _onCloseRequested = onCloseRequested;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'closeRequested') return;
      try {
        await _onCloseRequested?.call();
      } catch (_) {
        await cancelClose();
      }
    });
    try {
      await _channel.invokeMethod<void>('enableCloseGuard');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> confirmClose() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('close');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> cancelClose() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('cancelClose');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
