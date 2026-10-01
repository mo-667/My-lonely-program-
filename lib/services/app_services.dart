part of '../main.dart';

// متغير عام يتحكم في حالة حركة الحوت في كل التطبيق
final ValueNotifier<bool> whaleMotionNotifier = ValueNotifier<bool>(true);

// متغير عام يتحكم في تفعيل أو إيقاف صوت الحوت من الإعدادات
final ValueNotifier<bool> whaleSoundNotifier = ValueNotifier<bool>(true);
final ValueNotifier<bool> messageSoundNotifier = ValueNotifier<bool>(true);

// متغير عام يتحكم في التشفير التلقائي للرسائل
final ValueNotifier<bool> autoEncryptNotifier = ValueNotifier<bool>(false);

final ValueNotifier<String?> secretRoomCodeHashNotifier =
    ValueNotifier<String?>(null);

final ValueNotifier<String?> roomOwnerKeyHashNotifier = ValueNotifier<String?>(
  null,
);

const bool secureLocalDemoMode = true;
final ValueNotifier<Map<String, String>> chatPasswordsNotifier =
    ValueNotifier<Map<String, String>>({});
const int maxSecretRoomMembers = 100;
final ValueNotifier<List<String>> secretRoomMembersNotifier =
    ValueNotifier<List<String>>([]);

bool canRemoveSecretMember({
  required bool isGroup,
  required bool ownerVerified,
  required bool isOwnerUser,
}) {
  if (isGroup) return true;
  return ownerVerified && isOwnerUser;
}

bool isSecretRoomAtCapacity(int memberCount) {
  return memberCount >= maxSecretRoomMembers;
}

Future<int> countRoomMembers(String roomId) async {
  if (!firebaseReady) return 0;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('members')
        .limit(maxSecretRoomMembers + 1)
        .get();
    return snapshot.docs.length;
  } catch (error) {
    debugPrint('Room member count failed for $roomId: $error');
    return 0;
  }
}

Future<void> refreshSecretRoomMemberNotifier() async {
  final roomId = 'secret_room';
  if (!firebaseReady) return;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('members')
        .get();
    secretRoomMembersNotifier.value =
        snapshot.docs.map((doc) => doc.id).toList();
  } catch (error) {
    debugPrint('Secret room member refresh failed: $error');
  }
}

final ValueNotifier<bool> englishLanguageNotifier = ValueNotifier<bool>(false);
final ValueNotifier<bool> appLockEnabledNotifier = ValueNotifier<bool>(false);
final ValueNotifier<String?> appLockPasswordNotifier = ValueNotifier<String?>(
  null,
);
final ValueNotifier<bool> ghostModeNotifier = ValueNotifier<bool>(true);
final ValueNotifier<bool> autoDeleteMessagesNotifier = ValueNotifier<bool>(
  true,
);
final ValueNotifier<bool> secretGroupLockEnabledNotifier =
    ValueNotifier<bool>(false);
final ValueNotifier<String?> secretGroupPasswordHashNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<int> clearHistoryNotifier = ValueNotifier<int>(0);
final ValueNotifier<bool> globalDarkModeNotifier = ValueNotifier<bool>(true);
final ValueNotifier<Uint8List?> userProfileImageBytesNotifier =
    ValueNotifier<Uint8List?>(null);
const String appLockEnabledKey = 'app_lock_enabled';
const String appLockPasswordHashKey = 'app_lock_password_hash';
const String darkModeKey = 'dark_mode_enabled';
const String updateNoticeVersionKey = 'update_notice_version';
const String updateNoticeCountKey = 'update_notice_count';
bool firebaseReady = false;
String firebaseFailureMessage = '';
String? currentPublicUserId;
final ValueNotifier<String?> publicUserIdNotifier = ValueNotifier<String?>(null);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
StreamSubscription<RemoteMessage>? pushMessageSubscription;

const String shadowNotificationChannelId = 'shadow_whisper_signal';

Future<void> initializeLocalNotifications() async {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) return;

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);

  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      shadowNotificationChannelId,
      'Shadow Whisper',
      description: 'إشعارات رسائل Shadow Chat بصوت غامض',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('shadow_whisper'),
    ),
  );
  await androidPlugin?.requestNotificationsPermission();
}

