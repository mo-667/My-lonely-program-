part of '../main.dart';

// ==========================================
class _VideoMessagePlayer extends StatefulWidget {
  final XFile? mediaFile;
  final String? mediaUrl;

  const _VideoMessagePlayer({this.mediaFile, this.mediaUrl});

  @override
  State<_VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<_VideoMessagePlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = widget.mediaFile != null
        ? VideoPlayerController.file(File(widget.mediaFile!.path))
        : widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty
        ? VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl!))
        : null;
    if (controller == null) return;
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Video message playback error: $error');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final mediaWidth = MediaQuery.sizeOf(context).width < 600
        ? MediaQuery.sizeOf(context).width * 0.72
        : 340.0;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        width: mediaWidth,
        height: mediaWidth * 0.62,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: mediaWidth,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          IconButton(
            iconSize: 52,
            color: Colors.white,
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
            ),
            onPressed: () {
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
          ),
        ],
      ),
    );
  }
}

class Message {
  final String originalText;
  final String encryptedData; // هنحفظ هنا النص المتشفر بجد
  bool isEncrypted;
  final bool isMe;
  final String? firestoreId;
  final String? time;
  final String? mediaType;
  final XFile? mediaFile;
  final String? mediaUrl;

  Duration? voiceDuration;
  bool isPlayingVoice;
  Duration currentPlaybackPosition;

  Message({
    required this.originalText,
    required this.encryptedData,
    required this.isMe,
    this.firestoreId,
    this.time,
    this.isEncrypted = false,
    this.mediaType,
    this.mediaFile,
    this.mediaUrl,
    this.voiceDuration,
    this.isPlayingVoice = false,
    this.currentPlaybackPosition = Duration.zero,
  });

