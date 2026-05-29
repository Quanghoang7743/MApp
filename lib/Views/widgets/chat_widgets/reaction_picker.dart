import 'package:flutter/material.dart';

class ReactionOption {
  const ReactionOption({
    required this.code,
    required this.emoji,
  });

  final String code;
  final String emoji;
}

const List<ReactionOption> reactionOptions = [
  ReactionOption(code: 'like', emoji: '👍'),
  ReactionOption(code: 'love', emoji: '❤️'),
  ReactionOption(code: 'laugh', emoji: '😂'),
  ReactionOption(code: 'wow', emoji: '😮'),
  ReactionOption(code: 'sad', emoji: '😢'),
  ReactionOption(code: 'angry', emoji: '😡'),
];

/// Returns the sort-order index for a reaction code.
int reactionOrderIndex(String code) {
  final index = reactionOptions.indexWhere((item) => item.code == code);
  return index < 0 ? reactionOptions.length : index;
}

class ReactionPickerCard extends StatelessWidget {
  const ReactionPickerCard({
    super.key,
    required this.options,
    required this.selectedCode,
  });

  final List<ReactionOption> options;
  final String? selectedCode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260E123D),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(option.code),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selectedCode == option.code
                          ? const Color(0xFFF2EEFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option.emoji,
                      style: const TextStyle(fontSize: 24),
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