Future<void> showChatNotification({
  required String chatTitle,
  required String message,
}) async {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) return;

  const title = 'Shadow Chat';
  final body = 'رسالة جديدة في $chatTitle: $message';

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    shadowNotificationChannelId,
    'Shadow Whisper',
    channelDescription: 'إشعارات جذابة وغامضة داخل Shadow Chat',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('shadow_whisper'),
    enableVibration: true,
    ticker: 'Whisper Echo',
  );
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
  );
}

void showGenericFailureSnackBar(
  BuildContext context, {
  String message = 'حدثت مشكلة، حاول مرة أخرى',
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> setupPushNotifications() async {
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await pushMessageSubscription?.cancel();
    pushMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (!messageSoundNotifier.value) return;
      final notification = message.notification;
      final text = notification?.body ?? message.data['text'];
      if (text is! String || text.isEmpty) return;
      unawaited(
        showChatNotification(
          chatTitle: notification?.title ?? 'Shadow Chat',
          message: text,
        ),
      );
    });
    messaging.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': newToken,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  } catch (error) {
    debugPrint('Push notification setup failed: $error');
  }
}

Future<void> checkForUpdates(BuildContext context) async {
  if (!firebaseReady) return;
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    
    final updateDoc = await FirebaseFirestore.instance
        .collection('appUpdates')
        .doc('latestVersion')
        .get();
    
    if (!updateDoc.exists) return;
    
    final latestVersion = updateDoc.data()?['version'] as String?;
    final downloadUrl = updateDoc.data()?['downloadUrl'] as String?;
    final updateMessage = updateDoc.data()?['message'] as String?;
    final isForced = updateDoc.data()?['forced'] as bool? ?? false;
    
    if (latestVersion == null || latestVersion == currentVersion) return;

    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return;
    final savedVersion = preferences.getString(updateNoticeVersionKey);
    final shownCount = savedVersion == latestVersion
      ? preferences.getInt(updateNoticeCountKey) ?? 0
      : 0;
    if (shownCount >= 2) return;
    
    // مقارنة الإصدارات
    if (_isNewVersionAvailable(currentVersion, latestVersion)) {
      if (context.mounted) {
        await preferences.setString(updateNoticeVersionKey, latestVersion);
        await preferences.setInt(updateNoticeCountKey, shownCount + 1);
        _showUpdateDialog(
          context,
          latestVersion,
          updateMessage ?? 'تطبيق جديد متاح! يرجى التحديث للاستمتاع بالميزات الجديدة.',
          downloadUrl,
          isForced,
        );
      }
    }
  } catch (error) {
    debugPrint('Update check error: $error');
  }
}

bool _isNewVersionAvailable(String current, String latest) {
  try {
    final currentParts = current.split('.');
    final latestParts = latest.split('.');
    
    for (int i = 0; i < (currentParts.length > latestParts.length ? latestParts.length : currentParts.length); i++) {
      final currentNum = int.tryParse(currentParts[i].split('-')[0]) ?? 0;
      final latestNum = int.tryParse(latestParts[i].split('-')[0]) ?? 0;
      
      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }
    return false;
  } catch (e) {
    debugPrint('Version comparison error: $e');
    return false;
  }
}

