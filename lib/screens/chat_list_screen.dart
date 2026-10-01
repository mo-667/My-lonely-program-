part of '../main.dart';

// ==========================================
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowIntroduction();
      // التحقق من التحديثات
      if (mounted) {
        checkForUpdates(context);
      }
    });
  }

  Future<void> _checkAndShowIntroduction() async {
    try {
      final prefs = await getSafeSharedPreferences();
      if (prefs == null) return;
      final hasSeenIntro = prefs.getBool('has_seen_onboarding') ?? false;

      if (!hasSeenIntro && mounted) {
        _showIntroductionDialog();
      } else if (firebaseReady && hasSeenIntro) {
        // مزامنة حالة الترحيب مع Firebase في الخلفية
        _syncOnboardingStatusWithFirebase(true);
      }
    } catch (error) {
      debugPrint('Error checking introduction: $error');
    }
  }

  Future<void> _syncOnboardingStatusWithFirebase(bool completed) async {
    if (!firebaseReady) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('onboarding')
          .set({
            'onboardingCompleted': completed,
            'completedAt': FieldValue.serverTimestamp(),
            'appVersion': '1.0.0-beta.1',
          }, SetOptions(merge: true));
      debugPrint('Onboarding status synced to Firebase');
    } catch (error) {
      debugPrint('Error syncing onboarding status: $error');
    }
  }

  Future<void> _showIntroductionDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'أهلاً بك في Shadow Chat 👋',
          style: TextStyle(
            color: Color(0xFF00FF66),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'تطبيق المراسلة الآمن والمشفر',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              Text(
                'الإصدار التجريبي: BETA 1.0.0-beta.1',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF00FF66)),
              const SizedBox(height: 12),
              const Text(
                'المميزات:',
                style: TextStyle(
                  color: Color(0xFF00FF66),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              const Text(
                '🔐 تشفير AES-256 للرسائل\n'
                '🎙️ رسائل صوتية مشفرة\n'
                '📸 مشاركة الصور والفيديوهات\n'
                '🌙 وضع مظلم حصري\n'
                '👻 وضع الشبح المتقدم\n'
                '🔒 غرفة سرية بكلمة مرور\n'
                '⏰ حذف تلقائي للرسائل',
                style: TextStyle(color: Colors.white70, height: 1.6),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF00FF66)),
              const SizedBox(height: 12),
              const Text(
                'الأذونات المطلوبة:',
                style: TextStyle(
                  color: Color(0xFF00FF66),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              const Text(
                '📷 الكاميرا: لمشاركة الصور والفيديوهات\n'
                '🎙️ الميكروفون: للرسائل الصوتية\n'
                '🔔 الإشعارات: للتنبيهات الفورية',
                style: TextStyle(color: Colors.white70, height: 1.6),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF66).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF66), width: 1),
                ),
                child: const Text(
                  '💾 سيتم حفظ بياناتك بأمان في Firebase\nجميع البيانات مشفرة وآمنة 🔐',
                  style: TextStyle(
                    color: Color(0xFF00FF66),
                    fontSize: 12,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final prefs = await getSafeSharedPreferences();
                if (prefs != null) {
                  await prefs.setBool('has_seen_onboarding', true);
                }

                // مزامنة الحالة مع Firebase
                await _syncOnboardingStatusWithFirebase(true);

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                debugPrint('Error saving onboarding flag: $error');
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text(
              'الدخول',
              style: TextStyle(
                color: Color(0xFF00FF66),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _chooseChatToSecure(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'اختر دردشة لتأمينها',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser == null
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection(contactsCollectionName(ContactScope.regular))
                    .orderBy('updatedAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              final contacts = snapshot.data?.docs ??
                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              if (contacts.isEmpty) {
                return const Text(
                  'لا توجد دردشات متاحة للتأمين',
                  style: TextStyle(color: Colors.white70),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final data = contacts[index].data();
                  final chatName = data['displayName'] as String? ?? 'دردشة';
                  return ListTile(
                    leading: const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF00FF66),
                    ),
                    title: Text(
                      chatName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      final currentUid = FirebaseAuth.instance.currentUser?.uid;
                      final chatId = currentUid == null
                          ? chatName
                          : directChatDocumentId(currentUid, contacts[index].id);
                      _setChatPassword(context, chatName, chatId: chatId);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _setChatPassword(
    BuildContext context,
    String chatName, {
    String? chatId,
  }) {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'تأمين $chatName',
          style: const TextStyle(color: Color(0xFF00FF66)),
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'اكتب كلمة المرور',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final String password = passwordController.text.trim();
              if (password.length < 4) return;
              try {
                await saveChatPassword(chatId ?? chatName, password);
              } catch (error) {
                debugPrint('Chat password save error: $error');
                return;
              }
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('تم تأمين $chatName')));
            },
            child: const Text(
              'تأمين',
              style: TextStyle(color: Color(0xFF00FF66)),
            ),
          ),
        ],
      ),
    ).then((_) => passwordController.dispose());
  }

  bool _isUnknownContact(Map<String, dynamic> data) {
    final name = data['displayName'];
    if (name is! String || name.trim().isEmpty) return true;
    final normalizedName = name.trim().toLowerCase();
    return normalizedName == 'غير معرف' ||
        normalizedName == 'غير معروف' ||
        normalizedName == 'unknown';
  }

  Future<void> _removeChatContact(String contactUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || contactUid.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;

      await firestore
          .collection('users')
          .doc(user.uid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(contactUid)
          .delete();

      await firestore
          .collection('users')
          .doc(contactUid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(user.uid)
          .delete();

      final directChatId = directChatDocumentId(user.uid, contactUid);
      final chatRef = firestore.collection('chats').doc(directChatId);
      final chatSnapshot = await chatRef.get();
      if (chatSnapshot.exists) {
        await chatRef.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الدردشة من Firebase')),
        );
      }
    } catch (error) {
      debugPrint('Chat contact removal error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    return Directionality(
      textDirection: englishLanguageNotifier.value
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: Transform.scale(
                  scale: MediaQuery.sizeOf(context).width < 600 ? 1.9 : 1.0,
                  child: const ColoredBox(color: Color(0xFF101716)),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.black.withOpacity(0.6),
                centerTitle: true,
                title: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "✨ 🌑 SHADOW CHAT BETA 🌑 ✨",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF00FF66)),
                    tooltip: appText('بحث', 'Search'),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    tooltip: 'الإعدادات',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: !firebaseReady
                  ? const Center(
                      child: Text(
                        'وضع العرض المحلي مفعل، تسجيل الدخول غير متاح هنا',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : user == null
                  ? const Center(
                      child: Text(
                        'يرجى تسجيل الدخول أولاً',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection(contactsCollectionName(ContactScope.regular))
                          .orderBy('updatedAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: const Text(
                              'حدثت مشكلة، حاول مرة أخرى',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00FF66),
                              ),
                            ),
                          );
                        }

                        final contacts = (snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                            .where((doc) => !_isUnknownContact(doc.data()))
                            .toList();

                        for (final doc in snapshot.data?.docs ?? []) {
                          if (_isUnknownContact(doc.data())) {
                            unawaited(_removeChatContact(doc.id));
                          }
                        }

                        if (contacts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  color: Color(0xFF00FF66),
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'لا توجد دردشات',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'أضف جهات اتصال جديدة للبدء',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final contactData = contacts[index].data();
                            final contactName = contactData['displayName'] ?? 'مستخدم';
                            final lastMessage = contactData['lastMessage'] ?? 'لا توجد رسائل';
                            final contactUid = contacts[index].id;
                            final unreadCount =
                              (contactData['unreadCount'] as num?)?.toInt() ?? 0;
                            final status = (contactData['status'] as String?) ?? 'pending';
                            final isIncomingRequest = status == 'incoming';
                            final isPendingRequest = status == 'pending';

                            return Dismissible(
                              key: ValueKey('chat-$contactUid'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) {
                                unawaited(_removeChatContact(contactUid));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تمت إزالة الدردشة'),
                                  ),
                                  );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E1716).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF1B2D2A),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00FF66).withOpacity(0.06),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: const Color(0xFF0F2724),
                                    foregroundColor: const Color(0xFFB7FFD8),
                                    child: Text(
                                      contactName.toString().isNotEmpty
                                          ? contactName.toString()[0]
                                          : 'م',
                                      style: const TextStyle(
                                        color: Color(0xFFB7FFD8),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                    stream: FirebaseFirestore.instance
                                        .collection('publicProfiles')
                                        .doc(contactUid)
                                        .snapshots(),
                                    builder: (context, profileSnapshot) {
                                      final profileName = profileSnapshot
                                          .data
                                          ?.data()?['displayName'] as String?;
                                      return Text(
                                        profileName?.trim().isNotEmpty == true
                                            ? profileName!
                                            : contactName.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      );
                                    },
                                  ),
                                  subtitle: Text(
                                    isIncomingRequest
                                        ? 'طلب اتصال جديد — يحتاج موافقة'
                                        : (isPendingRequest
                                            ? 'طلب تم إرساله — ينتظر الموافقة'
                                            : lastMessage.toString()),
                                    style: TextStyle(
                                      color: isIncomingRequest
                                          ? const Color(0xFFB7FFD8)
                                          : Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (unreadCount > 0)
                                        Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00FF66),
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF00FF66)
                                                    .withOpacity(0.45),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                              color: Color(0xFF07120E),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      if (unreadCount > 0)
                                        const SizedBox(width: 8),
                                      if (isIncomingRequest || isPendingRequest)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isIncomingRequest)
                                              Container(
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00FF66).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: const Color(0xFF00FF66).withOpacity(0.35),
                                                  width: 1,
                                                ),
                                              ),
                                              child: IconButton(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.check, color: Color(0xFF9BF7C8)),
                                                tooltip: 'قبول',
                                                onPressed: () => _acceptContactRequest(
                                                  contactUid,
                                                  contactName.toString(),
                                                ),
                                              ),
                                            ),
                                            if (isIncomingRequest) const SizedBox(width: 8),
                                            Container(
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.redAccent.withOpacity(0.28),
                                                  width: 1,
                                                ),
                                              ),
                                              child: IconButton(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.close, color: Colors.redAccent),
                                                tooltip: isPendingRequest ? 'إلغاء الطلب' : 'رفض الطلب',
                                                onPressed: () => _rejectContactRequest(
                                                  contactUid,
                                                  contactName.toString(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                      Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.redAccent.withOpacity(0.28),
                                            width: 1,
                                          ),
                                        ),
                                        child: IconButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          tooltip: 'حذف الدردشة',
                                          onPressed: () => _removeChatContact(contactUid),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    if (isIncomingRequest || isPendingRequest) {
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          chatName: contactName.toString(),
                                          contactUid: contactUid,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              floatingActionButton: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF66).withOpacity(0.6),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF00FF66), width: 1),
                  ),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'status',
                          child: Row(
                            children: [
                              Icon(Icons.amp_stories, color: Color(0xFF00FF66)),
                              SizedBox(width: 10),
                              Text(
                                'خيارات الحالة',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'security',
                          child: Row(
                            children: [
                              Icon(Icons.security, color: Colors.cyanAccent),
                              SizedBox(width: 10),
                              Text(
                                'تأمين الدردشة',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'contacts',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_add_alt_1,
                                color: Colors.amberAccent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'إضافة جهات اتصال',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'secret_room',
                          child: Row(
                            children: [
                              Icon(Icons.vpn_key, color: Colors.amberAccent),
                              SizedBox(width: 10),
                              Text(
                                'الغرفة السرية (Password)',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'ghost',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_off,
                                color: Colors.purpleAccent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                ' المجموعة السرية (Password)',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'shadow_chat',
                          child: Row(
                            children: [
                              Icon(Icons.chat_bubble_outline, color: Colors.greenAccent),
                              SizedBox(width: 10),
                              Text(
                                'محادثة الظل',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                  onSelected: (String result) {
                    if (result == 'status') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم فتح خيارات الحالة ✨')),
                      );
                    } else if (result == 'security') {
                      _chooseChatToSecure(context);
                    } else if (result == 'contacts') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactsScreen(),
                        ),
                      );
                    } else if (result == 'secret_room') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SecretRoomScreen(),
                        ),
                      );
                    } else if (result == 'ghost') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SecretChatScreen(),
                        ),
                      );
                    } else if (result == 'shadow_chat') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShadowChatScreen(),
                        ),
                      );
                    }
                  },
                  child: FloatingActionButton(
                    onPressed: null,
                    backgroundColor: Colors.black,
                    elevation: 0,
                    highlightElevation: 0,
                    shape: const CircleBorder(
                      side: BorderSide(color: Color(0xFF00FF66), width: 2),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      color: Color(0xFF00FF66),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. شاشة الغرفة السرية
