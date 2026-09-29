import 'package:flutter/material.dart';

class ShadowChatScreen extends StatefulWidget {
  @override
  _ShadowChatScreenState createState() => _ShadowChatScreenState();
}

class _ShadowChatScreenState extends State<ShadowChatScreen> {
  // قائمة الرسائل بتصميم مزدوج (إنجليزي وتحته عربي)
  final List<Map<String, String>> messages = [
    {
      "en": "You shouldn't be here...",
      "ar": "لم يكن مفترضاً بك أن تكون هنا...",
      "time": "02:13",
      "status": "DELIVERED"
    },
    {
      "en": "They are watching every keystroke.",
      "ar": "إنهم يراقبون كل ضغطة زر لك.",
      "time": "02:14",
      "status": ""
    },
    {
      "en": "Leave now. Before the screen locks forever.",
      "ar": "اغادر الآن.. قبل أن تتقفل الشاشة عليك للأبد.",
      "time": "02:15",
      "status": ""
    },
    {
      "en": "You are trapped... no way back.",
      "ar": "أنت محبوس هنا... ولن تجد طريق العودة.",
      "time": "02:16",
      "status": ""
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        // خلفية داكنة توحي بأجواء الغابة المرعبة وإدمان الشاشات
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
            // شريط العنوان العلوي (App Bar المخصص)
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
                                "The Shadow • online • typing...",
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

            // قائمة المحادثة والرسائل المزدوجة
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey[900],
                          child: Icon(Icons.coronavirus_outlined, color: Colors.greenAccent, size: 14),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "The Shadow",
                                style: TextStyle(
                                  color: Colors.greenAccent.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[950]?.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.greenAccent.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // النص الإنجليزي العالمي
                                    Text(
                                      msg["en"]!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    // الترجمة العربية للعمق النفسي
                                    Text(
                                      msg["ar"]!,
                                      style: TextStyle(
                                        color: Colors.greenAccent.withOpacity(0.8),
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (msg["status"] != "")
                                          Text(
                                            "${msg["status"]} • ",
                                            style: TextStyle(color: Colors.grey, fontSize: 9),
                                          ),
                                        Text(
                                          msg["time"]!,
                                          style: TextStyle(color: Colors.grey, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // مؤشر الكتابة السفلي
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

            // صندوق كتابة الرسائل
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
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Send a message...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.send, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Icon(Icons.mic, color: Colors.greenAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
