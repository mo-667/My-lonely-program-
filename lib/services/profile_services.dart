part of '../main.dart';

Future<void> ensureUserProfile() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final fallbackPublicId =
    'SC-${user.uid.substring(0, 6).toUpperCase()}';
  currentPublicUserId = fallbackPublicId;
  publicUserIdNotifier.value = fallbackPublicId;

  final profileRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid);
  DocumentSnapshot<Map<String, dynamic>>? profile;
  var profileReadSucceeded = false;
  try {
    profile = await profileRef.get().timeout(const Duration(seconds: 10));
    profileReadSucceeded = true;
  } catch (error) {
    debugPrint('User profile read failed: $error');
  }
  final storedPublicId = profile?.data()?['publicId'];
  final publicId = storedPublicId is String && storedPublicId.isNotEmpty
    ? storedPublicId
    : fallbackPublicId;
  currentPublicUserId = publicId;
  publicUserIdNotifier.value = publicId;
  if (profileReadSucceeded) {
    try {
      final profileData = {
        'publicId': publicId,
        'displayName': profile?.data()?['displayName'] ?? 'Shadow User',
        if (user.phoneNumber != null)
          'phoneNumber': normalizePhoneNumber(user.phoneNumber!),
        if (user.phoneNumber != null)
          'phoneSearchKey': _phoneSearchKey(user.phoneNumber!),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await profileRef.set(profileData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'publicId': publicId,
            'displayName': profileData['displayName'],
            if (profileData['phoneSearchKey'] != null)
              'phoneSearchKey': profileData['phoneSearchKey'],
            if (profileData['phoneNumber'] != null)
              'phoneNumber': profileData['phoneNumber'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('User profile sync failed: $error');
    }
  }

  // تعيين owner للغرفة السرية والمجموعة السرية تلقائياً
  try {
    final configRef = FirebaseFirestore.instance
        .collection('config')
        .doc('app');
    final configDoc = await configRef.get();
    if (configDoc.data()?['ownerUid'] == null) {
      await configRef.set({
        'ownerUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await ensureDefaultSecretCredentials();
  } catch (error) {
    debugPrint('Owner assignment error: $error');
  }
}

String normalizePhoneNumber(String phone) =>
    phone
        .replaceAllMapped(RegExp(r'[٠-٩]'), (match) {
          return '٠١٢٣٤٥٦٧٨٩'.indexOf(match.group(0)!).toString();
        })
        .replaceAll(RegExp(r'[^0-9+]'), '');

String determineRegularContactAction({
  required String myStatus,
  required String otherStatus,
}) {
  final normalizedMyStatus = myStatus.trim().toLowerCase();
  final normalizedOtherStatus = otherStatus.trim().toLowerCase();

  if (normalizedMyStatus == 'accepted' || normalizedOtherStatus == 'accepted') {
    return 'accepted';
  }
  if (normalizedMyStatus == 'pending' || normalizedOtherStatus == 'pending') {
    return 'pending';
  }
  if (normalizedMyStatus == 'incoming' || normalizedOtherStatus == 'incoming') {
    return 'incoming';
  }
  if (normalizedMyStatus == 'rejected' || normalizedOtherStatus == 'rejected') {
    return 'rejected';
  }
  return 'none';
}

String _phoneSearchKey(String phone) {
  final normalizedPhone = normalizePhoneNumber(phone);
  final normalized = normalizedPhone.startsWith('+')
      ? normalizedPhone.substring(1)
      : normalizedPhone;
  return normalized.length > 10
      ? normalized.substring(normalized.length - 10)
      : normalized;
}

String firebaseWriteFailureMessage(Object error) {
  if (error is FirebaseException) {
    return 'تعذرت الإضافة في Firebase (${error.code}). تحقق من تسجيل الدخول والاتصال وقواعد المشروع.';
  }
  return 'تعذرت الإضافة في Firebase. تحقق من الاتصال وإعدادات المشروع.';
}

Future<void> updatePresence(bool isOnline) async {
  if (!firebaseReady) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    final now = Timestamp.now();
    final presenceData = {
      'isOnline': isOnline,
      'lastSeen': now,
      'lastSeenAt': now,
    };
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      presenceData,
      SetOptions(merge: true),
    );
    await FirebaseFirestore.instance
        .collection('publicProfiles')
        .doc(user.uid)
        .set(presenceData, SetOptions(merge: true));
  } catch (error) {
    debugPrint('Presence update error: $error');
  }
}