void _showUpdateDialog(
  BuildContext context,
  String newVersion,
  String message,
  String? downloadUrl,
  bool isForced,
) {
  showDialog(
    context: context,
    barrierDismissible: !isForced,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Color(0xFF00FF66), size: 24),
          SizedBox(width: 10),
          Text(
            'تحديث جديد متاح ✨',
            style: TextStyle(color: Color(0xFF00FF66), fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'الإصدار الجديد: $newVersion',
              style: const TextStyle(
                color: Color(0xFF00FF66),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (!isForced)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'تحديث لاحقاً',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF66),
            foregroundColor: Colors.black,
          ),
          onPressed: () async {
            Navigator.pop(dialogContext);
            if (downloadUrl != null && downloadUrl.isNotEmpty) {
              if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
              } else {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('لم تتمكن من فتح رابط التحميل')),
                  );
                }
              }
            }
          },
          child: const Text(
            'تحديث الآن',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

String appText(String arabic, String english) {
  return englishLanguageNotifier.value ? english : arabic;
}

const String defaultSecretRoomCode = '132465798';
const String defaultOwnerKey = 'DARK132465798';

Future<void> ensureDefaultSecretCredentials() async {
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final appConfigRef = FirebaseFirestore.instance
        .collection('config')
        .doc('app');
    final appSnapshot = await appConfigRef.get();
    final configuredOwnerUid = appSnapshot.data()?['ownerUid'];
    if (configuredOwnerUid == user.uid) {
      final ownerKeyHash = await hashPassword(defaultOwnerKey);
      await appConfigRef.set({
        'ownerKeyHash': ownerKeyHash,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      roomOwnerKeyHashNotifier.value = ownerKeyHash;
    }

    final secretConfigRef = FirebaseFirestore.instance
        .collection('config')
        .doc('secretRoom');
    if (configuredOwnerUid == user.uid) {
      final secretCodeHash = await hashPassword(defaultSecretRoomCode);
      await secretConfigRef.set({
        'codeHash': secretCodeHash,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      secretRoomCodeHashNotifier.value = secretCodeHash;
    }
  } catch (error) {
    debugPrint('Default secret config sync error: $error');
  }
}

Future<String> hashPassword(String password) async {
  final bytes = await Sha256().hash(utf8.encode(password));
  return base64Encode(bytes.bytes);
}

String sanitizeDisplayName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}

Future<void> syncUserDisplayNameAcrossApp(String newName) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final cleanedName = sanitizeDisplayName(newName);
  if (cleanedName.isEmpty) return;

  try {
    await user.updateDisplayName(cleanedName);
  } catch (error) {
    debugPrint('Update auth display name failed: $error');
  }

  final firestore = FirebaseFirestore.instance;
  final profileData = {
    'displayName': cleanedName,
    'name': cleanedName,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  await firestore
      .collection('users')
      .doc(user.uid)
      .set(profileData, SetOptions(merge: true));

  final publicId = currentPublicUserId ??
      publicUserIdNotifier.value ??
      'SC-${user.uid.substring(0, 6).toUpperCase()}';
  await firestore
      .collection('publicProfiles')
      .doc(user.uid)
      .set({
        'uid': user.uid,
        'displayName': cleanedName,
        'publicId': publicId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  final contactsSnapshot = await firestore
      .collection('users')
      .doc(user.uid)
      .collection(contactsCollectionName(ContactScope.regular))
      .get();

  for (final doc in contactsSnapshot.docs) {
    await doc.reference.set(
      {
        'displayName': cleanedName,
        'name': cleanedName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

Future<void> loadRoomOwnerKey() async {
  roomOwnerKeyHashNotifier.value = null;
  if (!firebaseReady) return;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('config')
        .doc('app')
        .get();
    final storedHash = snapshot.data()?['ownerKeyHash'];
    if (storedHash is String && storedHash.isNotEmpty) {
      roomOwnerKeyHashNotifier.value = storedHash;
    }
  } catch (error) {
    debugPrint('Room owner key load error: $error');
  }
}

Future<void> loadSecretRoomCode() async {
  secretRoomCodeHashNotifier.value = null;
  if (!firebaseReady) return;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('config')
        .doc('secretRoom')
        .get();
    final storedHash = snapshot.data()?['codeHash'];
    if (storedHash is String && storedHash.isNotEmpty) {
      secretRoomCodeHashNotifier.value = storedHash;
    }
  } catch (error) {
    debugPrint('Secret room code load error: $error');
  }
}

Future<void> savePrivacySetting(String key, bool value) async {
  if (key == 'ghostMode') {
    ghostModeNotifier.value = value;
  }
  if (key == 'autoDeleteMessages') {
    autoDeleteMessagesNotifier.value = value;
  }
  if (key == 'messageSound') {
    messageSoundNotifier.value = value;
  }

  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('privacy')
        .set({
          key: value,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (key == 'ghostMode') {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'ghostMode': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  } catch (error) {
    debugPrint('Privacy setting save error: $error');
  }
}

Future<Map<String, dynamic>> loadPrivacySettings() async {
  if (!firebaseReady) return {};
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('privacy')
        .get();
    final data = snapshot.data() ?? {};

    if (data['ghostMode'] is bool) {
      ghostModeNotifier.value = data['ghostMode'] as bool;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'ghostMode': data['ghostMode'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (data['autoDeleteMessages'] is bool) {
      autoDeleteMessagesNotifier.value = data['autoDeleteMessages'] as bool;
    }
    if (data['messageSound'] is bool) {
      messageSoundNotifier.value = data['messageSound'] as bool;
    }

    return data;
  } catch (error) {
    debugPrint('Privacy settings load error: $error');
    return {};
  }
}

Future<Map<String, dynamic>> loadSecretGroupSettings() async {
  secretGroupLockEnabledNotifier.value = false;
  secretGroupPasswordHashNotifier.value = null;
  if (!firebaseReady) return {};
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('secretGroup')
        .get();
    final data = snapshot.data() ?? {};
    final hash = data['passwordHash'];
    final enabled = data['enabled'] == true;
    secretGroupLockEnabledNotifier.value = enabled;
    secretGroupPasswordHashNotifier.value =
        enabled && hash is String && hash.isNotEmpty ? hash : null;
    return data;
  } catch (error) {
    debugPrint('Secret group settings load error: $error');
    return {};
  }
}

Future<void> saveSecretGroupPassword(String password) async {
  final hash = await hashPassword(password);
  secretGroupLockEnabledNotifier.value = true;
  secretGroupPasswordHashNotifier.value = hash;
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('secretGroup')
        .set({
          'enabled': true,
          'passwordHash': hash,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Secret group password save error: $error');
  }
}

Future<void> disableSecretGroupLock() async {
  secretGroupLockEnabledNotifier.value = false;
  secretGroupPasswordHashNotifier.value = null;
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('secretGroup')
        .set({
          'enabled': false,
          'passwordHash': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Secret group lock disable error: $error');
  }
}

Future<DateTime> ensureSecretAccessStart(String roomId) async {
  final fallback = DateTime.now();
  if (!firebaseReady) return fallback;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return fallback;
  final key = roomId == 'secret_group'
      ? 'secretGroupAccess'
      : 'secretRoomAccess';
  final reference = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('settings')
      .doc(key);
  try {
    final snapshot = await reference.get();
    final value = snapshot.data()?['startedAt'];
    if (value is Timestamp) return value.toDate();
    await reference.set({
      'startedAt': Timestamp.fromDate(fallback),
    }, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Secret access start load error: $error');
  }
  return fallback;
}

Future<void> deleteOwnChatMessages(String chatId) async {
  clearHistoryNotifier.value++;
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();
    var batch = FirebaseFirestore.instance.batch();
    var operationCount = 0;
    for (final message in snapshot.docs) {
      final data = message.data();
      final messageUid = data['uid'];

      if (messageUid == user.uid) {
        batch.delete(message.reference);
      } else {
        batch.update(message.reference, {
          'deletedFor': FieldValue.arrayUnion([user.uid]),
        });
      }

      operationCount++;
      if (operationCount == 450) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        operationCount = 0;
      }
    }
    if (operationCount > 0) await batch.commit();
  } catch (error) {
    debugPrint('Chat history delete error: $error');
  }
}

Future<void> deleteAllChatHistoryForUser() async {
  clearHistoryNotifier.value++;
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('messages')
        .get();
    var batch = FirebaseFirestore.instance.batch();
    var operationCount = 0;

    Future<void> commitBatch() async {
      if (operationCount == 0) return;
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      operationCount = 0;
    }

    for (final message in snapshot.docs) {
      final data = message.data();
      final messageUid = data['uid'];

      if (messageUid == user.uid) {
        batch.delete(message.reference);
      } else {
        batch.update(message.reference, {
          'deletedFor': FieldValue.arrayUnion([user.uid]),
        });
      }
      operationCount++;
      if (operationCount == 450) await commitBatch();
    }
    await commitBatch();
  } catch (error) {
    debugPrint('Full chat history delete error: $error');
    rethrow;
  }
}

Future<void> deleteExpiredOwnChatMessages(String chatId) async {
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('uid', isEqualTo: user.uid)
        .get();
    final now = Timestamp.now();
    var batch = FirebaseFirestore.instance.batch();
    var operationCount = 0;
    for (final message in snapshot.docs) {
      final expiresAt = message.data()['expiresAt'];
      if (expiresAt is! Timestamp || expiresAt.compareTo(now) > 0) {
        continue;
      }
      batch.delete(message.reference);
      operationCount++;
      if (operationCount == 450) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        operationCount = 0;
      }
    }
    if (operationCount > 0) await batch.commit();
  } catch (error) {
    debugPrint('Expired chat message delete error: $error');
  }
}

String chatDocumentId(String chatName) =>
    chatName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

String directChatDocumentId(String uidA, String uidB) {
  final participants = [uidA, uidB]..sort();
  return 'dm_${participants[0]}_${participants[1]}';
}

Future<bool> _hasApprovedDirectContact(String targetUid) async {
  final user = FirebaseAuth.instance.currentUser;
  if (!firebaseReady || user == null || targetUid.isEmpty) return false;

  try {
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(contactsCollectionName(ContactScope.regular))
        .doc(targetUid)
        .get();
    return myDoc.data()?['status'] == 'accepted';
  } catch (error) {
    debugPrint('Approved contact check error: $error');
    return false;
  }
}

Future<void> _markDirectChatAsRead(String contactUid) async {
  final user = FirebaseAuth.instance.currentUser;
  if (!firebaseReady || user == null || contactUid.isEmpty) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(contactsCollectionName(ContactScope.regular))
        .doc(contactUid)
        .set({'unreadCount': 0}, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Unread count reset error: $error');
  }
}

Future<void> _acceptContactRequest(String contactUid, String displayName) async {
  final user = FirebaseAuth.instance.currentUser;
  if (!firebaseReady || user == null || contactUid.isEmpty) return;

  try {
    final update = {
      'status': 'accepted',
      'lastMessage': 'تمت الموافقة على الدردشة',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(contactsCollectionName(ContactScope.regular))
        .doc(contactUid)
        .set(update, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('users')
        .doc(contactUid)
        .collection(contactsCollectionName(ContactScope.regular))
        .doc(user.uid)
        .set(update, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Accept contact request error for $displayName: $error');
  }
}

Future<void> _rejectContactRequest(String contactUid, String displayName) async {
  final user = FirebaseAuth.instance.currentUser;
  if (!firebaseReady || user == null || contactUid.isEmpty) return;

  try {
    final update = {
      'status': 'rejected',
      'lastMessage': 'تم رفض طلب الاتصال',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(contactsCollectionName(ContactScope.regular))
        .doc(contactUid)
        .set(update, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('users')
        .doc(contactUid)
        .collection(contactsCollectionName(ContactScope.regular))
        .doc(user.uid)
        .set(update, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Reject contact request error for $displayName: $error');
  }
}

Future<void> saveChatPassword(String chatName, String password) async {
  final passwordHash = await hashPassword(password);
  chatPasswordsNotifier.value = {
    ...chatPasswordsNotifier.value,
    chatName: passwordHash,
  };
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chatSecurity')
        .doc(chatDocumentId(chatName))
        .set({
          'chatName': chatName,
          'passwordHash': passwordHash,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Chat password Firebase sync failed: $error');
  }
}

Future<void> disableChatPassword(String chatName) async {
  chatPasswordsNotifier.value = {...chatPasswordsNotifier.value}
    ..remove(chatName);
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chatSecurity')
        .doc(chatDocumentId(chatName))
        .delete();
  } catch (error) {
    debugPrint('Chat password Firebase delete failed: $error');
  }
}

Future<void> loadAppLockSettings() async {
  var passwordHash = await hashPassword(
    'shadow-lock-${DateTime.now().microsecondsSinceEpoch}',
  );
  var enabled = false;

  // SharedPreferences is not supported on Linux
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    appLockEnabledNotifier.value = enabled;
    appLockPasswordNotifier.value = passwordHash;
    globalDarkModeNotifier.value = true;
    return;
  }

  final preferences = await SharedPreferences.getInstance();
  enabled = preferences.getBool(appLockEnabledKey) ?? false;
  final savedPasswordHash = preferences.getString(appLockPasswordHashKey);
  if (savedPasswordHash != null && savedPasswordHash.isNotEmpty) {
    passwordHash = savedPasswordHash;
  }

  if (firebaseReady) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final lockRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('security')
            .doc('appLock');
        final lockSnapshot = await lockRef.get();
        final data = lockSnapshot.data();
        if (data?['passwordHash'] is String &&
            (data!['passwordHash'] as String).isNotEmpty) {
          passwordHash = data['passwordHash'] as String;
          enabled = data['enabled'] == true;
        } else {
          await lockRef.set({
            'passwordHash': passwordHash,
            'enabled': enabled,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (error) {
        debugPrint('App lock Firebase load failed: $error');
      }
    }
  }

  await preferences.setBool(appLockEnabledKey, enabled);
  await preferences.setString(appLockPasswordHashKey, passwordHash);
  appLockEnabledNotifier.value = enabled;
  appLockPasswordNotifier.value = passwordHash;
  if (secureLocalDemoMode) {
    globalDarkModeNotifier.value = true;
    await preferences.setBool(darkModeKey, true);
  } else {
    globalDarkModeNotifier.value = preferences.getBool(darkModeKey) ?? true;
  }
}

Future<void> saveDarkModeSetting(bool enabled) async {
  globalDarkModeNotifier.value = enabled;

  // SharedPreferences is not supported on Linux
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    return;
  }

  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(darkModeKey, enabled);
}

Future<void> saveAppLockSettings({
  required bool enabled,
  required String passwordHash,
}) async {
  if (!firebaseReady) await initializeFirebase();
  final user = FirebaseAuth.instance.currentUser;

  // SharedPreferences is not supported on Linux
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    appLockEnabledNotifier.value = enabled;
    appLockPasswordNotifier.value = passwordHash;
    return;
  }

  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(appLockEnabledKey, enabled);
  await preferences.setString(appLockPasswordHashKey, passwordHash);
  appLockEnabledNotifier.value = enabled;
  appLockPasswordNotifier.value = passwordHash;

  if (!firebaseReady || user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('security')
        .doc('appLock')
        .set({
          'passwordHash': passwordHash,
          'enabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  } catch (error) {
    debugPrint('App lock Firebase sync failed: $error');
  }
}

Future<void> showChangeAppLockPasswordDialog(BuildContext context) async {
  final oldController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تغيير كلمة سر قفل التطبيق'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: oldController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة السر القديمة'),
          ),
          TextField(
            controller: newController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة السر الجديدة'),
          ),
          TextField(
            controller: confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'تأكيد كلمة السر الجديدة',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newPassword = newController.text.trim();
            if (await hashPassword(oldController.text.trim()) !=
                    appLockPasswordNotifier.value ||
                newPassword.length < 4 ||
                newPassword != confirmController.text.trim()) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تحقق من كلمة السر القديمة والجديدة'),
                ),
              );
              return;
            }
            try {
              await saveAppLockSettings(
                enabled: true,
                passwordHash: await hashPassword(newPassword),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ كلمة السر في Firebase')),
                );
              }
            } catch (error) {
              debugPrint('App lock password save error: $error');
              if (context.mounted) {
                showGenericFailureSnackBar(context);
              }
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  oldController.dispose();
  newController.dispose();
  confirmController.dispose();
}

bool isDuplicateFirebaseInitializationError(Object error) {
  if (error is FirebaseException) {
    if (error.code == 'duplicate-app') return true;
  }

  final text = error.toString();
  return text.contains('A Firebase App named') &&
      text.contains('already exists');
}

Future<SharedPreferences?> getSafeSharedPreferences() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    return null;
  }
  return SharedPreferences.getInstance();
}

Future<void> initializeFirebase() async {
  // Firebase is not supported on Linux desktop
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    firebaseReady = false;
    firebaseFailureMessage =
        'Firebase is not supported on Linux. Use Android, iOS, or Web.';
    return;
  }

  if (secureLocalDemoMode) {
    firebaseReady = false;
    firebaseFailureMessage = 'Local demo mode enabled';
    return;
  }

  try {
    if (Firebase.apps.isEmpty) {
      try {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: 'AIzaSyAyg-kuQKgCnYleTzBJUTyFOJkKNsPSj_M',
              appId: '1:525641785110:android:acb70e1294c17dec00fa37',
              messagingSenderId: '525641785110',
              projectId: 'shadow-chat-9edd9',
              authDomain: 'shadow-chat-9edd9.firebaseapp.com',
              storageBucket: 'shadow-chat-9edd9.firebasestorage.app',
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      } on FirebaseException catch (error) {
        if (!isDuplicateFirebaseInitializationError(error)) rethrow;
        debugPrint(
          'Firebase already initialized; ignoring duplicate init: $error',
        );
      }
    }

    firebaseReady = true;
    await initializeLocalNotifications();
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await ensureUserProfile();
        await setupPushNotifications();
        final privacySettings = await loadPrivacySettings();
        if (privacySettings['messageSound'] is bool) {
          messageSoundNotifier.value = privacySettings['messageSound'] as bool;
        }
      } catch (error) {
        debugPrint('User profile setup failed: $error');
      }
      await loadAppLockSettings();
      await loadSecretGroupSettings();
      await loadRoomOwnerKey();
      await loadSecretRoomCode();
    }
  } catch (error) {
    firebaseFailureMessage = error.toString();
    debugPrint('Firebase initialization failed: $error');
  }
}
