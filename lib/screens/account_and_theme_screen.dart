part of '../main.dart';

class AccountAndThemeScreen extends StatefulWidget {
  const AccountAndThemeScreen({super.key});

  @override
  State<AccountAndThemeScreen> createState() => _AccountAndThemeScreenState();
}

class _AccountAndThemeScreenState extends State<AccountAndThemeScreen> {
  String userName = "Shadow User";
  late TextEditingController nameController;
  final ImagePicker _picker = ImagePicker();
  String? _linkedPhoneNumber;
  bool _isLinkingPhone = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: userName);
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Selected profile image is empty');
      }
      userProfileImageNotifier.value = image;
      userProfileImageBytesNotifier.value = bytes;
      await _saveLocalProfileImage(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الصورة على الجهاز فقط')),
        );
      }
    } catch (error) {
      debugPrint('Profile image pick error: $error');
      debugPrint('Profile image selection failed');
    }
  }

  Future<void> _saveLocalProfileImage(Uint8List bytes) async {
    try {
      final preferences = await getSafeSharedPreferences();
      if (preferences == null) return;
      final userKey = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      await preferences.setString(
        'profile_image_base64_$userKey',
        base64Encode(bytes),
      );
    } catch (error) {
      debugPrint('Local profile image save error: $error');
    }
  }

  Future<void> _loadLocalProfileImage() async {
    try {
      final preferences = await getSafeSharedPreferences();
      if (preferences == null) return;
      final userKey = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final encodedImage = preferences.getString('profile_image_base64_$userKey');
      if (encodedImage != null && encodedImage.isNotEmpty) {
        final bytes = base64Decode(encodedImage);
        if (bytes.isNotEmpty) {
          userProfileImageBytesNotifier.value = bytes;
        }
      }
    } catch (error) {
      debugPrint('Local profile image load error: $error');
    }
  }

  Future<void> _loadProfile() async {
    await _loadLocalProfileImage();
    final initialUser = FirebaseAuth.instance.currentUser;
    User? user = initialUser;
    if (!firebaseReady || user == null) return;
    try {
      await user.reload().timeout(const Duration(seconds: 10));
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return;
      final data =
          (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(refreshedUser.uid)
                  .get()
                  .timeout(const Duration(seconds: 10)))
              .data();
      if (mounted) {
        setState(() {
          userName = data?['displayName'] as String? ?? userName;
          _linkedPhoneNumber = refreshedUser.phoneNumber;
          nameController.text = userName;
        });
      }
    } catch (error) {
      debugPrint('Profile load error: $error');
    }
  }

  void _showProfileImageViewer() {
    final imageBytes = userProfileImageBytesNotifier.value;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                      )
                    : Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFF101716),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 110,
                          color: Color(0xFF00FF66),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveLocalPhoneNumber(String phone) async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return;
    await preferences.setString('local_linked_phone_number', phone);
  }

  Future<String?> _loadLocalPhoneNumber() async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return null;
    final value = preferences.getString('local_linked_phone_number');
    return value != null && value.isNotEmpty ? value : null;
  }

  Future<void> _linkPhoneNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    final existingLocalPhone = await _loadLocalPhoneNumber();
    if (user != null && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الهاتف مرتبط بهذا الحساب بالفعل')),
      );
      return;
    }
    if (existingLocalPhone != null && existingLocalPhone.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الهاتف محجوز على الجهاز بالفعل')),
      );
      return;
    }

    final phoneController = TextEditingController();
    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ربط رقم الهاتف'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          autofocus: true,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'رقم الهاتف',
            hintText: '+201xxxxxxxxx',
            prefixIcon: Icon(Icons.phone_android),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = phoneController.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('حفظ محليًا'),
          ),
        ],
      ),
    );
    phoneController.dispose();
    if (!mounted || phoneNumber == null || phoneNumber.isEmpty) return;
    final normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    if (!normalizedPhoneNumber.startsWith('+') ||
        normalizedPhoneNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتب رقم الهاتف بالصيغة الدولية مثل +201xxxxxxxxx'),
        ),
      );
      return;
    }

    setState(() => _isLinkingPhone = true);
    try {
      await _saveLocalPhoneNumber(normalizedPhoneNumber);
      setState(() {
        _linkedPhoneNumber = normalizedPhoneNumber;
        _isLinkingPhone = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ رقم الهاتف على الجهاز فقط')),
        );
      }
    } catch (error) {
      debugPrint('Local phone link save error: $error');
      if (mounted) {
        setState(() => _isLinkingPhone = false);
      }
    }
  }

  Future<void> _finishPhoneLink(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');
      final linkedUser = (await user.linkWithCredential(credential)).user;
      if (linkedUser == null || linkedUser.phoneNumber == null) {
        throw FirebaseAuthException(code: 'phone-link-failed');
      }
      await FirebaseFirestore.instance.collection('users').doc(linkedUser.uid).set({
        'phoneNumber': normalizePhoneNumber(linkedUser.phoneNumber!),
        'phoneSearchKey': _phoneSearchKey(linkedUser.phoneNumber!),
        'phoneLinked': true,
        'phoneUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(linkedUser.uid)
          .set({
            'uid': linkedUser.uid,
            'phoneNumber': normalizePhoneNumber(linkedUser.phoneNumber!),
            'phoneSearchKey': _phoneSearchKey(linkedUser.phoneNumber!),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _linkedPhoneNumber = linkedUser.phoneNumber;
        _isLinkingPhone = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التحقق من الرقم وربطه بحساب Firebase')),
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('Phone credential link failed: ${error.code}');
      if (!mounted) return;
      setState(() => _isLinkingPhone = false);
    } catch (error) {
      debugPrint('Unexpected phone credential link error: $error');
      if (!mounted) return;
      setState(() => _isLinkingPhone = false);
    }
  }

  String _phoneAuthErrorMessage(Object error) {
    return 'حدثت مشكلة، حاول مرة أخرى';
  }

  void _showEditNameDialog() {
    nameController.text = userName;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: ValueListenableBuilder<bool>(
          valueListenable: globalDarkModeNotifier,
          builder: (context, isDark, child) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFF00FF66), width: 1.5),
              ),
              title: Row(
                children: const [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "تعديل اسم المستخدم",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              titleTextStyle: TextStyle(
                color: isDark ? const Color(0xFF00FF66) : Colors.black,
              ),
              content: TextField(
                controller: nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "أدخل الاسم الجديد",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF66)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF66), width: 2),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF66),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final nextName = sanitizeDisplayName(nameController.text);
                    if (nextName.isNotEmpty) {
                      setState(() {
                        userName = nextName;
                      });
                      if (firebaseReady) {
                        await syncUserDisplayNameAcrossApp(nextName);
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    "حفظ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalDarkModeNotifier,
      builder: (context, isDark, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 20,
                    color: isDark ? const Color(0xFF38E8A5) : Colors.black,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "الحساب والمظهر",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: isDark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFE2E7EC),
              foregroundColor: isDark ? Colors.white : Colors.black,
              elevation: 0,
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A1A), const Color(0xFF000000)]
                      : [const Color(0xFFF4F6F9), const Color(0xFFE4E8EE)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.hardEdge,
                          child: InkWell(
                            onTap: () {
                              if (userProfileImageBytesNotifier.value != null) {
                                _showProfileImageViewer();
                              } else {
                                _pickProfileImage();
                              }
                            },
                            child: ValueListenableBuilder<XFile?>(
                              valueListenable: userProfileImageNotifier,
                              builder: (context, profileImg, child) {
                                return ValueListenableBuilder<Uint8List?>(
                                  valueListenable:
                                      userProfileImageBytesNotifier,
                                  builder: (context, imageBytes, child) =>
                                      CircleAvatar(
                                        radius: 62,
                                        backgroundColor: isDark
                                            ? const Color(0xFF00FF66)
                                            : Colors.black,
                                        child: CircleAvatar(
                                          radius: 56,
                                          backgroundColor: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          child: imageBytes != null
                                              ? ClipOval(
                                                  child: Image.memory(
                                                    imageBytes,
                                                    width: 112,
                                                    height: 112,
                                                    fit: BoxFit.cover,
                                                        errorBuilder: (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => Icon(
                                                          Icons.person,
                                                          size: 65,
                                                          color: isDark
                                                              ? const Color(0xFF00FF66)
                                                              : Colors.black54,
                                                        ),
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.person,
                                                  size: 65,
                                                  color: isDark
                                                      ? const Color(0xFF00FF66)
                                                      : Colors.black54,
                                                ),
                                        ),
                                      ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Material(
                            color: isDark
                                ? const Color(0xFF00FF66)
                                : Colors.black,
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: _pickProfileImage,
                              tooltip: 'تغيير الصورة الشخصية',
                              icon: Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Center(
                    child: Text(
                      userName,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: isDark ? const Color(0xFF38E8A5) : Colors.black,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "إعدادات الحساب والمظهر",
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF00FF66)
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.add_a_photo_rounded,
                            color: isDark
                                ? const Color(0xFF00FF66)
                                : Colors.black,
                          ),
                          title: Text(
                            'تغيير الصورة الشخصية',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'اختيار صورة جديدة من الجهاز',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: _pickProfileImage,
                        ),
                        Divider(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          height: 1,
                          indent: 15,
                          endIndent: 15,
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.edit_rounded,
                            color: isDark
                                ? const Color(0xFF00FF66)
                                : Colors.black,
                          ),
                          title: Text(
                            "تعديل اسم المستخدم",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: _showEditNameDialog,
                        ),
                        Divider(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          height: 1,
                          indent: 15,
                          endIndent: 15,
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.phone_android_rounded,
                            color: isDark
                                ? const Color(0xFF38E8A5)
                                : Colors.black,
                          ),
                          title: Text(
                            'ربط رقم الهاتف',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _linkedPhoneNumber == null
                                ? 'أضف رقمك لتسهيل العثور عليك من جهات الاتصال'
                                : 'مرتبط: $_linkedPhoneNumber',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: _isLinkingPhone
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  _linkedPhoneNumber == null
                                      ? Icons.arrow_forward_ios_rounded
                                      : Icons.verified_rounded,
                                  size: 18,
                                  color: _linkedPhoneNumber == null
                                      ? Colors.grey
                                      : const Color(0xFF38E8A5),
                                ),
                          onTap: _isLinkingPhone || _linkedPhoneNumber != null
                              ? null
                              : _linkPhoneNumber,
                        ),
                        Divider(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          height: 1,
                          indent: 15,
                          endIndent: 15,
                        ),
                        SwitchListTile(
                          secondary: Icon(
                            isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: isDark
                                ? const Color(0xFF00FF66)
                                : Colors.black,
                          ),
                          title: Text(
                            "الوضع المظلم (Dark Mode)",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            isDark
                                ? "التطبيق يعمل بالوضع المظلم حالياً"
                                : "التطبيق يعمل بالوضع الهادئ المريح",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black,
                              fontSize: 12,
                            ),
                          ),
                          value: isDark,
                          activeColor: isDark
                              ? const Color(0xFF00FF66)
                              : Colors.black,
                          onChanged: (bool value) {
                            saveDarkModeSetting(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
