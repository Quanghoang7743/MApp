import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../models/chat_item.dart';
import 'widgets/conversation_row.dart';
import '../services/environment.dart';
import '../providers/auth_provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.onChatTap,
    required this.onToggleTheme,
    required this.darkModeEnabled,
  });

  final VoidCallback onChatTap;
  final VoidCallback onToggleTheme;
  final bool darkModeEnabled;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatItem> chats = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      final url = Uri.parse(Environment.conversations);
      print('Fetching URL: $url');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      print('Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          final List<dynamic> data = decoded is List ? decoded : (decoded['data'] ?? []);
          setState(() {
            chats = data.map((item) => ChatItem.fromJson(item)).toList();
            isLoading = false;
          });
        } catch (e) {
          print('Lỗi parse JSON. API Response body: ${utf8.decode(response.bodyBytes)}');
          setState(() {
            errorMessage = 'Dữ liệu không hợp lệ từ máy chủ (phản hồi là HTML hoặc văn bản)';
            isLoading = false;
          });
        }
      } else {
        print('Error body: ${response.body}');
        setState(() {
          errorMessage = 'Lỗi tải danh sách: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Lỗi kết nối: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF111318), const Color(0xFF171B21)]
                : [const Color(0xFFF9FAFC), const Color(0xFFF2F4F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        "Sửa",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Mox',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: IconButton(
                        icon: SvgPicture.asset(
                          'assets/icons/qr-scanner.svg',
                          width: 30,
                          height: 30,
                          colorFilter: ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                        onPressed: () {
                          // Implement Search UI here when needed
                        },
                      ),
                    ),

                    // InkWell(
                    //   borderRadius: BorderRadius.circular(20),
                    //   onTap: onToggleTheme,
                    //   child: Container(
                    //     width: 36,
                    //     height: 36,
                    //     decoration: BoxDecoration(
                    //       color: isDark
                    //           ? const Color(0xFF20242B).withValues(alpha: 0.7)
                    //           : Colors.white.withValues(alpha: 0.76),
                    //       borderRadius: BorderRadius.circular(18),
                    //       border: Border.all(
                    //         color: isDark
                    //             ? Colors.white.withValues(alpha: 0.08)
                    //             : Colors.black.withValues(alpha: 0.05),
                    //       ),
                    //     ),
                    //     child: Icon(
                    //       darkModeEnabled
                    //           ? Icons.light_mode_rounded
                    //           : Icons.dark_mode_rounded,
                    //       size: 17,
                    //       color: isDark
                    //           ? const Color(0xFFE8EBF1)
                    //           : const Color(0xFF485064),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 15),
                // const GlassContainer(
                //   borderRadius: 16,
                //   padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                //   child: Row(
                //     children: [
                //       Icon(Icons.search_rounded, size: 20),
                //       SizedBox(width: 8),
                //       Text('Search'),
                //     ],
                //   ),
                // ),
                const SizedBox(height: 18),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage != null
                          ? Center(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            )
                          : chats.isEmpty
                              ? const Center(
                                  child: Text("Không có cuộc trò chuyện nào"),
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: chats.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return ConversationRow(
                                      chat: chats[index],
                                      onTap: widget.onChatTap,
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
