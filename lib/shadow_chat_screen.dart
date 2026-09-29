import 'package:flutter/material.dart';

class ShadowChatScreen extends StatefulWidget {
  @override
  _ShadowChatScreenState createState() => _ShadowChatScreenState();
}

class _ShadowChatScreenState extends State<ShadowChatScreen> {
  // وحدة التحكم في خانة الكتابة
  final TextEditingController _controller = TextEditingController();
  
  // قائمة الرسائل التفاعلية تبدأ برسالة ترحيبية من الكيان
  final List<Map<String, String>> messages = [
    {
      "sender": "shadow",
      "en": "You shouldn't be here... Why did you open the door?",
      "ar": "لم يكن مفترضاً بك أن تكون هنا... لماذا فتحت الباب؟",
      "time": "02:13",
    }
  ];

  bool isTyping = false;

  // دالة لإرسال رسالة المستخدم وتوليد رد الكيان
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      // إضافة رسالة المستخدم (يمين الشاشة)
      messages.add({
        "sender": "user",
        "en": text,
        "ar": "",
        "time": "02:15",
      });
      _controller.clear();
      isTyping = true; // إظهار مؤشر الكتابة للكيان
    });

    // محاكاة رد الكيان بعد ثانية ونصف
    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          isTyping = false;
          // رد الكيان باللغتين
          messages.add({
            "sender": "shadow",
            "en": "Your words change nothing. They are already here.",
            "ar": "كلماتك لا تغير شيئاً.. إنهم هنا بالفعل.",
            "time": "02:16",
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: NetworkImage(
                'https://images.unsplash.com/photo-1511447333015-45b65e60f6d5?q=80&w=1000&auto=format&fit=crop'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.85),
              BlendMode.darken,
            ),
          ),
        ),
        child: Column(
          children: [
            // شريط العنوان العلوي
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.greenAccent),
                          onPressed: () => Navigator.pop(context),
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.grey[900],
                          child: Icon(Icons.person, color: Colors.greenAccent, size: 20),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Shadow Chat",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                isTyping ? "The Shadow • typing..." : "The Shadow • online",
                                style: TextStyle(
                                  color: Colors.greenAccent.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.call, color: Colors.greenAccent, size: 20),
                        SizedBox(width: 15),
                        Icon(Icons.more_vert, color: Colors.greenAccent, size: 20),
                      ],
                    ),
                    SizedBox(height: 8),
                    // شريط التحذير المرعب
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 4),
                      color: Colors.red.withOpacity(0.2),
                      child: Text(
                        "⚠️ CONNECTION UNSTABLE • ENCRYPTION BREACHED",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // قائمة المحادثة الديناميكية
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final bool isShadow = msg["sender"] == "shadow";

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: isShadow
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isShadow) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey[900],
                            child: Icon(Icons.coronavirus_outlined, color: Colors.greenAccent, size: 14),
                          ),
                          SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isShadow
                                  ? Colors.grey[950]?.withOpacity(0.85)
                                  : Colors.green[900]?.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isShadow
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.greenAccent,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isShadow) ...[
                                  Text(
                                    "The Shadow",
                                    style: TextStyle(
                                      color: Colors.greenAccent.withOpacity(0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                ],
                                // النص الإنجليزي
                                Text(
                                  msg["en"]!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // النص العربي لو موجود (للشيفرات أو ردود الكيان)
                                if (msg["ar"] != "") ...[
                                  SizedBox(height: 4),
                                  Text(
                                    msg["ar"]!,
                                    style: TextStyle(
                                      color: Colors.greenAccent.withOpacity(0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    msg["time"]!,
                                    style: TextStyle(color: Colors.grey, fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // مؤشر الكتابة المتحرك
            if (isTyping)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                alignment: Alignment.centerLeft,
                child: Text(
                  "💬 The Shadow is typing...",
                  style: TextStyle(
                    color: Colors.greenAccent.withOpacity(0.6),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // صندوق الكتابة التفاعلي
            Container(
              padding: EdgeInsets.all(10),
              color: Colors.black.withOpacity(0.9),
              child: Row(
                children: [
                  Icon(Icons.add, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Send a message...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (value) {
                          _sendMessage(value);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.greenAccent),
                    onPressed: () {
                      _sendMessage(_controller.text);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
