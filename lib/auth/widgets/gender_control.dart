import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum GenderOption { male, female, other }

class GenderControl extends StatelessWidget {
  const GenderControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GenderOption value;
  final ValueChanged<GenderOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark
                ? const Color(0xFF1D2128).withValues(alpha: 0.86)
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
                blurRadius: 18,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CupertinoSlidingSegmentedControl<GenderOption>(
            groupValue: value,
            onValueChanged: onChanged,
            thumbColor: const Color(0xFF2A89FF),
            backgroundColor: Colors.transparent,
            children: {
              GenderOption.male: _segmentLabel('Male'),
              GenderOption.female: _segmentLabel('Female'),
              GenderOption.other: _segmentLabel('Other'),
            },
          ),
        ),
      ],
    );
  }

  Widget _segmentLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