  String get displayText {
    if (!isEncrypted) return originalText;
    // الشكل السري الغامض (المربعات) مع الحفاظ على التشفير الحقيقي جواه
    return encryptedData.replaceAll(RegExp(r'[^\s]'), '█');
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path()..moveTo(22, 0);
    path.quadraticBezierTo(size.width * 0.25, 8, size.width * 0.42, 0);
    path.quadraticBezierTo(size.width * 0.58, -8, size.width * 0.74, 0);
    path.quadraticBezierTo(size.width * 0.9, 8, size.width - 22, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 22);
    path.lineTo(size.width, size.height - 22);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - 22,
      size.height,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 8,
      size.width * 0.58,
      size.height,
    );
    path.quadraticBezierTo(
      size.width * 0.42,
      size.height + 8,
      size.width * 0.26,
      size.height,
    );
    path.quadraticBezierTo(8, size.height - 8, 22, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 22);
    path.lineTo(0, 22);
    path.quadraticBezierTo(0, 0, 22, 0);
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ShellBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF00FF66).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(_ShellClipper().getClip(size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingChatButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _FloatingChatButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: color,
        shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 12)],
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _SeaShellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path shell = Path()..moveTo(24, 6);
    shell.quadraticBezierTo(size.width * 0.18, 14, size.width * 0.3, 7);
    shell.quadraticBezierTo(size.width * 0.42, 0, size.width * 0.54, 7);
    shell.quadraticBezierTo(size.width * 0.66, 14, size.width * 0.78, 7);
    shell.quadraticBezierTo(size.width * 0.9, 0, size.width - 24, 6);
    shell.quadraticBezierTo(size.width, 8, size.width - 4, 22);
    shell.lineTo(size.width - 4, size.height - 20);
    shell.quadraticBezierTo(
      size.width - 8,
      size.height - 6,
      size.width - 24,
      size.height - 6,
    );
    shell.quadraticBezierTo(
      size.width * 0.78,
      size.height - 14,
      size.width * 0.66,
      size.height - 6,
    );
    shell.quadraticBezierTo(
      size.width * 0.54,
      size.height + 2,
      size.width * 0.42,
      size.height - 6,
    );
    shell.quadraticBezierTo(
      size.width * 0.3,
      size.height - 14,
      size.width * 0.18,
      size.height - 6,
    );
    shell.quadraticBezierTo(8, size.height - 6, 4, size.height - 20);
    shell.lineTo(4, 22);
    shell.quadraticBezierTo(0, 8, 24, 6);
    shell.close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShellMediaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Rect.fromLTWH(5, 4, size.width - 10, size.height - 8);
    final Paint fill = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF174B38), Color(0xFF0B2119)],
      ).createShader(bounds);
    final Paint outline = Paint()
      ..color = Colors.amberAccent.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final Path shell = Path()
      ..moveTo(7, size.height - 9)
      ..quadraticBezierTo(size.width * 0.16, 5, size.width * 0.5, 6)
      ..quadraticBezierTo(size.width * 0.84, 5, size.width - 7, size.height - 9)
      ..quadraticBezierTo(size.width * 0.5, size.height + 2, 7, size.height - 9)
      ..close();
    canvas.drawPath(shell, fill);
    canvas.drawPath(shell, outline);

    final Paint ridges = Paint()
      ..color = const Color(0x99FFDF75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int index = 1; index < 5; index++) {
      final double x = size.width * index / 5;
      canvas.drawLine(Offset(7, size.height - 10), Offset(x, 8), ridges);
    }
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.58, size.height * 0.55),
        radius: 6,
      ),
      0.4,
      4.8,
      false,
      ridges,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChatScreen extends StatefulWidget {
  final String chatName;
  final String? contactUid;

  const ChatScreen({
    super.key,
    this.chatName = '✨ 🌑 SHADOW CHAT 🌑 ✨',
    this.contactUid,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _chatAudioPlayer = AudioPlayer();
  final AudioPlayer _mediaAudioPlayer = AudioPlayer();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final ImagePicker _mediaPicker = ImagePicker();

  late AnimationController _whaleController;
  late Animation<double> _whaleAnimation;

  late AnimationController _launchController;
  late AnimationController _lockPulseController;
  late Animation<double> _lockPulseAnimation;
  bool _isLaunching = false;
  bool _isRecording = false;
  bool _isOtherTyping = false;
  bool _hasLoadedMessages = false;
  bool _incomingBannerVisible = false;
  Timer? _incomingBannerTimer;
  bool _chatLocked = false;
  bool _directAccessChecked = false;
  bool _directAccessApproved = true;
  String? _chatPassword;
  final TextEditingController _chatPasswordController = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _typingStatusSubscription;
  Timer? _typingStatusTimer;
  bool _isCurrentUserTyping = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? get _contactPresenceStream {
    if (!firebaseReady || widget.contactUid == null) return null;
    return FirebaseFirestore.instance
      .collection('publicProfiles')
        .doc(widget.contactUid)
        .snapshots();
  }

  String _presenceText(Map<String, dynamic>? data) {
    if (data?['ghostMode'] == true) return appText('الحالة مخفية', 'Status hidden');
    final value = data?['lastSeen'] ?? data?['lastSeenAt'];
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate().toLocal();
    } else if (value is DateTime) {
      date = value.toLocal();
    } else if (value is String) {
      date = DateTime.tryParse(value)?.toLocal();
    }
    if (data?['isOnline'] == true &&
        date != null &&
        DateTime.now().difference(date).abs() <= const Duration(minutes: 2)) {
      return 'متصل الآن';
    }
    if (date == null) return 'آخر ظهور غير متاح';
    final localizations = MaterialLocalizations.of(context);
    final formattedDate = localizations.formatShortDate(date);
    final formattedTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );
    return 'آخر ظهور $formattedDate - $formattedTime';
  }

  String _messageTime(dynamic value) {
    final date = value is Timestamp ? value.toDate().toLocal() : DateTime.now();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get _localVoiceMessagesKey => 'local_voice_messages_$_chatId';

  Future<void> _loadLocalVoiceMessages() async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return;
    try {
      final encoded = preferences.getString(_localVoiceMessagesKey);
      if (encoded == null || encoded.isEmpty) return;
      final storedMessages = jsonDecode(encoded);
      if (storedMessages is! List) return;

      final restoredMessages = <Message>[];
      for (final item in storedMessages) {
        if (item is! Map) continue;
        final path = item['path'];
        if (path is! String || !await File(path).exists()) continue;
        restoredMessages.add(
          Message(
            originalText: '🎙️ رسالة صوتية',
            encryptedData: path,
            isMe: true,
            time: item['time'] as String? ?? _messageTime(null),
            mediaType: 'audio',
            mediaFile: XFile(path),
            mediaUrl: 'local://$path',
          ),
        );
      }
      if (mounted && restoredMessages.isNotEmpty) {
        setState(() => _messages.addAll(restoredMessages));
      }
    } catch (error) {
      debugPrint('Local voice messages load error: $error');
    }
  }

  Future<void> _saveLocalVoiceMessage(String path, String time) async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null) return;
    try {
      final storedMessages = <Map<String, String>>[];
      final encoded = preferences.getString(_localVoiceMessagesKey);
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
        _localVoiceMessagesKey,
        jsonEncode(storedMessages),
      );
    } catch (error) {
      debugPrint('Local voice message save error: $error');
    }
  }

  Future<void> _ensureDirectChatAccess() async {
    final contactUid = widget.contactUid;
    if (contactUid == null || contactUid.isEmpty) {
      if (mounted) setState(() => _directAccessChecked = true);
      return;
    }
    final approved = await _hasApprovedDirectContact(contactUid);
    if (approved) {
      if (mounted) {
        setState(() {
          _directAccessApproved = true;
          _directAccessChecked = true;
        });
        _listenToChatMessages();
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _directAccessApproved = false;
      _directAccessChecked = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا يمكنك الدخول إلى هذه الدردشة إلا بعد موافقة الطرف الآخر'),
      ),
    );
    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    if (widget.contactUid != null && widget.contactUid!.isNotEmpty) {
      unawaited(_markDirectChatAsRead(widget.contactUid!));
    }
    clearHistoryNotifier.addListener(_clearChatMessages);
    whaleMotionNotifier.addListener(_onWhaleMotionChanged);
    whaleSoundNotifier.addListener(_onWhaleSoundChanged);
    _chatPassword = chatPasswordsNotifier.value[widget.chatName];
    _chatLocked = _chatPassword != null;
    _loadChatPassword();
    _loadLocalVoiceMessages();
    if (widget.contactUid != null && widget.contactUid!.isNotEmpty) {
      unawaited(_ensureDirectChatAccess());
    } else {
      _directAccessChecked = true;
      _listenToChatMessages();
    }
    _setupTypingListener();
    _whaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (whaleMotionNotifier.value) {
      _whaleController.repeat(reverse: true);
    }

    _whaleAnimation = Tween<double>(begin: -12.0, end: 12.0).animate(
      CurvedAnimation(parent: _whaleController, curve: Curves.easeInOut),
    );

    _launchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _lockPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _lockPulseAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _lockPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _typingStatusSubscription?.cancel();
    _typingStatusTimer?.cancel();
    unawaited(_updateTypingStatus(false));
    _incomingBannerTimer?.cancel();
    clearHistoryNotifier.removeListener(_clearChatMessages);
    whaleMotionNotifier.removeListener(_onWhaleMotionChanged);
    whaleSoundNotifier.removeListener(_onWhaleSoundChanged);
    _chatAudioPlayer.dispose();
    _mediaAudioPlayer.dispose();
    _whaleController.dispose();
    _launchController.dispose();
    _lockPulseController.dispose();
    unawaited(_voiceRecorder.stop());
    _voiceRecorder.dispose();
    _controller.dispose();
    _chatPasswordController.dispose();
    super.dispose();
  }

  void _clearChatMessages() {
    if (mounted) setState(_messages.clear);
  }

  void _onWhaleSoundChanged() {
    if (!whaleSoundNotifier.value) {
      unawaited(_stopWhaleSound());
    }
  }

  void _onWhaleMotionChanged() {
    if (whaleMotionNotifier.value) {
      _whaleController.repeat(reverse: true);
    } else {
      _whaleController.stop();
    }
  }

  Future<void> _stopWhaleSound() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) return;
    try {
      await _chatAudioPlayer.stop().timeout(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  String get _chatId {
    if (widget.contactUid != null && widget.contactUid!.isNotEmpty) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        return directChatDocumentId(currentUid, widget.contactUid!);
      }
    }
    return chatDocumentId(widget.chatName);
  }

  Future<void> _loadChatPassword() async {
    if (!firebaseReady) {
      _playWhaleIfChatUnlocked();
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _playWhaleIfChatUnlocked();
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chatSecurity')
          .doc(_chatId)
          .get();
      final passwordHash = snapshot.data()?['passwordHash'];
      if (passwordHash is String && mounted) {
        await _chatAudioPlayer.stop();
        setState(() {
          _chatPassword = passwordHash;
          _chatLocked = true;
        });
      } else {
        _playWhaleIfChatUnlocked();
      }
    } catch (error) {
      debugPrint('Chat password load error: $error');
      _playWhaleIfChatUnlocked();
    }
  }

  void _playWhaleIfChatUnlocked() {
    if (_chatLocked || !whaleSoundNotifier.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_chatLocked) unawaited(_playWhaleSound());
    });
  }

  void _listenToChatMessages() {
    if (!firebaseReady) return;
    unawaited(deleteExpiredOwnChatMessages(_chatId));
    _messagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
      .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final hasIncomingMessage = snapshot.docChanges.any(
              (change) =>
                  change.type == DocumentChangeType.added &&
                  change.doc.data()?['uid'] != currentUid,
            );
            // الاحتفاظ فقط بالرسائل المحلية التي لم تُحفظ في Firebase بعد.
            final localMessages = _messages
              .where((msg) => msg.firestoreId == null)
              .toList();
            
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
              final mediaUrl = data['mediaUrl'] as String?;
              final localMediaPath = mediaUrl != null &&
                      mediaUrl.startsWith('local://')
                  ? mediaUrl.substring('local://'.length)
                  : null;
              return Message(
                originalText: data['text'] ?? '',
                encryptedData: data['text'] ?? '',
                isMe: data['uid'] == currentUid,
                firestoreId: doc.id,
                time: _messageTime(data['createdAt']),
                mediaType: data['mediaType'] as String?,
                mediaFile: localMediaPath == null
                    ? null
                    : XFile(localMediaPath),
                mediaUrl: localMediaPath == null ? mediaUrl : null,
              );
            }).whereType<Message>().toList();
            
            setState(() {
              _messages.clear();
              _messages.addAll(messages);
              // إضافة الرسائل المحلية المعلقة في النهاية
              _messages.addAll(localMessages
                  .where((local) => 
                      messages.every((server) => 
                          server.originalText != local.originalText ||
                          server.mediaUrl != local.mediaUrl))
                  .toList());
            });
                if (_hasLoadedMessages && hasIncomingMessage) {
                  _incomingBannerTimer?.cancel();
                  setState(() => _incomingBannerVisible = true);
                  _incomingBannerTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) setState(() => _incomingBannerVisible = false);
                  });
                }
                _hasLoadedMessages = true;
          },
          onError: (error) {
            debugPrint('Chat messages listener error: $error');
          },
        );
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (!firebaseReady) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
      await chatRef.set(
        {
          'typing': {
            currentUser.uid: isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
          },
        },
        SetOptions(merge: true),
      );

      if (!isTyping) {
        final doc = await chatRef.get();
        final typingMap = doc.data()?['typing'];
        if (typingMap is Map && typingMap.containsKey(currentUser.uid)) {
          await chatRef.update({
            'typing.${currentUser.uid}': FieldValue.delete(),
          });
        }
      }
    } catch (error) {
      debugPrint('Typing status update error: $error');
    }
  }

  void _setupTypingListener() {
    if (!firebaseReady) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _typingStatusSubscription?.cancel();
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    _typingStatusSubscription = chatRef.snapshots().listen((doc) {
      if (!mounted || !doc.exists) return;
      final typingData = doc.data()?['typing'];
      if (typingData is! Map) {
        if (_isOtherTyping) setState(() => _isOtherTyping = false);
        return;
      }

      final now = DateTime.now();
      bool otherUserTyping = false;
      for (final entry in typingData.entries) {
        final userId = entry.key;
        final value = entry.value;
        if (userId == currentUser.uid) continue;
        if (value is! Timestamp) continue;
        final lastActive = value.toDate();
        if (now.difference(lastActive).inSeconds <= 5) {
          otherUserTyping = true;
          break;
        }
      }

      if (mounted && _isOtherTyping != otherUserTyping) {
        setState(() => _isOtherTyping = otherUserTyping);
      }
    }, onError: (error) {
      debugPrint('Typing status listen error: $error');
    });
  }

  void _handleTypingChanged(String value) {
    final hasText = value.trim().isNotEmpty;

    if (hasText) {
      if (!_isCurrentUserTyping) {
        _isCurrentUserTyping = true;
        unawaited(_updateTypingStatus(true));
      }

      _typingStatusTimer?.cancel();
      _typingStatusTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _isCurrentUserTyping = false;
        unawaited(_updateTypingStatus(false));
      });
      return;
    }

    _typingStatusTimer?.cancel();
    if (_isCurrentUserTyping) {
      _isCurrentUserTyping = false;
      unawaited(_updateTypingStatus(false));
    }
  }

  Future<void> _saveChatMessage(
    String text, {
    required bool isEncrypted,
  }) async {
    if (!firebaseReady) {
      debugPrint('Chat message save skipped: Firebase not ready');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (widget.contactUid != null && widget.contactUid!.isNotEmpty) {
      final isApproved = await _hasApprovedDirectContact(widget.contactUid!);
      if (!isApproved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكنك إرسال رسالة إلا بعد موافقة الطرف الآخر'),
            ),
          );
        }
        return;
      }
    }

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId);
      await chatRef.set({
        'participantA': widget.contactUid == null
          ? user.uid
          : ([user.uid, widget.contactUid!]..sort())[0],
        'participantB': widget.contactUid == null
          ? user.uid
          : ([user.uid, widget.contactUid!]..sort())[1],
        'participants':
            widget.contactUid == null
                  ? [user.uid]
                  : [user.uid, widget.contactUid].toList()
              ..sort(),
        'chatType': widget.contactUid == null ? 'group' : 'direct',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'text': isEncrypted ? await _realEncrypt(text) : text,
        'sender': 'مستخدم',
        'uid': user.uid,
        'deletedFor': <String>[],
        if (widget.contactUid != null) 'recipientUid': widget.contactUid,
        'createdAt': FieldValue.serverTimestamp(),
        if (autoDeleteMessagesNotifier.value)
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(seconds: 8)),
          ),
      });

      // تحديث lastMessage في جهات الاتصال
      if (widget.contactUid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(contactsCollectionName(ContactScope.regular))
            .doc(widget.contactUid)
            .get();

        if (userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection(contactsCollectionName(ContactScope.regular))
              .doc(widget.contactUid)
              .update({
                'lastMessage': text.length > 50 ? '${text.substring(0, 50)}...' : text,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
      }
    } catch (error) {
      debugPrint('Chat message save error: $error');
    }
  }

  String _firebaseUnavailableMessage() {
    return 'حدثت مشكلة، حاول مرة أخرى';
  }

  Future<void> _unlockChat() async {
    if (await hashPassword(_chatPasswordController.text.trim()) ==
        _chatPassword) {
      setState(() {
        _chatLocked = false;
        _chatPasswordController.clear();
      });
      if (whaleSoundNotifier.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_chatLocked) unawaited(_playWhaleSound());
        });
      }
    } else {
      debugPrint('Chat unlock failed: invalid password');
    }
  }

  Future<void> _playWhaleSound() async {
    if (!whaleSoundNotifier.value ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux)) {
      return;
    }
    try {
      await _chatAudioPlayer.play(AssetSource('audio/whale_sound.mp3'));
    } catch (_) {
      // Audio is optional; a browser or device may deny playback.
    }
  }

  Future<void> _playMediaAudio(Message message) async {
    try {
      await _mediaAudioPlayer.stop();
      if (message.mediaFile != null) {
        await _mediaAudioPlayer.play(DeviceFileSource(message.mediaFile!.path));
      } else if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
        await _mediaAudioPlayer.play(UrlSource(message.mediaUrl!));
      }
    } catch (error) {
      debugPrint('Audio message playback error: $error');
    }
  }

  Future<void> _changeChatPassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير كلمة سر الدردشة'),
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
              final oldHash = await hashPassword(oldController.text.trim());
              if (oldHash != _chatPassword ||
                  newPassword.length < 4 ||
                  newPassword != confirmController.text.trim()) {
                debugPrint('Chat password update validation failed');
                return;
              }
              try {
                await saveChatPassword(_chatId, newPassword);
                final newHash = await hashPassword(newPassword);
                if (mounted) {
                  setState(() => _chatPassword = newHash);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                debugPrint('Chat password update error: $error');
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

  Future<void> _setChatPasswordForCurrentChat() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأمين هذه الدردشة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
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
              final newPassword = passwordController.text.trim();
              final confirmed = confirmController.text.trim();
              if (newPassword.length < 4 || newPassword != confirmed) {
                debugPrint('Chat password set validation failed');
                return;
              }
              try {
                await saveChatPassword(_chatId, newPassword);
                final newHash = await hashPassword(newPassword);
                if (mounted) {
                  setState(() {
                    _chatPassword = newHash;
                    _chatLocked = false;
                  });
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                debugPrint('Chat password set error: $error');
              }
            },
            child: const Text('تأمين'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _disableChatPassword() async {
    final enteredHash = await hashPassword(_chatPasswordController.text.trim());
    if (enteredHash != _chatPassword) {
      debugPrint('Disable chat password failed: invalid current password');
      return;
    }
    if (mounted) {
      setState(() {
        _chatLocked = false;
        _chatPassword = null;
        _chatPasswordController.clear();
      });
    }
    unawaited(disableChatPassword(_chatId));
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      try {
        final String? path = await _voiceRecorder.stop();
        if (!mounted) return;
        setState(() => _isRecording = false);
        if (path != null && path.isNotEmpty) {
          final voiceFile = XFile(path);
          final uploadedMediaUrl = await _uploadMedia(voiceFile, 'audio');
          final mediaUrl = uploadedMediaUrl ?? 'local://$path';
          final messageTime = _messageTime(null);
          if (mediaUrl.startsWith('local://')) {
            await _saveLocalVoiceMessage(path, messageTime);
          }
          setState(() {
            final Message voiceMessage = Message(
              originalText: '🎙️ رسالة صوتية',
              encryptedData: path,
              isMe: true,
              time: messageTime,
              mediaType: 'audio',
              mediaFile: voiceFile,
              mediaUrl: mediaUrl,
            );
            _messages.add(voiceMessage);
            _scheduleMessageDeletion(
              voiceMessage,
              enabledAtSend: autoDeleteMessagesNotifier.value,
            );
          });
          if (uploadedMediaUrl != null &&
              !uploadedMediaUrl.startsWith('local://')) {
            await _saveUploadedMediaMessage('🎙️ رسالة صوتية', 'audio', mediaUrl);
          }
        }
      } catch (error) {
        debugPrint('Voice recording stop error: $error');
        if (mounted) {
          setState(() => _isRecording = false);
        }
      }
      return;
    }

    try {
      final hasPermission = await _voiceRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        return;
      }

      final recordPath = await getApplicationDocumentsDirectory();
      final fileName = 'shadow_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${recordPath.path}/$fileName';

      await _voiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: filePath,
      );
      if (mounted) setState(() => _isRecording = true);
    } catch (error) {
      debugPrint('Voice recording start error: $error');
    }
  }

  Future<void> _pickMedia({
    required bool video,
    ImageSource source = ImageSource.gallery,
  }) async {
    final XFile? file = video
        ? await _mediaPicker.pickVideo(source: source)
        : await _mediaPicker.pickImage(source: source);
    if (file == null || !mounted) return;
    
    final mediaType = video ? 'video' : 'image';
    
    // إضافة الرسالة محليًا أولاً لتظهير فوري
    final messageIndex = _messages.length;
    setState(() {
      _messages.add(
        Message(
          originalText: video ? '🎬 فيديو' : '🖼️ صورة',
          encryptedData: file.name,
          isMe: true,
          time: _messageTime(null),
          mediaType: mediaType,
          mediaFile: file,
          mediaUrl: null,
        ),
      );
      _scheduleMessageDeletion(
        _messages.last,
        enabledAtSend: autoDeleteMessagesNotifier.value,
      );
    });

    // رفع الملف في الخلفية
    try {
      final mediaUrl = await _uploadMedia(file, mediaType);
      if (mediaUrl != null && mounted && messageIndex < _messages.length) {
        // إنشاء رسالة جديدة برابط الملف
        setState(() {
          _messages[messageIndex] = Message(
            originalText: video ? '🎬 فيديو' : '🖼️ صورة',
            encryptedData: file.name,
            isMe: true,
            time: _messageTime(null),
            mediaType: mediaType,
            mediaFile: file,
            mediaUrl: mediaUrl,
          );
        });
        
        // لا نرسل local:// إلى Firebase؛ هذا المسار صالح على هذا الجهاز فقط.
        if (!mediaUrl.startsWith('local://')) {
          await _saveUploadedMediaMessage(
            video ? '🎬 فيديو' : '🖼️ صورة',
            mediaType,
            mediaUrl,
          );
        }
      } else if (mounted) {
        debugPrint('Media upload failed');
        if (mounted) {
          setState(() {
            if (messageIndex < _messages.length) {
              _messages.removeAt(messageIndex);
            }
          });
        }
      }
    } catch (error) {
      debugPrint('Media pick error: $error');
      if (mounted) {
        setState(() {
          if (messageIndex < _messages.length) {
            _messages.removeAt(messageIndex);
          }
        });
      }
    }
  }

  Future<String?> _uploadMedia(XFile file, String mediaType) async {
    Future<String?> saveLocally() async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final localFile = File(
          '${directory.path}/shadow_media_${DateTime.now().millisecondsSinceEpoch}_$safeName',
        );
        await File(file.path).copy(localFile.path);
        return 'local://${localFile.path}';
      } catch (error) {
        debugPrint('Local media save error: $error');
        return null;
      }
    }

    if (!firebaseReady) return saveLocally();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return saveLocally();

    try {
      final fileName = '${mediaType}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final uploadTask = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('media')
          .child(mediaType)
          .child(fileName)
          .putFile(File(file.path));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (error) {
      debugPrint('Media upload error: $error');
      return saveLocally();
    }
  }

  Future<void> _saveUploadedMediaMessage(
    String text,
    String mediaType,
    String? mediaUrl,
  ) async {
    if (!firebaseReady ||
        mediaUrl == null ||
        mediaUrl.isEmpty ||
        mediaUrl.startsWith('local://')) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId);
      
      await chatRef.set({
        'participantA': widget.contactUid == null
          ? user.uid
          : ([user.uid, widget.contactUid!]..sort())[0],
        'participantB': widget.contactUid == null
          ? user.uid
          : ([user.uid, widget.contactUid!]..sort())[1],
        'participants':
            widget.contactUid == null
                  ? [user.uid]
                  : [user.uid, widget.contactUid].toList()
              ..sort(),
        'chatType': widget.contactUid == null ? 'group' : 'direct',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'text': text,
        'uid': user.uid,
        'sender': 'مستخدم',
        'deletedFor': <String>[],
        'mediaType': mediaType,
        'mediaUrl': mediaUrl,
        if (widget.contactUid != null) 'recipientUid': widget.contactUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // تحديث lastMessage في جهات الاتصال
      if (widget.contactUid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(contactsCollectionName(ContactScope.regular))
            .doc(widget.contactUid)
            .get();

        if (userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection(contactsCollectionName(ContactScope.regular))
              .doc(widget.contactUid)
              .update({
                'lastMessage': text,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
      }
    } catch (error) {
      debugPrint('Media message save error: $error');
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101714),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MediaOption(
                  icon: Icons.photo_library_rounded,
                  label: 'صورة',
                  color: const Color(0xFF00FF66),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickMedia(video: false);
                  },
                ),
                _MediaOption(
                  icon: Icons.video_library_rounded,
                  label: 'فيديو',
                  color: Colors.amberAccent,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickMedia(video: true);
                  },
                ),
                _MediaOption(
                  icon: Icons.photo_camera_rounded,
                  label: 'كاميرا',
                  color: Colors.cyanAccent,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickMedia(video: false, source: ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _realEncrypt(String text) async {
    if (text.isEmpty) return '';

    final AesGcm cipher = AesGcm.with256bits();
    final List<int> keySeed = utf8.encode('SHADOW_KEY_2026');
    final List<int> keyBytes = (await Sha256().hash(keySeed)).bytes;
    final SecretKey secretKey = SecretKey(keyBytes);
    final SecretBox encrypted = await cipher.encrypt(
      utf8.encode(text),
      secretKey: secretKey,
    );

    return base64Encode([
      ...encrypted.nonce,
      ...encrypted.cipherText,
      ...encrypted.mac.bytes,
    ]);
  }

  void _scheduleMessageDeletion(
    Message message, {
    required bool enabledAtSend,
  }) {
    if (!enabledAtSend || !message.isMe) return;

    final String? firestoreId = message.firestoreId;
    final String comparisonKey = [
      message.originalText,
      message.mediaUrl ?? '',
      message.time ?? '',
    ].join('|');

    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted) {
        unawaited(deleteExpiredOwnChatMessages(_chatId));
        return;
      }

      setState(() {
        _messages.removeWhere((candidate) {
          if (firestoreId != null && candidate.firestoreId != null) {
            return candidate.firestoreId == firestoreId;
          }

          final candidateKey = [
            candidate.originalText,
            candidate.mediaUrl ?? '',
            candidate.time ?? '',
          ].join('|');

          return candidate.isMe == message.isMe && candidateKey == comparisonKey;
        });
      });

      unawaited(deleteExpiredOwnChatMessages(_chatId));
    });
  }

  Future<void> _deleteRegularMedia(Message message, {required bool remote}) async {
    if (message.mediaFile != null) {
      try {
        final localFile = File(message.mediaFile!.path);
        if (await localFile.exists()) await localFile.delete();
      } catch (error) {
        debugPrint('Local media delete error: $error');
      }
    }
    if (!remote || message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return;
    }
    try {
      await FirebaseStorage.instance.refFromURL(message.mediaUrl!).delete();
    } catch (error) {
      debugPrint('Firebase media delete error: $error');
    }
  }

  Future<void> _deleteRegularMessage(
    Message message, {
    required bool forEveryone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final docId = message.firestoreId;
    if (user == null) return;
    if (forEveryone && !message.isMe) {
      return;
    }
    if (docId == null || !firebaseReady) {
      await _deleteRegularMedia(message, remote: false);
      if (mounted) setState(() => _messages.remove(message));
      return;
    }

    final reference = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(docId);
    try {
      if (forEveryone && message.isMe) {
        await reference.delete();
        await _deleteRegularMedia(message, remote: true);
      } else {
        await reference.update({
          'deletedFor': FieldValue.arrayUnion([user.uid]),
        });
        await _deleteRegularMedia(message, remote: false);
      }
      if (mounted) setState(() => _messages.remove(message));
    } catch (error) {
      debugPrint('Regular message delete error: $error');
    }
  }

  Future<void> _showMessageActions(Message message) async {
    final deleteMode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101714),
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
            if (message.isMe && message.firestoreId != null)
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
    if (deleteMode == 'everyone') {
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
    await _deleteRegularMessage(
      message,
      forEveryone: deleteMode == 'everyone',
    );
  }

  // دعم تحويل النصوص العربية والإنجليزية لنيون
  String _toNeonGreenText(String text) {
    const Map<String, String> normalToNeon = {
      // الحروف العربية
      'ا': '𝕒',
      'ب': '𝕓',
      'ت': '𝕥',
      'ث': '𝕥𝕙',
      'ج': '𝕛',
      'ح': '𝕙',
      'خ': '𝕩',
      'د': '𝕕',
      'ذ': 'ẕ',
      'ر': '𝕣',
      'ز': '𝕫',
      'س': '𝕤',
      'ش': '𝕤𝕙',
      'ص': '𝕤',
      'ض': 'ḏ', 'ط': '𝕥', 'ظ': 'ẓ', 'ع': '𝕔', 'غ': 'ǧ', 'ف': '𝕗', 'ق': 'զ',
      'ك': '𝕜',
      'ل': '𝕝',
      'م': '𝕞',
      'ن': '𝕟',
      'ه': '𝕙',
      'و': '𝕨',
      'ي': '𝟪',
      'أ': '𝕒',
      'إ': '𝕒',
      'آ': '𝕒',
      'ة': '𝕥',
      'ى': '𝟪',
      'ئ': '𝟪',
      'ؤ': '𝕨',
      'ء': '𝕩', 'لا': '𝕝𝕒',

      // الحروف الإنجليزية الصغيرة
      'a': '𝕒',
      'b': '𝕓',
      'c': '𝕔',
      'd': '𝕕',
      'e': '𝕖',
      'f': '𝕗',
      'g': '𝕘',
      'h': '𝕙',
      'i': '𝕚',
      'j': '𝕛',
      'k': '𝕜',
      'l': '𝕝',
      'm': '𝕞',
      'n': '𝕟',
      'o': '𝕠',
      'p': '𝕡',
      'q': 'զ',
      'r': '𝕣',
      's': '𝕤',
      't': '𝕥',
      'u': '𝕦',
      'v': '𝕧', 'w': '𝕨', 'x': '𝕩', 'y': '𝕪', 'z': '𝕫',

      // الحروف الإنجليزية الكبيرة
      'A': '𝔸',
      'B': '𝔹',
      'C': 'ℂ',
      'D': '𝔻',
      'E': '𝔼',
      'F': '𝔽',
      'G': '𝔾',
      'H': 'ℍ', 'I': '𝕀', 'J': '𝕁', 'K': '𝕂', 'L': '𝔏', 'M': '𝕄', 'N': 'ℕ',
      'O': '𝕆', 'P': 'ℙ', 'Q': 'ℚ', 'R': 'ℝ', 'S': '𝕊', 'T': '𝕋', 'U': '𝕌',
      'V': '𝕍', 'W': '𝕎', 'X': '𝕏', 'Y': '𝕐', 'Z': 'ℤ',

      // الأرقام
      '0': '𝟘',
      '1': '𝟙',
      '2': '𝟚',
      '3': '𝟛',
      '4': '𝟜',
      '5': '𝟝',
      '6': '𝟞',
      '7': '𝟟', '8': '𝟠', '9': '𝟡',
    };

    StringBuffer result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      final bool isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(char);
      result.write(isArabic ? char : normalToNeon[char] ?? char);
    }
    return result.toString();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isNotEmpty && !_isLaunching) {
      String userText = _controller.text.trim();
      _controller.clear();
      _typingStatusTimer?.cancel();
      if (_isCurrentUserTyping) {
        _isCurrentUserTyping = false;
        unawaited(_updateTypingStatus(false));
      }

      setState(() {
        _isLaunching = true;
      });

      // تشفير البيانات بجد في الخلفية لو الـ autoEncrypt مفعل
      bool isEncrypted = autoEncryptNotifier.value;
      final String processedText = isEncrypted
          ? await _realEncrypt(userText)
          : userText;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            final Message sentMessage = Message(
              originalText: userText,
              encryptedData: processedText,
              isMe: true,
              time: _messageTime(null),
              isEncrypted: isEncrypted,
            );
            _messages.add(sentMessage);
            _saveChatMessage(userText, isEncrypted: isEncrypted);
            _scheduleMessageDeletion(
              sentMessage,
              enabledAtSend: autoDeleteMessagesNotifier.value,
            );
            _isOtherTyping = true;
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) setState(() => _isOtherTyping = false);
          });
        }
      });

      _launchController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _isLaunching = false;
          });
        }
      });
    }
  }

  Widget _buildMessageContent(Message message) {
    final mediaWidth = MediaQuery.sizeOf(context).width < 600
        ? MediaQuery.sizeOf(context).width * 0.72
        : 340.0;
    final mediaHeight = mediaWidth * 0.72;

    // معالجة الصور
    if (message.mediaType == 'image' &&
        (message.mediaFile != null || message.mediaUrl != null)) {
      debugPrint('عرض صورة: mediaUrl=${message.mediaUrl}, mediaFile=${message.mediaFile?.name}');
      
      // عرض من رابط Firebase
      if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.mediaUrl!,
            width: mediaWidth,
            height: mediaHeight,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('خطأ في تحميل الصورة من الرابط: $error');
              return Container(
                width: mediaWidth,
                height: mediaHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, color: Colors.white54),
                    SizedBox(height: 8),
                    Text(
                      'تعذر عرض الصورة',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: mediaWidth,
                height: mediaHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00FF66),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
      
      // عرض من ملف محلي
      if (message.mediaFile != null) {
        debugPrint('عرض صورة محلية: ${message.mediaFile?.name}');
        return FutureBuilder<Uint8List>(
          future: message.mediaFile!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: 220,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00FF66),
                    ),
                  ),
                ),
              );
            }
            
            if (!snapshot.hasData || snapshot.data == null) {
              return Container(
                width: 220,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, color: Colors.white54),
                    SizedBox(height: 8),
                    Text(
                      'لم تتمكن من قراءة الصورة',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              );
            }
            
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                width: mediaWidth,
                height: mediaHeight,
                fit: BoxFit.cover,
              ),
            );
          },
        );
      }
    }
    
    // معالجة الفيديوهات
    if (message.mediaType == 'video') {
      return _VideoMessagePlayer(
        mediaFile: message.mediaFile,
        mediaUrl: message.mediaUrl,
      );
    }
    
    // معالجة التسجيلات الصوتية
    if (message.mediaType == 'audio') {
      return GestureDetector(
        onTap: () => _playMediaAudio(message),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: message.isMe
                  ? [const Color(0xFF1FD196), const Color(0xFF0F7D5E)]
                  : [const Color(0xFF1A2A2D), const Color(0xFF131E21)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: message.isMe
                  ? const Color(0xFF9AF7D0).withOpacity(0.8)
                  : const Color(0xFF7DE5A8).withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF66).withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رسالة صوتية',
                      style: TextStyle(
                        color: message.isMe ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اضغط للتشغيل 🎙️',
                      style: TextStyle(
                        color: message.isMe ? Colors.white70 : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Text(
      _toNeonGreenText(message.displayText),
      textAlign: TextAlign.start,
      softWrap: true,
      style: TextStyle(
        color: message.isMe ? Colors.white : const Color(0xFFE8FFF4),
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w500,
        shadows: message.isMe
            ? null
            : [
                Shadow(
                  color: const Color(0xFF00FF66).withOpacity(0.28),
                  blurRadius: 5,
                ),
              ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isDark) {
    final sentColor = const Color(0xFF176B59);
    final receivedColor = const Color(0xFF1C2728);
    final borderColor = message.isMe
        ? const Color(0xFF38E8A5).withOpacity(0.65)
        : const Color(0xFF8BA99A).withOpacity(0.35);
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          minWidth: 72,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 8),
          decoration: BoxDecoration(
            color: message.isMe
                ? sentColor.withOpacity(isDark ? 0.92 : 1)
                : receivedColor.withOpacity(isDark ? 0.94 : 1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(message.isMe ? 18 : 5),
              bottomRight: Radius.circular(message.isMe ? 5 : 18),
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMessageContent(message),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.time ?? _messageTime(null),
                    style: TextStyle(
                      color: message.isMe
                          ? const Color(0xFFB5E7D2)
                          : Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  if (message.isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: Color(0xFFB5E7D2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_directAccessChecked) {
      return const Scaffold(
        backgroundColor: Color(0xFF101716),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38E8A5)),
        ),
      );
    }
    if (!_directAccessApproved) {
      return const Scaffold(
        backgroundColor: Color(0xFF101716),
        body: Center(
          child: Text(
            'هذه الدردشة تحتاج موافقة الطرف الآخر أولًا',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (_chatLocked) return _buildLockedChat();
    const isDark = true;
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF101716)
              : const Color(0xFFF4F7F6),
          body: Stack(
            children: [
              if (isDark)
                ValueListenableBuilder<bool>(
                  valueListenable: whaleMotionNotifier,
                  builder: (context, isMoving, child) {
                    return AnimatedBuilder(
                      animation: _whaleAnimation,
                      child: Image.asset(
                        'assets/images/whale.jpg',
                        fit: BoxFit.cover,
                        cacheWidth: 896,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: const Color(0xFF101716)),
                      ),
                      builder: (context, child) {
                        return Positioned.fill(
                          child: RepaintBoundary(
                            child: Transform.translate(
                              offset: isMoving
                                  ? Offset(0, _whaleAnimation.value)
                                  : Offset.zero,
                              child: Transform.scale(scale: 1.08, child: child),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              if (isDark)
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF00FF66),
                            ),
                            tooltip: 'رجوع',
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child:
                                StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >(
                                  stream: _contactPresenceStream,
                                  builder: (context, snapshot) {
                                    final data = snapshot.data?.data();
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          (data?['displayName'] as String?)
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? data!['displayName'] as String
                                          : widget.chatName,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF14211D),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        if (widget.contactUid != null)
                                          Text(
                                            _presenceText(data),
                                            style: TextStyle(
                                              color: data?['isOnline'] == true
                                                  ? const Color(0xFF00FF66)
                                                  : Colors.white60,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: ghostModeNotifier,
                            builder: (context, isGhostModeEnabled, child) {
                              return Icon(
                                isGhostModeEnabled
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: isGhostModeEnabled
                                    ? Colors.purpleAccent
                                    : Colors.white30,
                                size: 18,
                              );
                            },
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2A25).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF38E8A5).withOpacity(0.35),
                        ),
                      ),
                      child: const Text(
                        'أهلاً بك في نظام shadow chat ✨ 🌑 ✨',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF00FF66),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) {
                        return SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _incomingBannerVisible
                          ? Container(
                              key: const ValueKey('incoming-message'),
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF103E32),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF38E8A5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00FF66)
                                        .withOpacity(0.18),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.mark_unread_chat_alt_rounded,
                                    color: Color(0xFF7CFFC0),
                                    size: 19,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'رسالة جديدة من ${widget.chatName}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFE8FFF4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('no-incoming-message'),
                              height: 0,
                            ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return GestureDetector(
                            onLongPress: () => _showMessageActions(msg),
                            child: _buildMessageBubble(msg, isDark),
                          );
                        },
                      ),
                    ),
                    if (_isOtherTyping)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C342B).withOpacity(0.96),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF38E8A5).withOpacity(0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00FF66),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'يكتب الآن...',
                              style: TextStyle(
                                color: Color(0xFFE8FFF4),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15221F).withOpacity(0.96),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF38E8A5).withOpacity(0.45),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                        _FloatingChatButton(
                          icon: Icons.send_rounded,
                          color: const Color(0xFF00FF66),
                          tooltip: 'إرسال',
                          onPressed: _sendMessage,
                        ),
                        _FloatingChatButton(
                          icon: _isRecording
                              ? Icons.stop_circle
                              : Icons.mic_none_rounded,
                          color: _isRecording
                              ? Colors.redAccent
                              : Colors.amberAccent,
                          tooltip: _isRecording
                              ? 'إيقاف التسجيل'
                              : 'تسجيل رسالة صوتية',
                          onPressed: _toggleVoiceRecording,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 9,
                              ),
                              hintText:
                                  'اكتب رسالتك هنا...',
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                            ),
                            onChanged: _handleTypingChanged,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        SizedBox(
                          width: 62,
                          height: 48,
                          child: IconButton(
                            icon: const Text(
                              '🌊',
                              style: TextStyle(fontSize: 25),
                            ),
                            tooltip: 'إرسال صورة أو فيديو',
                            onPressed: _showMediaPicker,
                          ),
                        ),
                        ],
                      ),
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

  Widget _buildLockedChat() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        appBar: AppBar(
          title: const Text(
            'دردشة محمية',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF17243A),
          iconTheme: const IconThemeData(color: Color(0xFF7DE7FF)),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B1220),
                      const Color(0xFF142B42),
                      const Color(0xFF081018),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 410),
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152235).withOpacity(0.98),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF7DE7FF).withOpacity(0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CC9F0).withOpacity(0.16),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _lockPulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00FF66).withOpacity(0.1),
                            border: Border.all(
                              color: const Color(0xFF00FF66),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFF00FF66),
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'الدردشة مؤمنة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'أدخل كلمة المرور للوصول إلى الرسائل',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _chatPasswordController,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(
                            color: Colors.white30,
                            letterSpacing: 3,
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.35),
                          prefixIcon: const Icon(
                            Icons.key_rounded,
                            color: Colors.amberAccent,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF00FF66),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _unlockChat(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _unlockChat,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text(
                            'فتح الدردشة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF66),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _changeChatPassword,
                            icon: const Icon(Icons.password_rounded, size: 18),
                            label: const Text('تغيير كلمة السر'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.amberAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _disableChatPassword,
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text('إيقاف كلمة السر'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF61E7C0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Colors.amberAccent,
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'حماية Shadow Chat',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
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

// ---------------------------------------------------------
// ضع هذا الجزء في نهاية ملف main.dart تماماً (بدون أي imports جديدة)
// ---------------------------------------------------------

ValueNotifier<XFile?> userProfileImageNotifier = ValueNotifier<XFile?>(null);
