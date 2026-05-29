import 'package:flutter/material.dart';

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.size,
  });

  final String? avatarUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE7EAF4),
          ),
          child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      ConversationAvatarFallback(
                        initials: initials,
                        size: size,
                      ),
                )
              : ConversationAvatarFallback(initials: initials, size: size),
        ),
        const Positioned(
          right: 2,
          bottom: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF5CDD73),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 12, height: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ConversationAvatarFallback extends StatelessWidget {
  const ConversationAvatarFallback({
    super.key,
    required this.initials,
    required this.size,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6251CC),
        ),
      ),
    );
  }
}
