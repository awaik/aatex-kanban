import "package:flutter/material.dart";

class Log {
  static const enableLog = true; // Changed from false to true to enable logging

  static void trace(String? message) {
    if (enableLog) {
      debugPrint(
        "${_now()} AATexBoard: 🔎 TRACE - $message",
      );
    }
  }

  static void debug(String? message) {
    if (enableLog) {
      debugPrint(
        "${_now()} AATexBoard: 🐛 DEBUG - $message",
      );
    }
  }

  static void info(String? message) {
    if (enableLog) {
      debugPrint(
        "${_now()} AATexBoard: ℹ️ INFO - $message",
      );
    }
  }

  static void warn(String? message) {
    if (enableLog) {
      debugPrint(
        "${_now()} AATexBoard: ⚠️ WARN - $message",
      );
    }
  }

  static void error(String? message) {
    debugPrint(
      "${_now()} AATexBoard: ❌ ERROR - $message",
    );
  }

  static String _now() {
    final dateTime = DateTime.now();
    return "${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} "
        "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}";
  }

  static String _twoDigits(int n) {
    if (n >= 10) {
      return "$n";
    }
    return "0$n";
  }
}
