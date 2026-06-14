import 'package:flutter/material.dart';

/// Pastki tab bardagi rejimlar. Har biri o'z sahifasiga, o'z agentiga
/// (backend `mode`) va o'z UI matnlariga ega.
enum ChatMode {
  chat,
  image,
  code,
  slides,
  video;

  /// Backendga yuboriladigan `mode` qiymati. `null` → keyword routing.
  String? get apiMode => switch (this) {
        ChatMode.image => 'image',
        ChatMode.code => 'code',
        _ => null,
      };

  /// Asosiy chatdan yuborilganda ishlatiladigan rejim ("chat" | "image" |
  /// "code"). Slayd/Video bu yerga kelmaydi (alohida "tez kunda" sahifa).
  String get sendMode => switch (this) {
        ChatMode.image => 'image',
        ChatMode.code => 'code',
        _ => 'chat',
      };

  /// Tab yorlig'i (pastki bar).
  String get label => switch (this) {
        ChatMode.chat => 'Chat',
        ChatMode.image => 'Rasm',
        ChatMode.code => 'Kod',
        ChatMode.slides => 'Slayd',
        ChatMode.video => 'Video',
      };

  IconData get icon => switch (this) {
        ChatMode.chat => Icons.chat_bubble_outline,
        ChatMode.image => Icons.image_outlined,
        ChatMode.code => Icons.code,
        ChatMode.slides => Icons.slideshow_outlined,
        ChatMode.video => Icons.movie_creation_outlined,
      };

  IconData get activeIcon => switch (this) {
        ChatMode.chat => Icons.chat_bubble,
        ChatMode.image => Icons.image,
        ChatMode.code => Icons.code,
        ChatMode.slides => Icons.slideshow,
        ChatMode.video => Icons.movie_creation,
      };

  /// "Tez kunda" placeholder tab (Slayd/Video).
  bool get isComingSoon => this == ChatMode.slides || this == ChatMode.video;

  String get appBarTitle => switch (this) {
        ChatMode.image => 'Rasm yaratish',
        ChatMode.code => 'Kod — Coder Pro',
        _ => label,
      };

  String get emptyTitle => switch (this) {
        ChatMode.image => 'Qanday rasm yarataylik?',
        ChatMode.code => 'Qanday kod kerak?',
        _ => 'Suhbatni boshlang',
      };

  String get inputHint => switch (this) {
        ChatMode.image => 'Tasvir tavsifini yozing...',
        ChatMode.code => 'Vazifa yoki kodni yozing...',
        _ => 'Xabar yozing...',
      };

  /// Bo'sh holatdagi taklif chiplari (label bosilganda yuboriladi).
  List<(String, IconData)> get suggestions => switch (this) {
        ChatMode.image => const [
            ('Tog\' ustida quyosh chiqishi', Icons.landscape_outlined),
            ('Futuristik shahar, neon', Icons.location_city_outlined),
            ('Minimalist logo — tulki', Icons.pets_outlined),
            ('Suvosti dunyosi, akvarel', Icons.water_outlined),
          ],
        ChatMode.code => const [
            ('Python\'da REST API yoz', Icons.api_outlined),
            ('Bubble sort algoritmi', Icons.sort_outlined),
            ('SQL JOIN tushuntir', Icons.storage_outlined),
            ('Flutter widget debug qil', Icons.bug_report_outlined),
          ],
        _ => const [],
      };
}
