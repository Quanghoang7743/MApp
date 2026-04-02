class ChatItem {
  const ChatItem({
    required this.name,
    required this.message,
    required this.time,
    required this.initials,
  });

  final String name;
  final String message;
  final String time;
  final String initials;

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    return ChatItem(
      name: json['name'] ?? 'Unknown',
      message: json['lastMessage'] ?? json['message'] ?? '',
      time: json['time'] ?? 'Now',
      initials: json['initials'] ??
          ((json['name'] != null && json['name'].isNotEmpty)
              ? json['name'].substring(0, 1).toUpperCase()
              : '?'),
    );
  }
}
