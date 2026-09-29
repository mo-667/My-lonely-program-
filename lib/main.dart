import 'shadow_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:cryptography/cryptography.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

part 'services/app_services.dart';
part 'services/profile_services.dart';
part 'screens/app_shell.dart';
part 'screens/chat_list_screen.dart';
part 'screens/secret_rooms_screen.dart';
part 'screens/settings_screens.dart';
part 'screens/chat_screen.dart';
part 'screens/account_and_theme_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (secureLocalDemoMode) {
    firebaseReady = false;
    await loadAppLockSettings();
  } else {
    await initializeFirebase();
  }
  runApp(const ShadowChatApp());
}
