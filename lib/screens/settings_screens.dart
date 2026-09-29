part of '../main.dart';

// ==========================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: englishLanguageNotifier.value
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'إعدادات النظام',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF0B1D19) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
          centerTitle: true,
        ),
        body: ListView(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: englishLanguageNotifier,
              builder: (context, isEnglish, child) {
                return ListTile(
                  leading: Icon(
                    Icons.language,
                    color: isDark ? Colors.cyanAccent : Colors.black,
                  ),
                  title: Text(
                    isEnglish ? 'Language' : 'اللغة',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    isEnglish ? 'Choose the app language' : 'اختار لغة التطبيق',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: DropdownButton<bool>(
                    value: isEnglish,
                    dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: false,
                        child: Text(
                          'العربية',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(
                          'English',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) englishLanguageNotifier.value = value;
                    },
                  ),
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              leading: Icon(
                Icons.folder_special,
                color: isDark ? const Color(0xFF00FF66) : Colors.black,
              ),
              title: Text(
                'الإعدادات المتغيرة',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'تحكم في الحركة، الصوت، والتشفير التلقائي',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DynamicSettingsScreen(),
                  ),
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              leading: Icon(
                Icons.security,
                color: isDark ? Colors.cyanAccent : Colors.black,
              ),
              title: Text(
                'الخصوصية والأمان',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'الوضع الخفي، قفل التطبيق، وحذف السجل',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacySettingsScreen(),
                  ),
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              leading: Icon(
                Icons.account_circle,
                color: isDark ? const Color(0xFF38E8A5) : Colors.black,
              ),
              title: Text(
                'الحساب والمظهر',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'الملف الشخصي وتخصيص المظهر والألوان',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountAndThemeScreen(),
                  ),
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              leading: Icon(
                Icons.notifications_active,
                color: isDark ? Colors.pinkAccent : Colors.black,
              ),
              title: Text(
                'الإشعارات والأصوات',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'تخصيص نغمات التنبيه والاهتزاز',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: isDark ? Colors.blueAccent : Colors.black,
              ),
              title: Text(
                'حول التطبيق',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Shadow Chat BETA v1.0.0-beta.1 ومعلومات المبرمج',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutAppScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DynamicSettingsScreen extends StatelessWidget {
  const DynamicSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'الإعدادات المتغيرة',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: isDark ? Colors.white : Colors.black,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
          centerTitle: true,
        ),
        body: ListView(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: whaleMotionNotifier,
              builder: (context, isMoving, child) {
                return SwitchListTile(
                  secondary: Icon(
                    Icons.waves,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.cyanAccent
                        : Colors.black,
                  ),
                  title: Text(
                    'تحريك خلفية الحوت',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'تفعيل أو إيقاف حركة طفو الحوت في الخلفية',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: isMoving,
                  activeColor: isDark ? const Color(0xFF00FF66) : Colors.black,
                  onChanged: (bool value) {
                    whaleMotionNotifier.value = value;
                  },
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ValueListenableBuilder<bool>(
              valueListenable: whaleSoundNotifier,
              builder: (context, isSoundEnabled, child) {
                return SwitchListTile(
                  secondary: Icon(
                    Icons.volume_up,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.pinkAccent
                        : Colors.black,
                  ),
                  title: Text(
                    'صوت ترحيب الحوت',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'تشغيل أو إيقاف المؤثر الصوتي عند فتح الشات',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: isSoundEnabled,
                  activeColor: isDark ? const Color(0xFF00FF66) : Colors.black,
                  onChanged: (bool value) {
                    whaleSoundNotifier.value = value;
                  },
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ValueListenableBuilder<bool>(
              valueListenable: autoEncryptNotifier,
              builder: (context, isAutoEncryptEnabled, child) {
                return SwitchListTile(
                  secondary: Icon(
                    Icons.security,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF00FF66)
                        : Colors.black,
                  ),
                  title: Text(
                    'تشفير الرسائل التلقائي',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'تشفير كل رسالة جديدة فور إرسالها تلقائياً',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: isAutoEncryptEnabled,
                  activeColor: isDark ? const Color(0xFF00FF66) : Colors.black,
                  onChanged: (bool value) {
                    autoEncryptNotifier.value = value;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _appLockEnabled = false;
  bool _ghostModeEnabled = true;
  bool _autoDeleteMessages = false;

  @override
  void initState() {
    super.initState();
    _appLockEnabled = appLockEnabledNotifier.value;
    _ghostModeEnabled = ghostModeNotifier.value;
    _autoDeleteMessages = autoDeleteMessagesNotifier.value;
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final settings = await loadPrivacySettings();
    if (!mounted) return;
    setState(() {
      if (settings['ghostMode'] is bool) {
        _ghostModeEnabled = settings['ghostMode'] as bool;
        ghostModeNotifier.value = _ghostModeEnabled;
      }
      if (settings['autoDeleteMessages'] is bool) {
        _autoDeleteMessages = settings['autoDeleteMessages'] as bool;
        autoDeleteMessagesNotifier.value = _autoDeleteMessages;
      }
      if (settings['messageSound'] is bool) {
        messageSoundNotifier.value = settings['messageSound'] as bool;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الخصوصية والأمان',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.lock,
                color: isDark ? const Color(0xFF00FF66) : Colors.black,
                size: 20,
              ),
            ],
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'حماية التطبيق',
              style: TextStyle(
                color: isDark ? const Color(0xFF00FF66) : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              secondary: Icon(
                Icons.fingerprint,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF63F5C2)
                    : Colors.black,
              ),
              title: Text(
                'قفل التطبيق بالبصمة / كلمة السر',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'طلب التحقق عند فتح Shadow Chat',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              value: _appLockEnabled,
              activeColor: isDark ? const Color(0xFF00FF66) : Colors.black,
              onChanged: (bool value) async {
                if (value) {
                  _setAppLockPassword();
                  return;
                }
                final currentHash = appLockPasswordNotifier.value;
                if (currentHash == null) return;
                await saveAppLockSettings(
                  enabled: false,
                  passwordHash: currentHash,
                );
                if (mounted) setState(() => _appLockEnabled = false);
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: appLockPasswordNotifier,
              builder: (context, passwordHash, child) {
                if (passwordHash == null || !appLockEnabledNotifier.value)
                  return const SizedBox.shrink();
                return ListTile(
                  leading: Icon(
                    Icons.password_rounded,
                    color: isDark ? Colors.amberAccent : Colors.black,
                  ),
                  title: Text(
                    'كلمة سر قفل التطبيق',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'كلمة السر ثابتة ومربوطة بإعدادات Firebase',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                  onTap: () => showChangeAppLockPasswordDialog(context),
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor, height: 30),
            Text(
              'خصوصية المحادثات',
              style: TextStyle(
                color: isDark ? const Color(0xFF00FF66) : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<bool>(
              valueListenable: ghostModeNotifier,
              builder: (context, isGhostModeEnabled, child) {
                return SwitchListTile(
                  secondary: Icon(
                    Icons.visibility_off,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.purpleAccent
                        : Colors.black,
                  ),
                  title: Text(
                    'الوضع الخفي (Ghost Mode)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'إخفاء مؤشر "جاري الكتابة" وحالة الاتصال',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: isGhostModeEnabled,
                  activeColor: isDark ? const Color(0xFF00FF66) : Colors.black,
                  onChanged: (bool value) {
                    ghostModeNotifier.value = value;
                    savePrivacySetting('ghostMode', value);
                    setState(() => _ghostModeEnabled = value);
                  },
                );
              },
            ),
            SwitchListTile(
              secondary: Icon(
                Icons.timer_off,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orangeAccent
                    : Colors.black,
              ),
              title: Text(
                'الرسائل ذاتية التدمير',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'حذف الرسائل تلقائياً بعد قراءتها',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              value: autoDeleteMessagesNotifier.value,
              activeColor: isDark ? const Color(0xFF00FF66) : Colors.black,
              onChanged: (bool value) {
                autoDeleteMessagesNotifier.value = value;
                savePrivacySetting('autoDeleteMessages', value);
                setState(() {
                  _autoDeleteMessages = value;
                });
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: secretGroupLockEnabledNotifier,
              builder: (context, isLocked, child) {
                return SwitchListTile(
                  secondary: Icon(
                    Icons.groups_rounded,
                    color: isDark ? Colors.amberAccent : Colors.black,
                  ),
                  title: Text(
                    'قفل المجموعة السرية',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    isLocked
                        ? 'المجموعة محمية بكلمة سر خاصة بك'
                        : 'المجموعة مفتوحة بدون كلمة سر',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: isLocked,
                  activeColor: isDark ? Colors.amberAccent : Colors.black,
                  onChanged: (value) {
                    if (value) {
                      _showSecretGroupPasswordDialog();
                    } else {
                      unawaited(disableSecretGroupLock());
                    }
                  },
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: secretGroupLockEnabledNotifier,
              builder: (context, isLocked, child) {
                if (!isLocked) return const SizedBox.shrink();
                return ListTile(
                  leading: Icon(
                    Icons.password_rounded,
                    color: isDark ? Colors.amberAccent : Colors.black,
                  ),
                  title: Text(
                    'تغيير كلمة سر المجموعة',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showSecretGroupPasswordDialog(changing: true),
                );
              },
            ),
            Divider(color: Theme.of(context).dividerColor, height: 30),
            const Text(
              'إدارة البيانات',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: Text(
                'حذف سجل المحادثات بالكامل',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'مسح كافة الرسائل المخزنة نهائياً',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () {
                _showDeleteConfirmationDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setAppLockPassword() {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'تفعيل قفل التطبيق',
          style: TextStyle(color: Color(0xFF00FF66)),
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'اكتب كلمة مرورك هنا',
            hintStyle: TextStyle(color: Colors.black),
            filled: true,
            fillColor: Colors.white,
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
              if (password.isEmpty) return;
              if (password.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة السر يجب أن تكون 4 أحرف على الأقل'),
                  ),
                );
                return;
              }
              await saveAppLockSettings(
                enabled: true,
                passwordHash: await hashPassword(password),
              );
              if (!mounted) return;
              setState(() => _appLockEnabled = true);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text(
              'تفعيل',
              style: TextStyle(color: Color(0xFF00FF66)),
            ),
          ),
        ],
      ),
    ).then((_) => passwordController.dispose());
  }

  void _showSecretGroupPasswordDialog({bool changing = false}) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(changing ? 'تغيير كلمة سر المجموعة' : 'قفل المجموعة السرية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (changing)
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة السر الحالية'),
              ),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة السر الجديدة'),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'تأكيد كلمة السر'),
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
              final currentHash = secretGroupPasswordHashNotifier.value;
              final oldPasswordValid = !changing ||
                  (currentHash != null &&
                      await hashPassword(oldController.text.trim()) == currentHash);
              if (!oldPasswordValid ||
                  newPassword.length < 4 ||
                  newPassword != confirmController.text.trim()) {
                debugPrint('Secret group password validation failed');
                return;
              }
              await saveSecretGroupPassword(newPassword);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ).then((_) {
      oldController.dispose();
      newController.dispose();
      confirmController.dispose();
    });
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'تحذير أمني',
              style: TextStyle(color: Colors.redAccent),
            ),
            content: const Text(
              'هل أنت متأكد من حذف جميع سجلات الشات نهائياً؟ لا يمكن التراجع عن هذه الخطوة.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.cyanAccent),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: const Text(
                  'حذف الكل',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onPressed: () async {
                  clearHistoryNotifier.value++;
                  Navigator.of(dialogContext).pop();
                  try {
                    await deleteAllChatHistoryForUser();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف سجل المحادثات من Firebase'),
                        ),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showGenericFailureSnackBar(context);
                    }
                    debugPrint('Full history delete action error: $error');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'الإشعارات والأصوات',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: messageSoundNotifier,
              builder: (context, isSoundEnabled, child) => SwitchListTile(
                secondary: Icon(
                  Icons.music_note,
                  color: isDark ? Colors.pinkAccent : Colors.black,
                ),
                title: Text(
                  'صوت الرسائل الواردة',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                value: isSoundEnabled,
                activeColor: isDark ? const Color(0xFF38E8A5) : Colors.black,
                onChanged: (value) {
                  messageSoundNotifier.value = value;
                  unawaited(savePrivacySetting('messageSound', value));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = true;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text(
            'حول التطبيق',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.black87,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF00FF66) : Colors.black,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF66).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.code,
                  size: 50,
                  color: const Color(0xFF00FF66),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '🌑 SHADOW CHAT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.public, color: Colors.cyanAccent, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'BETA Version v1.0.0-beta.1',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Divider(color: Colors.white24, thickness: 1),
              ),
              const Text(
                'من خلف الظل:',
                style: TextStyle(color: Color(0xFF00FF66), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Eng. Hatem',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.public, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 4),
                  Text('✨', style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF66).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00FF66).withOpacity(0.5),
                  ),
                ),
                child: const Text(
                  '« مساحة خاصة »',
                  style: TextStyle(
                    color: Color(0xFF00FF66),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'مساحة هادئة للمحادثات الخاصة بعيداً عن الضوضاء.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
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
// 5. شاشة الشات العادية (بدون AppBar - عائمة في الماء)
