part of '../main.dart';

// ==========================================
class SecretRoomScreen extends StatefulWidget {
  const SecretRoomScreen({super.key});

  @override
  State<SecretRoomScreen> createState() => _SecretRoomScreenState();
}

enum ContactScope { regular, group, room }

String contactsCollectionName(ContactScope scope) {
  switch (scope) {
    case ContactScope.regular:
      return 'regularContacts';
    case ContactScope.group:
      return 'groupContacts';
    case ContactScope.room:
      return 'roomContacts';
  }
}

class ContactsScreen extends StatefulWidget {
  final ContactScope scope;
  final bool ownerVerified;

  const ContactsScreen({
    super.key,
    this.scope = ContactScope.regular,
    this.ownerVerified = false,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _contactIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _headerScrollController = ScrollController();
  final Set<String> _sendingRequestUids = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.scope == ContactScope.room) {
      unawaited(refreshSecretRoomMemberNotifier());
    }
  }

  @override
  void dispose() {
    _contactIdController.dispose();
    _nameController.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveLocalContactEntry({
    required String targetUid,
    required String displayName,
    required String publicId,
  }) async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return;
    final key = 'local_contacts_${widget.scope.name}';
    final existing = preferences.getStringList(key) ?? const <String>[];
    final decoded = existing
        .map((item) => jsonDecode(item))
        .whereType<Map<String, dynamic>>()
        .toList();
    final entry = {
      'contactId': publicId,
      'uid': targetUid,
      'displayName': displayName.isEmpty ? 'جهة اتصال' : displayName,
      'name': displayName.isEmpty ? 'جهة اتصال' : displayName,
      'lastMessage': 'لا توجد رسائل',
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final index = decoded.indexWhere((item) => item['uid'] == targetUid);
    if (index >= 0) {
      decoded[index] = entry;
    } else {
      decoded.add(entry);
    }
    await preferences.setStringList(
      key,
      decoded.map((item) => jsonEncode(item)).toList(),
    );
  }

  Future<void> _saveContactRelationship({
    required String targetUid,
    required String displayName,
    required String publicId,
    String status = 'accepted',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (targetUid.isEmpty) return;

    if (!firebaseReady || user == null) {
      await _saveLocalContactEntry(
        targetUid: targetUid,
        displayName: displayName,
        publicId: publicId,
      );
      return;
    }

    final contactData = {
      'contactId': publicId,
      'uid': targetUid,
      'displayName': displayName.isEmpty ? 'جهة اتصال' : displayName,
      'lastMessage': status == 'pending' ? 'طلب اتصال في انتظار الموافقة' : 'لا توجد رسائل',
      'name': displayName.isEmpty ? 'جهة اتصال' : displayName,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (widget.scope != ContactScope.regular) {
      final roomId = widget.scope == ContactScope.group
          ? 'secret_group'
          : 'secret_room';
      if (widget.scope == ContactScope.room) {
        final memberCount = await countRoomMembers(roomId);
        if (isSecretRoomAtCapacity(memberCount)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم الوصول إلى الحد الأقصى 100 عضو في الغرفة السرية'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }
      final membershipReference = FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(targetUid);
      final membership = await membershipReference.get();
      if (!membership.exists) {
        await membershipReference.set({
          'displayName': displayName.isEmpty ? 'جهة اتصال' : displayName,
          'addedBy': user.uid,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
      if (widget.scope == ContactScope.room) {
        await refreshSecretRoomMemberNotifier();
      }
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(contactsCollectionName(widget.scope))
        .doc(targetUid)
        .set(contactData, SetOptions(merge: true));
  }

  String _regularContactDecision({
    required String myStatus,
    required String otherStatus,
  }) {
    return determineRegularContactAction(
      myStatus: myStatus,
      otherStatus: otherStatus,
    );
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
      final myStatus = (myDoc.data()?['status'] as String?) ?? 'none';
        return _regularContactDecision(myStatus: myStatus, otherStatus: 'none') ==
          'accepted';
    } catch (error) {
      debugPrint('Approved contact check error: $error');
      return false;
    }
  }

  Future<void> _acceptContactRequest(String contactUid, String displayName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || contactUid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(contactUid)
          .set({
            'status': 'accepted',
            'lastMessage': 'تمت الموافقة على الدردشة',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(contactUid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(user.uid)
          .set({
            'status': 'accepted',
            'lastMessage': 'تمت الموافقة على الدردشة',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت الموافقة على $displayName')),
        );
      }
    } catch (error) {
      debugPrint('Accept contact request error: $error');
    }
  }

  Future<void> _rejectContactRequest(String contactUid, String displayName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null || contactUid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(contactUid)
          .set({
            'status': 'rejected',
            'lastMessage': 'تم رفض طلب الاتصال',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(contactUid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(user.uid)
          .set({
            'status': 'rejected',
            'lastMessage': 'تم رفض طلب الاتصال',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم رفض طلب $displayName')),
        );
      }
    } catch (error) {
      debugPrint('Reject contact request error: $error');
    }
  }

  Future<void> _addContact() async {
    final input = _contactIdController.text.trim();
    final String publicId = input.toUpperCase();
    final String name = _nameController.text.trim();
    final User? user = FirebaseAuth.instance.currentUser;
    if (input.isEmpty) return;

    if (!firebaseReady || user == null) {
      final targetUid = publicId.isEmpty ? 'local_${DateTime.now().millisecondsSinceEpoch}' : publicId;
      await _saveContactRelationship(
        targetUid: targetUid,
        displayName: name.isEmpty ? 'جهة اتصال محلية' : name,
        publicId: publicId.isEmpty ? targetUid : publicId,
      );
      _contactIdController.clear();
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة جهة الاتصال محليًا')),
        );
      }
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> matchingUsers;
      if (input.startsWith('+') || RegExp(r'^[0-9٠-٩ ()-]+$').hasMatch(input)) {
        final phoneKey = _phoneMatchKey(input);
        matchingUsers = await FirebaseFirestore.instance
          .collection('publicProfiles')
            .where('phoneSearchKey', isEqualTo: phoneKey)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 12));
      } else {
        matchingUsers = await FirebaseFirestore.instance
          .collection('publicProfiles')
            .where('publicId', isEqualTo: publicId)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 12));
      }
      if (matchingUsers.docs.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على حساب بهذا المعرّف أو الرقم'),
            ),
          );
        return;
      }

      final targetUid = matchingUsers.docs.first.id;
      if (targetUid == user.uid) {
        return;
      }

      final resolvedDisplayName = name.isEmpty
          ? (matchingUsers.docs.first.data()['displayName'] as String? ??
              'جهة اتصال')
          : name;
      final resolvedPublicId =
          matchingUsers.docs.first.data()['publicId'] as String? ?? targetUid;
      if (widget.scope != ContactScope.regular) {
        await _saveContactRelationship(
          targetUid: targetUid,
          displayName: resolvedDisplayName,
          publicId: resolvedPublicId,
          status: 'accepted',
        );
        _contactIdController.clear();
        _nameController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة العضو بنجاح')),
          );
        }
        return;
      }

      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(targetUid)
          .get();
      final action = _regularContactDecision(
        myStatus: (myDoc.data()?['status'] as String?) ?? 'none',
        otherStatus: 'none',
      );

      if (action == 'accepted') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أنت بالفعل متصل بهذا المستخدم')),
          );
        }
        return;
      }
      if (action == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('طلب الإضافة لهذا المستخدم قيد الانتظار بالفعل')),
          );
        }
        return;
      }
      if (action == 'incoming') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذا المستخدم أرسل لك طلب اتصال بالفعل')),
          );
        }
        return;
      }

      await _saveContactRelationship(
        targetUid: targetUid,
        displayName: resolvedDisplayName,
        publicId: resolvedPublicId,
        status: 'pending',
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(user.uid)
          .set({
            'contactId': user.uid,
            'uid': user.uid,
            'displayName': user.displayName ?? 'مستخدم',
            'name': user.displayName ?? 'مستخدم',
            'lastMessage': 'طلب اتصال جديد',
            'status': 'incoming',
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _contactIdController.clear();
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الموافقة إلى جهة الاتصال')),
        );
      }
    } catch (error) {
      debugPrint('Contact save error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firebaseWriteFailureMessage(error)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _normalizePhone(String phone) {
    final arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    var normalized = phone;
    for (var index = 0; index < arabicDigits.length; index++) {
      normalized = normalized.replaceAll(arabicDigits[index], index.toString());
    }
    return normalized.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _phoneMatchKey(String phone) {
    return _phoneSearchKey(phone);
  }

  Future<void> _addAppUserByTap(String targetUid, String publicId, String displayName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يحتاج التطبيق إلى اتصال Firebase لإضافة مستخدم من التطبيق')),
        );
      }
      return;
    }
    if (targetUid == user.uid) {
      return;
    }
    if (_sendingRequestUids.contains(targetUid)) return;
    setState(() => _sendingRequestUids.add(targetUid));

    try {
      if (widget.scope != ContactScope.regular) {
        await _saveContactRelationship(
          targetUid: targetUid,
          displayName: displayName.isEmpty ? publicId : displayName,
          publicId: publicId,
          status: 'accepted',
        );
        if (mounted) {
          final sectionName = widget.scope == ContactScope.group
              ? 'المجموعة'
              : 'الغرفة';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إضافة $displayName إلى $sectionName')),
          );
        }
        return;
      }

      final myExisting = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(targetUid)
          .get();
      final action = _regularContactDecision(
        myStatus: (myExisting.data()?['status'] as String?) ?? 'none',
        otherStatus: 'none',
      );

      if (action == 'accepted') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('أنت بالفعل لديك صلاحية الدردشة مع $displayName')),
          );
        }
        return;
      }
      if (action == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('طلب الإضافة إلى $displayName موجود بالفعل في الانتظار')),
          );
        }
        return;
      }
      if (action == 'incoming') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('هذا المستخدم أرسل لك طلب اتصال بالفعل')),
          );
        }
        return;
      }

      await _saveContactRelationship(
        targetUid: targetUid,
        displayName: displayName.isEmpty ? publicId : displayName,
        publicId: publicId,
        status: 'pending',
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection(contactsCollectionName(ContactScope.regular))
          .doc(user.uid)
          .set({
            'contactId': user.uid,
            'uid': user.uid,
            'displayName': user.displayName ?? 'مستخدم',
            'name': user.displayName ?? 'مستخدم',
            'lastMessage': 'طلب اتصال جديد',
            'status': 'incoming',
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرسال طلب الموافقة إلى $displayName')),
        );
      }
    } catch (error) {
      debugPrint('One-tap add request error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firebaseWriteFailureMessage(error)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingRequestUids.remove(targetUid));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scope == ContactScope.room && !widget.ownerVerified) {
      return const Scaffold(
        body: Center(child: Text('يجب التحقق من مفتاح المالك أولًا')),
      );
    }
    final User? user = FirebaseAuth.instance.currentUser;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF07110F),
        appBar: AppBar(
          title: Text(
            widget.scope == ContactScope.regular
                ? 'جهات اتصال الشات'
                : widget.scope == ContactScope.group
                ? 'جهات اتصال المجموعة'
                : 'جهات اتصال الغرفة',
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          iconTheme: const IconThemeData(color: Color(0xFF38E8A5)),
        ),
        body: Column(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                ),
                child: Scrollbar(
                  controller: _headerScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _headerScrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                children: [
                  if (user != null)
                    ValueListenableBuilder<String?>(
                      valueListenable: publicUserIdNotifier,
                      builder: (context, publicId, child) {
                        return SelectableText(
                          'معرّفك السهل: ${publicId ?? 'جارٍ التحميل...'}',
                          style: const TextStyle(
                            color: Color(0xFF38E8A5),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  if (firebaseReady)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('publicProfiles')
                          .orderBy('updatedAt', descending: true)
                          .limit(8)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        final appUsers = docs
                            .where((doc) => doc.id != currentUserId)
                            .toList();
                        if (appUsers.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1C1A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إضافة من التطبيق بنقرة واحدة',
                                style: TextStyle(
                                  color: Color(0xFF38E8A5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...appUsers.map((doc) {
                                final data = doc.data();
                                final publicId = (data['publicId'] as String?) ?? doc.id;
                                final displayName = (data['displayName'] as String?) ?? 'مستخدم';
                                final isSending = _sendingRequestUids.contains(doc.id);
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$displayName · $publicId',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: isSending
                                          ? null
                                          : () => _addAppUserByTap(
                                                doc.id,
                                                publicId,
                                                displayName,
                                              ),
                                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                                      label: Text(
                                        isSending
                                            ? 'جارٍ الإرسال...'
                                            : widget.scope == ContactScope.regular
                                            ? 'إرسال طلب'
                                            : 'إضافة الآن',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    ),
                  TextField(
                    controller: _contactIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'المعرّف السهل',
                      hintText: 'SC-A1B2C3',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'اسم جهة الاتصال',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addContact,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(
                        widget.scope == ContactScope.regular
                            ? 'إرسال طلب'
                            : 'إضافة عضو',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38E8A5),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () {
                        _headerScrollController.animateTo(
                          _headerScrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                        );
                      },
                      icon: const Icon(Icons.keyboard_arrow_down),
                      label: const Text('نزّل الصفحة لعرض المزيد'),
                    ),
                  ),
                ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: user == null
                  ? const Center(
                      child: Text(
                        'حدثت مشكلة، حاول مرة أخرى',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection(contactsCollectionName(widget.scope))
                          .orderBy('createdAt')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return const Center(
                            child: Text(
                              'حدثت مشكلة، حاول مرة أخرى',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        final docs = snapshot.data?.docs ?? [];
                        Widget buildContactList(
                          List<QueryDocumentSnapshot<Map<String, dynamic>>>
                              visibleDocs,
                        ) {
                          if (visibleDocs.isEmpty) {
                            return const Center(
                              child: Text(
                                'لا توجد جهات اتصال بعد',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: visibleDocs.length,
                            itemBuilder: (context, index) {
                              final contact = visibleDocs[index];
                              final data = contact.data();
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(
                                  data['displayName'] ?? 'جهة اتصال',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  data['contactId'] ?? contact.id,
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                onTap: () {
                                  final status =
                                      data['status'] as String? ?? 'pending';
                                  if (widget.scope == ContactScope.regular &&
                                      status != 'accepted') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          status == 'incoming'
                                              ? 'اقبل طلب الاتصال أولًا لفتح الدردشة'
                                              : 'انتظر موافقة الطرف الآخر لفتح الدردشة',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) {
                                        if (widget.scope == ContactScope.room) {
                                          return const BlackRoomScreen();
                                        }
                                        if (widget.scope == ContactScope.group) {
                                          return const SecretChatScreen();
                                        }
                                        return ChatScreen(
                                          chatName:
                                              data['displayName'] ?? 'جهة اتصال',
                                          contactUid: data['uid'] ?? contact.id,
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }

                        if (widget.scope == ContactScope.regular) {
                          return buildContactList(docs);
                        }

                        final roomId = widget.scope == ContactScope.group
                            ? 'secret_group'
                            : 'secret_room';
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(roomId)
                              .collection('members')
                              .snapshots(),
                          builder: (context, membersSnapshot) {
                            final memberIds = membersSnapshot.data?.docs
                                    .map((member) => member.id)
                                    .toSet() ??
                                <String>{};
                            final visibleDocs = docs
                                .where((contact) => memberIds.contains(contact.id))
                                .toList();
                            return buildContactList(visibleDocs);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecretRoomScreenState extends State<SecretRoomScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  bool _isUnlocked = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF07110F),
        appBar: AppBar(
          title: const Text(
            '🔐 الغرفة السرية المحصنة',
            style: TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          backgroundColor: Colors.black87,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.amberAccent),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.grey[900]!, Colors.black],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isUnlocked
                ? _buildSecretWorkspace()
                : _buildCodeEntryView(),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEntryView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 70,
                  color: Colors.amberAccent,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'منطقة مقيدة أمنياً',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل كود الغرفة الثابت للوصول إلى محتواها',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 30),
            TextField(
              controller: _codeController,
              style: const TextStyle(color: Colors.white, letterSpacing: 2),
              obscureText: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.grey[900],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Colors.amberAccent,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF00FF66),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                ),
                icon: const Icon(Icons.lock_open, color: Colors.black),
                label: const Text(
                  'فك التشفير والدخول',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () async {
                  await loadSecretRoomCode();
                    final enteredCode = _codeController.text.trim();
                    final isValidCode = enteredCode.isNotEmpty &&
                        secretRoomCodeHashNotifier.value != null &&
                        await hashPassword(enteredCode) ==
                            secretRoomCodeHashNotifier.value;
                    if (isValidCode) {
                    final user = FirebaseAuth.instance.currentUser;
                    try {
                      if (firebaseReady && user != null) {
                          final membershipReference = FirebaseFirestore.instance
                            .collection('rooms')
                            .doc('secret_room')
                            .collection('members')
                              .doc(user.uid);
                          final membership = await membershipReference.get();
                          final isOwner = (await FirebaseFirestore.instance
                                  .collection('config')
                                  .doc('app')
                                  .get())
                              .data()?['ownerUid'] == user.uid;
                          if (!membership.exists && !isOwner) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('يجب أن يضيفك مالك الغرفة أولًا قبل الدخول'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                            return;
                          }
                          if (isOwner && !membership.exists) {
                            await membershipReference.set({
                              'displayName': 'مالك الغرفة',
                              'addedBy': user.uid,
                              'addedAt': FieldValue.serverTimestamp(),
                            });
                          }
                      }
                    } catch (error) {
                      debugPrint('Secret room entry membership error: $error');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تعذر دخول الغرفة. تأكد من نشر قواعد Firebase وتحقق صلاحية المالك.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }
                    setState(() {
                      _isUnlocked = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم فتح الغرفة السرية بنجاح 🚀'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('الكود خطأ! ❌ برجاء مراجعة كود الغرفة'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amberAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amberAccent, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.security, color: Colors.amberAccent, size: 36),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'أنت الآن في النطاق الآمن',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'البيانات هنا مشفرة كلياً ولا تظهر في السجل الرئيسي للتطبيق.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'إدارة إعدادات الغرفة:',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<List<String>>(
          valueListenable: secretRoomMembersNotifier,
          builder: (context, members, child) {
            return ListTile(
              tileColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(Icons.group_add, color: Color(0xFF00FF66)),
              title: Text(
                'إدارة أعضاء الغرفة (للمالك فقط)',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                members.length >= maxSecretRoomMembers
                    ? 'تم الوصول إلى الحد الأقصى: ${members.length} / $maxSecretRoomMembers'
                    : 'الأعضاء: ${members.length} / $maxSecretRoomMembers',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
              onTap: () => _verifyRoomOwner(context),
            );
          },
        ),
        const SizedBox(height: 15),
        const Text(
          'المحادثات المخفية داخل الغرفة:',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                tileColor: Colors.grey[900]?.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Colors.amberAccent,
                  child: Icon(Icons.vpn_key, color: Colors.black),
                ),
                title: const Text(
                  'الغرفة السوداء (Shadow Ops)',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'آخر رسالة: تم تأمين التردد بنجاح...',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.lock,
                  color: Color(0xFF00FF66),
                  size: 18,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BlackRoomScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRoomMembersDialog(BuildContext context) {
    final User? owner = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (dialogContext) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: owner == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(owner.uid)
                      .collection(contactsCollectionName(ContactScope.room))
                      .orderBy('createdAt')
                      .snapshots(),
            builder: (context, contactsSnapshot) =>
                ValueListenableBuilder<List<String>>(
                  valueListenable: secretRoomMembersNotifier,
                  builder: (context, members, child) {
                    final contacts = contactsSnapshot.data?.docs ?? [];
                    final currentMemberCount = members.length;
                    final availableContacts = contacts
                        .where((contact) => !members.contains(contact.id))
                        .toList();
                    return AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: Text(
                        'أعضاء الغرفة (${members.length}/$maxSecretRoomMembers)',
                        style: const TextStyle(color: Colors.white),
                      ),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: isSecretRoomAtCapacity(currentMemberCount)
                            ? const Text(
                                'تم الوصول إلى الحد الأقصى: تم توصيل 100 عضو في الغرفة السرية. لا يمكن إضافة أعضاء جدد فعليًا.',
                                style: TextStyle(color: Colors.white70),
                              )
                            : availableContacts.isEmpty
                            ? const Text(
                                'أضف جهات اتصال أولًا من زر البصمة.',
                                style: TextStyle(color: Colors.white70),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: availableContacts.length,
                                itemBuilder: (context, index) {
                                  final contact = availableContacts[index];
                                  final data = contact.data();
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.person_add,
                                      color: Color(0xFF00FF66),
                                    ),
                                    title: Text(
                                      data['displayName'] ?? 'جهة اتصال',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      contact.id,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    onTap: () async {
                                      final memberCount = await countRoomMembers('secret_room');
                                      if (isSecretRoomAtCapacity(memberCount)) {
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            const SnackBar(
                                              content: Text('تم الوصول إلى الحد الأقصى 100 عضو في الغرفة السرية'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      await FirebaseFirestore.instance
                                          .collection('rooms')
                                          .doc('secret_room')
                                          .collection('members')
                                          .doc(contact.id)
                                          .set({
                                            'displayName':
                                                data['displayName'] ??
                                                'جهة اتصال',
                                            'addedBy': owner?.uid,
                                            'addedAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                      await refreshSecretRoomMemberNotifier();
                                      if (dialogContext.mounted)
                                        Navigator.pop(dialogContext);
                                    },
                                  );
                                },
                              ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'إغلاق',
                            style: TextStyle(color: Colors.amberAccent),
                          ),
                        ),
                      ],
                    );
                  },
                ),
          ),
    );
  }

  void _verifyRoomOwner(BuildContext context) {
    final TextEditingController ownerKeyController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'تحقق من المالك',
          style: TextStyle(color: Colors.amberAccent),
        ),
        content: TextField(
          controller: ownerKeyController,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white, letterSpacing: 2),
          decoration: const InputDecoration(
            hintText: 'مفتاح المالك',
            hintStyle: TextStyle(color: Colors.white54),
            prefixIcon: Icon(
              Icons.admin_panel_settings,
              color: Colors.amberAccent,
            ),
          ),
          onSubmitted: (_) =>
              _submitOwnerKey(dialogContext, ownerKeyController),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => _submitOwnerKey(dialogContext, ownerKeyController),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('تحقق'),
          ),
        ],
      ),
    ).then((_) => ownerKeyController.dispose());
  }

  Future<void> _submitOwnerKey(
    BuildContext dialogContext,
    TextEditingController controller,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !firebaseReady) return;
    await loadRoomOwnerKey();
    final enteredKey = controller.text.trim();
    final matchesStoredOwnerKey = await hashPassword(enteredKey) ==
        roomOwnerKeyHashNotifier.value;
    var isConfiguredOwner = false;
    try {
      final ownerSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get();
      isConfiguredOwner = ownerSnapshot.data()?['ownerUid'] == user.uid;
    } catch (error) {
      debugPrint('Room owner verification error: $error');
    }
    if (isConfiguredOwner && matchesStoredOwnerKey) {
      Navigator.pop(dialogContext);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ContactsScreen(
            scope: ContactScope.room,
            ownerVerified: true,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('مفتاح المالك غير صحيح'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

class SecretMembersScreen extends StatefulWidget {
  final String roomId;
  final String title;

  const SecretMembersScreen({
    super.key,
    required this.roomId,
    required this.title,
  });

  @override
  State<SecretMembersScreen> createState() => _SecretMembersScreenState();
}

class _SecretMembersScreenState extends State<SecretMembersScreen> {
  DateTime? _accessStartedAt;
  bool _ownerVerifiedForRoom = false;

  bool get _isSecretRoom => widget.roomId == 'secret_room';
  bool get _isSecretGroup => widget.roomId == 'secret_group';

  Future<void> _verifyRoomOwnerForRemoval() async {
    if (!_isSecretRoom) return;

    final TextEditingController ownerKeyController = TextEditingController();
    final bool? verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'تحقق من مالك الغرفة',
          style: TextStyle(color: Colors.amberAccent),
        ),
        content: TextField(
          controller: ownerKeyController,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white, letterSpacing: 2),
          decoration: const InputDecoration(
            hintText: 'مفتاح المالك',
            hintStyle: TextStyle(color: Colors.white54),
            prefixIcon: Icon(
              Icons.admin_panel_settings,
              color: Colors.amberAccent,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              final enteredKey = ownerKeyController.text.trim();
              if (user == null) {
                Navigator.pop(dialogContext, false);
                return;
              }
                await loadRoomOwnerKey();
              final matchesStoredOwnerKey = await hashPassword(enteredKey) ==
                  roomOwnerKeyHashNotifier.value;
              bool isConfiguredOwner = false;
              try {
                final ownerSnapshot = await FirebaseFirestore.instance
                    .collection('config')
                    .doc('app')
                    .get();
                isConfiguredOwner = ownerSnapshot.data()?['ownerUid'] == user.uid;
              } catch (error) {
                debugPrint('Room owner verification error: $error');
              }
              if (isConfiguredOwner && matchesStoredOwnerKey) {
                if (mounted) {
                  Navigator.pop(dialogContext, true);
                }
                return;
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('مفتاح المالك غير صحيح'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
              Navigator.pop(dialogContext, false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('تحقق'),
          ),
        ],
      ),
    );

    if (verified == true) {
      setState(() => _ownerVerifiedForRoom = true);
    }
  }

  Future<void> _removeMember(String memberId, String displayName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || memberId.isEmpty) return;
    if (memberId == currentUser.uid) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('members')
          .doc(memberId)
          .delete();

      if (_isSecretRoom) {
        await refreshSecretRoomMemberNotifier();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إزالة $displayName من ${widget.title}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      debugPrint('Failed to remove secret member: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذرت إزالة العضو'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccessStart());
  }

  Future<void> _loadAccessStart() async {
    final startedAt = await ensureSecretAccessStart(widget.roomId);
    if (mounted) {
      setState(() => _accessStartedAt = startedAt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: const Color(0xFF171D26),
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            if (_isSecretRoom)
              IconButton(
                onPressed: _ownerVerifiedForRoom
                    ? null
                    : _verifyRoomOwnerForRemoval,
                icon: Icon(
                  _ownerVerifiedForRoom
                      ? Icons.verified_user
                      : Icons.admin_panel_settings_outlined,
                  color: _ownerVerifiedForRoom
                      ? const Color(0xFF38E8A5)
                      : Colors.amberAccent,
                ),
                tooltip: _ownerVerifiedForRoom
                    ? 'تم التحقق من المالك'
                    : 'إدخال مفتاح المالك للإزالة',
              ),
          ],
        ),
        body: !firebaseReady
            ? const Center(
                child: Text(
                  'حدثت مشكلة، حاول مرة أخرى',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(widget.roomId)
                    .collection('members')
                    .orderBy('addedAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'حدثت مشكلة، حاول مرة أخرى',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF38E8A5),
                      ),
                    );
                  }
                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                  final visibleMembers = snapshot.data!.docs.where((member) {
                    final addedAt = member.data()['addedAt'];
                    if (currentUid != null && member.id == currentUid) {
                      return true;
                    }
                    if (addedAt is! Timestamp) {
                      return false;
                    }
                    if (_accessStartedAt == null) {
                      return true;
                    }
                    return addedAt.toDate().isAfter(_accessStartedAt!);
                  }).toList();

                  if (visibleMembers.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا يوجد أعضاء حتى الآن',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => ListTile(
                      tileColor: const Color(0xFF18231F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF38E8A5),
                        child: Icon(Icons.person, color: Colors.black),
                      ),
                      title: Text(
                        visibleMembers[index].data()['displayName'] ?? 'مجهول الهوية',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'عضو في ${widget.title}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: (() {
                        final memberId = visibleMembers[index].id;
                        final memberName =
                            visibleMembers[index].data()['displayName'] ?? 'مجهول الهوية';
                        final bool canRemoveMember = canRemoveSecretMember(
                          isGroup: _isSecretGroup,
                          ownerVerified: _ownerVerifiedForRoom,
                          isOwnerUser: _ownerVerifiedForRoom,
                        ) && memberId != currentUid;

                        if (!canRemoveMember) {
                          return null;
                        }

                        return IconButton(
                          onPressed: () => _removeMember(memberId, memberName),
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          tooltip: 'إزالة العضو',
                        );
                      })(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ==========================================
// 3. شاشة الشات الجماعي السري (المجموعة السرية الآمنة 🛡️)
// ==========================================
class SecretChatScreen extends StatefulWidget {
  final bool? requirePassword;
  final String chatTitle;

  const SecretChatScreen({
    super.key,
    this.requirePassword,
    this.chatTitle = 'المجموعة السرية الآمنة',
  });

  @override
  State<SecretChatScreen> createState() => _SecretChatScreenState();
}

class BlackRoomScreen extends StatelessWidget {
  const BlackRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SecretChatScreen(
      chatTitle: 'الغرفة السوداء (Shadow Ops)',
      requirePassword: false,
    );
  }
}

class _SecretChatScreenState extends State<SecretChatScreen>
    with SingleTickerProviderStateMixin {
  bool _isUnlocked = false;
  bool _requiresPassword = false;
  bool _isSecretMember = false;
  String? _groupPasswordHash;
  DateTime? _accessStartedAt;
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder _secretVoiceRecorder = AudioRecorder();
  final AudioPlayer _secretAudioPlayer = AudioPlayer();
  bool _isSecretRecording = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _secretMessagesSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _secretMessages = [];

  @override
  void initState() {
    super.initState();
    _requiresPassword = widget.requirePassword ??
        secretGroupLockEnabledNotifier.value;
    _isUnlocked = !_requiresPassword;
    _loadLocalSecretVoiceMessages();
    unawaited(_prepareSecretChat());
    clearHistoryNotifier.addListener(_clearSecretMessages);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _prepareSecretChat() async {
    final roomId = widget.chatTitle.contains('الغرفة السوداء')
        ? 'secret_room'
        : 'secret_group';
    _accessStartedAt = await ensureSecretAccessStart(roomId);
    await _loadSecretMembership();
    await _loadGroupPassword();
    _listenToSecretMessages();
  }

  Future<void> _sendSecretMessage() async {
    final String text = _messageController.text.trim();
    if (text.isNotEmpty) {
      if (!_isSecretMember) {
        await _loadSecretMembership();
      }
      if (!_isSecretMember) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح المجموعة حاليًا، حاول مرة أخرى'),
            ),
          );
        }
        return;
      }
      _messageController.clear();
      if (firebaseReady) {
        await _saveSecretMessage(text);
      } else if (mounted) {
        setState(() {
          _secretMessages.add({
            "sender": "أنت",
            "text": text,
            "isMe": true,
            "time": _formatMessageTime(),
          });
        });
      }
      if (autoDeleteMessagesNotifier.value) {
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) {
            setState(() {
              _secretMessages.removeWhere(
                (message) => message['text'] == text && message['isMe'] == true,
              );
            });
          }
          unawaited(deleteExpiredOwnChatMessages(_secretChatId));
        });
      }
    }
  }

  Future<void> _loadGroupPassword() async {
    if (widget.chatTitle.contains('الغرفة السوداء')) return;
    if (mounted) {
      setState(() {
        _groupPasswordHash = null;
        _requiresPassword = false;
        _isUnlocked = true;
      });
    }
  }

  String get _secretChatId => widget.chatTitle.contains('الغرفة السوداء')
      ? 'shadow_ops'
      : 'secret_group';

  Future<void> _loadSecretMembership() async {
    if (!firebaseReady) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSecretMember = false);
      return;
    }

    try {
      final roomId = widget.chatTitle.contains('الغرفة السوداء')
          ? 'secret_room'
          : 'secret_group';

      if (roomId == 'secret_group') {
        final membershipReference = FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .collection('members')
            .doc(user.uid);
        final membership = await membershipReference.get();
        if (!membership.exists) {
          await membershipReference.set({
            'displayName': 'عضو المجموعة',
            'addedBy': user.uid,
            'addedAt': FieldValue.serverTimestamp(),
          });
        }
        if (mounted) setState(() => _isSecretMember = true);
        return;
      }

      final membership = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(user.uid)
          .get();
      final ownerSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get();
      final isOwner = ownerSnapshot.data()?['ownerUid'] == user.uid;
      if (mounted) {
        setState(() => _isSecretMember = membership.exists || isOwner);
      }
    } catch (error) {
      debugPrint('Secret membership load error: $error');
      if (mounted) {
        setState(
          () => _isSecretMember =
              !widget.chatTitle.contains('الغرفة السوداء'),
        );
      }
    }
  }

  Future<void> _leaveSecretChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171D26),
        title: const Text(
          'تأكيد الخروج',
          style: TextStyle(color: Colors.amberAccent),
        ),
        content: const Text(
          'هل تريد الخروج من هذه المجموعة؟ لن تتمكن من إرسال رسائل حتى تتم إضافتك مرة أخرى.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('خروج', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final roomId = widget.chatTitle.contains('الغرفة السوداء')
        ? 'secret_room'
        : 'secret_group';
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(user.uid)
          .delete();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(
            contactsCollectionName(
              roomId == 'secret_group'
                  ? ContactScope.group
                  : ContactScope.room,
            ),
          )
          .doc(user.uid)
          .delete();

      await _secretMessagesSubscription?.cancel();
      _secretMessagesSubscription = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الخروج من المحادثة بنجاح')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Secret chat leave error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر الخروج الآن، حاول مرة أخرى'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _listenToSecretMessages() {
    if (!firebaseReady) return;
    unawaited(deleteExpiredOwnChatMessages(_secretChatId));
    _secretMessagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(_secretChatId)
        .collection('messages')
      .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final accessStartedAt = _accessStartedAt;
            final messages = snapshot.docs.reversed.map((doc) {
              final data = doc.data();
              final deletedFor = data['deletedFor'];
              final expiresAt = data['expiresAt'];
              if (currentUid != null &&
                  deletedFor is List &&
                  deletedFor.contains(currentUid)) {
                return null;
              }
              if (expiresAt is Timestamp &&
                  expiresAt.compareTo(Timestamp.now()) <= 0) {
                return null;
              }
              final timestamp = data['createdAt'];
              if (accessStartedAt != null &&
                  timestamp is Timestamp &&
                  timestamp.toDate().isBefore(accessStartedAt)) {
                return null;
              }
              final mediaUrl = data['mediaUrl'] as String?;
              final localMediaPath = mediaUrl != null &&
                      mediaUrl.startsWith('local://')
                  ? mediaUrl.substring('local://'.length)
                  : null;
              return {
                'docId': doc.id,
                'sender': data['sender'] ?? 'مستخدم',
                'text': data['text'] ?? '',
                'isMe': data['uid'] == FirebaseAuth.instance.currentUser?.uid,
                'mediaType': data['mediaType'] as String?,
                'mediaFile': localMediaPath == null
                    ? null
                    : XFile(localMediaPath),
                'mediaUrl': localMediaPath == null ? mediaUrl : null,
                'time': timestamp is Timestamp
                    ? _formatTimestamp(timestamp)
                    : _formatMessageTime(),
              };
            }).whereType<Map<String, dynamic>>().toList();
            final localMessages = _secretMessages
                .where((message) => message['docId'] == null)
                .toList();
            setState(() {
              _secretMessages
                ..clear()
                ..addAll(messages)
                ..addAll(localMessages);
            });
          },
          onError: (error) {
            debugPrint('Secret messages listener error: $error');
          },
        );
  }

  Future<String?> _saveSecretMediaLocally(XFile file, String mediaType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final localFile = File(
        '${directory.path}/secret_${mediaType}_${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );
      await localFile.writeAsBytes(await file.readAsBytes());
      return 'local://${localFile.path}';
    } catch (error) {
      debugPrint('Secret media local save error: $error');
      return null;
    }
  }

  String get _localSecretVoiceMessagesKey =>
      'local_secret_voice_messages_$_secretChatId';

  Future<void> _loadLocalSecretVoiceMessages() async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return;
    try {
      final encoded = preferences.getString(_localSecretVoiceMessagesKey);
      if (encoded == null || encoded.isEmpty) return;
      final storedMessages = jsonDecode(encoded);
      if (storedMessages is! List) return;
      for (final item in storedMessages) {
        if (item is! Map || item['path'] is! String) continue;
        final path = item['path'] as String;
        if (!await File(path).exists()) continue;
        _secretMessages.add({
          'sender': 'أنت',
          'text': 'رسالة صوتية 🎙️',
          'isMe': true,
          'time': item['time'] as String? ?? _formatMessageTime(),
          'mediaType': 'audio',
          'mediaFile': XFile(path),
          'mediaUrl': 'local://$path',
        });
      }
    } catch (error) {
      debugPrint('Local secret voice messages load error: $error');
    }
  }

  Future<void> _saveLocalSecretVoiceMessage(String path, String time) async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return;
    try {
      final storedMessages = <Map<String, String>>[];
      final encoded = preferences.getString(_localSecretVoiceMessagesKey);
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map && item['path'] is String) {
              storedMessages.add({
                'path': item['path'] as String,
                'time': item['time'] as String? ?? time,
              });
            }
          }
        }
      }
      if (storedMessages.every((item) => item['path'] != path)) {
        storedMessages.add({'path': path, 'time': time});
      }
      await preferences.setString(
        _localSecretVoiceMessagesKey,
        jsonEncode(storedMessages),
      );
    } catch (error) {
      debugPrint('Local secret voice message save error: $error');
    }
  }

  Future<String?> _uploadSecretMedia(XFile file, String mediaType) async {
    if (!firebaseReady) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final fileName = 'secret_${mediaType}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final uploadTask = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('secret_media')
          .child(mediaType)
          .child(fileName)
          .putFile(File(file.path));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (error) {
      debugPrint('Secret media upload error: $error');
      return null;
    }
  }

  Future<void> _saveSecretMediaMessage(
    String text,
    String mediaType,
    String? mediaUrl,
  ) async {
    if (!firebaseReady || mediaUrl == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_secretChatId)
          .collection('messages')
          .add({
            'sender': 'أنت',
            'text': text,
            'uid': user.uid,
            'deletedFor': <String>[],
            'mediaType': mediaType,
            'mediaUrl': mediaUrl,
            'createdAt': FieldValue.serverTimestamp(),
            if (autoDeleteMessagesNotifier.value)
              'expiresAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(seconds: 8)),
              ),
          });
    } catch (error) {
      debugPrint('Secret media save error: $error');
    }
  }

  Future<void> _toggleSecretVoiceRecording() async {
    if (_isSecretRecording) {
      try {
        final path = await _secretVoiceRecorder.stop();
        if (!mounted) return;
        setState(() => _isSecretRecording = false);
        if (path == null || path.isEmpty) return;

        final voiceFile = XFile(path);
        final localPath = await _saveSecretMediaLocally(voiceFile, 'audio');
        final messageTime = _formatMessageTime();
        final secretMsg = {
          'sender': 'أنت',
          'text': 'رسالة صوتية 🎙️',
          'isMe': true,
          'time': messageTime,
          'mediaType': 'audio',
          'mediaFile': voiceFile,
          'mediaUrl': localPath,
        };

        if (mounted) {
          setState(() => _secretMessages.add(secretMsg));
        }

        String? remoteUrl;
        if (firebaseReady) {
          remoteUrl = await _uploadSecretMedia(voiceFile, 'audio');
          if (remoteUrl != null && mounted) {
            setState(() {
              final last = _secretMessages.isNotEmpty ? _secretMessages.last : null;
              if (last != null) {
                last['mediaUrl'] = remoteUrl;
              }
            });
          }
        }

        if (remoteUrl == null && localPath != null) {
          await _saveLocalSecretVoiceMessage(path, messageTime);
        }
        if (remoteUrl != null) {
          await _saveSecretMediaMessage('رسالة صوتية 🎙️', 'audio', remoteUrl);
        }
      } catch (error) {
        debugPrint('Secret voice recording stop error: $error');
        if (mounted) {
          setState(() => _isSecretRecording = false);
        }
      }
      return;
    }

    try {
      final hasPermission = await _secretVoiceRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'shadow_secret_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${directory.path}/$fileName';
      await _secretVoiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: filePath,
      );
      if (mounted) setState(() => _isSecretRecording = true);
    } catch (error) {
      debugPrint('Secret voice recording start error: $error');
    }
  }

  Future<void> _playSecretAudio(Map<String, dynamic> msg) async {
    final mediaUrl = msg['mediaUrl'] as String?;
    final mediaFile = msg['mediaFile'] as XFile?;
    try {
      await _secretAudioPlayer.stop();
      if (mediaFile != null) {
        await _secretAudioPlayer.play(DeviceFileSource(mediaFile.path));
      } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
        if (mediaUrl.startsWith('local://')) {
          final localFile = File(mediaUrl.substring('local://'.length));
          if (await localFile.exists()) {
            await _secretAudioPlayer.play(DeviceFileSource(localFile.path));
            return;
          }
        }
        await _secretAudioPlayer.play(UrlSource(mediaUrl));
      }
    } catch (error) {
      debugPrint('Secret audio playback error: $error');
    }
  }

  Future<void> _saveSecretMessage(String text) async {
    if (!firebaseReady) {
      debugPrint('Secret message save skipped: Firebase not ready');
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_secretChatId)
          .collection('messages')
          .add({
            'sender': 'أنت',
            'text': text,
            'uid': user?.uid,
            'deletedFor': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            if (autoDeleteMessagesNotifier.value)
              'expiresAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(seconds: 8)),
              ),
          });
    } catch (error) {
      debugPrint('Secret message save error: $error');
      if (mounted) {
        showGenericFailureSnackBar(context);
      }
    }
  }

  Future<void> _deleteSecretMessage(
    Map<String, dynamic> message, {
    required bool forEveryone,
  }) async {
    final docId = message['docId'];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (docId is! String || !firebaseReady) {
      await _deleteSecretMedia(message, remote: false);
      if (mounted) {
        setState(() => _secretMessages.remove(message));
      }
      return;
    }
    if (forEveryone && message['isMe'] != true) {
      return;
    }

    final reference = FirebaseFirestore.instance
        .collection('chats')
        .doc(_secretChatId)
        .collection('messages')
        .doc(docId);
    try {
      if (forEveryone && message['isMe'] == true) {
        await reference.delete();
        await _deleteSecretMedia(message, remote: true);
      } else {
        await reference.update({
          'deletedFor': FieldValue.arrayUnion([user.uid]),
        });
        await _deleteSecretMedia(message, remote: false);
      }
      if (mounted) {
        setState(() {
          _secretMessages.removeWhere((item) => item['docId'] == docId);
        });
      }
    } catch (error) {
      debugPrint('Secret message delete error: $error');
    }
  }

  Future<void> _deleteSecretMedia(
    Map<String, dynamic> message, {
    required bool remote,
  }) async {
    final mediaFile = message['mediaFile'] as XFile?;
    if (mediaFile != null) {
      try {
        final localFile = File(mediaFile.path);
        if (await localFile.exists()) await localFile.delete();
      } catch (error) {
        debugPrint('Secret local media delete error: $error');
      }
    }
    final mediaUrl = message['mediaUrl'] as String?;
    if (!remote || mediaUrl == null || mediaUrl.isEmpty) return;
    try {
      await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
    } catch (error) {
      debugPrint('Secret Firebase media delete error: $error');
    }
  }

  Future<void> _showSecretMessageActions(Map<String, dynamic> message) async {
    final deleteMode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF18231F),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white),
              title: const Text(
                'حذف لدي',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, 'mine'),
            ),
            if (message['isMe'] == true && message['docId'] is String)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'حذف لدى الجميع',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.pop(sheetContext, 'everyone'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || deleteMode == null) return;
    if (deleteMode == 'everyone' && message['docId'] is String) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف لدى الجميع'),
          content: const Text(
            'سيتم حذف الرسالة والوسائط المرتبطة بها من Firebase لدى جميع المشاركين.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف للجميع'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _deleteSecretMessage(
      message,
      forEveryone: deleteMode == 'everyone',
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showGroupContactDialog() {
    final User? owner = FirebaseAuth.instance.currentUser;
    if (!firebaseReady || owner == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: owner == null
                ? null
                : FirebaseFirestore.instance
                      .collection('publicProfiles')
                      .snapshots(),
            builder: (context, snapshot) {
              final contacts = (snapshot.data?.docs ?? [])
                  .where((contact) => contact.id != owner.uid)
                  .toList();
              return AlertDialog(
                backgroundColor: const Color(0xFF101B18),
                title: const Text(
                  'إضافة شخص للمجموعة',
                  style: TextStyle(color: Colors.white),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: contacts.isEmpty
                      ? const Text(
                          'لا يوجد مستخدمون آخرون مسجلون حاليًا.',
                          style: TextStyle(color: Colors.white70),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final data = contacts[index].data();
                            return ListTile(
                              leading: const Icon(
                                Icons.person_add,
                                color: Color(0xFFFFD76A),
                              ),
                              title: Text(
                                data['displayName'] ?? 'جهة اتصال',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                contacts[index].id,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              onTap: () async {
                                await FirebaseFirestore.instance
                                    .collection('rooms')
                                    .doc('secret_group')
                                    .collection('members')
                                    .doc(contacts[index].id)
                                    .set({
                                      'displayName':
                                          data['displayName'] ?? 'جهة اتصال',
                                      'addedBy': owner?.uid,
                                      'addedAt': FieldValue.serverTimestamp(),
                                    });
                                if (dialogContext.mounted)
                                  Navigator.pop(dialogContext);
                              },
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'إغلاق',
                      style: TextStyle(color: Colors.amberAccent),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  String _firebaseUnavailableMessage() {
    return 'حدثت مشكلة، حاول مرة أخرى';
  }

  String _formatMessageTime() {
    final DateTime now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _secretMessagesSubscription?.cancel();
    clearHistoryNotifier.removeListener(_clearSecretMessages);
    _pulseController.dispose();
    _passController.dispose();
    _messageController.dispose();
    unawaited(_secretVoiceRecorder.stop());
    unawaited(_secretAudioPlayer.stop());
    _secretVoiceRecorder.dispose();
    _secretAudioPlayer.dispose();
    super.dispose();
  }

  void _clearSecretMessages() {
    if (mounted) setState(_secretMessages.clear);
  }

  @override
  Widget build(BuildContext context) {
    return _isUnlocked ? _buildChatInterface() : _buildPasswordInterface();
  }

  // 1. واجهة الباسورد (العنوان في المنتصف والقفل على الشمال)
  Widget _buildPasswordInterface() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          centerTitle: true, // جعل العنوان في المنتصف
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.chatTitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 18),
            ],
          ),
          backgroundColor: const Color(0xFF121212),
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.amberAccent),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amberAccent.withOpacity(0.08),
                      border: Border.all(color: Colors.amberAccent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amberAccent.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.amberAccent,
                      size: 55,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  widget.chatTitle.contains('الغرفة السوداء')
                      ? 'غرفة Shadow Ops'
                      : 'المجموعة السرية الآمنة',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.chatTitle.contains('الغرفة السوداء')
                      ? 'قناة خاصة ومحمية - أدخل مفتاح التشفير'
                      : 'منطقة مقيدة أمنياً - أدخل مفتاح التشفير',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 40),
                Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: TextField(
                    controller: _passController,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••••••••',
                      hintStyle: TextStyle(color: Colors.grey[700]),
                      filled: true,
                      fillColor: const Color(0xFF141414),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Colors.amberAccent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      shadowColor: Colors.amberAccent.withOpacity(0.5),
                    ),
                    onPressed: () async {
                      final enteredHash =
                          await hashPassword(_passController.text.trim());
                      if (_groupPasswordHash != null &&
                          enteredHash == _groupPasswordHash) {
                        setState(() => _isUnlocked = true);
                        await _loadSecretMembership();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'الكود غير صحيح! حاول مجدداً',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'فك التشفير والدخول',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2. واجهة الشات الجماعي السري
  Widget _buildChatInterface() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.chatTitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF38E8A5),
                size: 20,
              ),
            ],
          ),
          backgroundColor: const Color(0xFF171D26),
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFF3A4655)),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF38E8A5)),
          actions: [
            IconButton(
              icon: const Icon(Icons.groups_rounded),
              tooltip: 'أعضاء المحادثة السرية',
              onPressed: () {
                final isBlackRoom = widget.chatTitle.contains('الغرفة السوداء');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SecretMembersScreen(
                      roomId: isBlackRoom ? 'secret_room' : 'secret_group',
                      title: isBlackRoom ? 'أعضاء الغرفة' : 'أعضاء المجموعة',
                    ),
                  ),
                );
              },
            ),
            if (!widget.chatTitle.contains('الغرفة السوداء'))
              IconButton(
                icon: const Icon(
                  Icons.person_add_alt_1,
                  color: Color(0xFFFFD76A),
                ),
                tooltip: 'إضافة جهة اتصال للمجموعة',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ContactsScreen(scope: ContactScope.group),
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'الخروج من المحادثة',
              onPressed: _leaveSecretChat,
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1117), Color(0xFF111A1D)],
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2930),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF61E7C0).withOpacity(0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF38E8A5),
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.chatTitle.contains('الغرفة السوداء')
                            ? 'قناة Shadow Ops الخاصة'
                            : 'اتصال مشفّر داخل المجموعة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Text(
                      'متصل الآن',
                      style: TextStyle(color: Color(0xFF38E8A5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(14, 4, 14, 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.amberAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.chatTitle.contains('الغرفة السوداء')
                            ? 'أهلاً بك في غرفة Shadow Ops · الرسائل مشفرة'
                            : 'أهلاً بك في المجموعة السرية · الرسائل مشفرة',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _secretMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _secretMessages[index];
                    final bool isMe = msg["isMe"]!;

                    if (msg["mediaType"] == 'audio') {
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => _playSecretAudio(msg),
                          onLongPress: () => _showSecretMessageActions(msg),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF176B59)
                                  : const Color(0xFF202733),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isMe
                                    ? const Color(0xFF38E8A5).withOpacity(0.7)
                                    : const Color(0xFF718096).withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: Color(0xFF00FF66),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'رسالة صوتية 🎙️',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final isWelcomeMsg = !isMe &&
                        (msg["text"].toString().contains(
                              "أهلاً بك في المجموعة السرية الآمنة",
                            ) ||
                            msg["text"].toString().contains(
                              "أهلاً بك في غرفة Shadow Ops",
                            ));
                    if (isWelcomeMsg) return const SizedBox.shrink();

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showSecretMessageActions(msg),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            minWidth: 76,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF176B59)
                                  : const Color(0xFF202733),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 5),
                                bottomRight: Radius.circular(isMe ? 5 : 18),
                              ),
                              border: Border.all(
                                color: isMe
                                    ? const Color(0xFF38E8A5).withOpacity(0.7)
                                    : const Color(0xFF718096).withOpacity(0.45),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isMe
                                          ? Icons.account_circle
                                          : Icons.shield_rounded,
                                      color: isMe
                                          ? const Color(0xFF8FFFD0)
                                          : const Color(0xFFFFD76A),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      msg["sender"]!,
                                      style: TextStyle(
                                        color: isMe
                                            ? const Color(0xFF8FFFD0)
                                            : const Color(0xFFFFD76A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  msg["text"]!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  softWrap: true,
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: AlignmentDirectional.bottomEnd,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg["time"] ?? _formatMessageTime(),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.done_all_rounded,
                                          size: 14,
                                          color: Color(0xFFB5E7D2),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },

                ),
              ),

              Container(
                margin: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF18231F).withOpacity(0.98),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF38E8A5).withOpacity(0.45),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          hintText: 'اكتب رسالتك السرية...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendSecretMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isSecretRecording
                            ? Icons.stop_circle_rounded
                            : Icons.mic_none_rounded,
                        color: _isSecretRecording
                            ? Colors.redAccent
                            : const Color(0xFF38E8A5),
                      ),
                      tooltip: _isSecretRecording ? 'إيقاف التسجيل' : 'تسجيل رسالة صوتية',
                      onPressed: _toggleSecretVoiceRecording,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFF38E8A5),
                      ),
                      onPressed: _sendSecretMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. إعدادات النظام وشاشات التطبيق
