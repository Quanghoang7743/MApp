import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'app_home_login_screen.dart';
import 'package:mess_app/Views/widgets/setting_widgets/storege_cache.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _notificationsEnabled = true;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showPlaceholder(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label đang được phát triển'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final displayName = (user?['display_name'] ?? 'Chưa cập nhật').toString();
    final username = (user?['username'] ?? 'chuacapnhat').toString();
    final avatarUrl = user?['avatar_url']?.toString();

    final accountRows = [
      _SettingRowData(
        icon: Icons.person_rounded,
        iconColor: const Color(0xFF6B4EFF),
        iconBackground: const Color(0xFFF1ECFF),
        label: 'Tài khoản',
        onTap: () => _showPlaceholder('Tài khoản'),
      ),
      _SettingRowData(
        icon: Icons.lock_outline_rounded,
        iconColor: const Color(0xFF7A59FF),
        iconBackground: const Color(0xFFF4EFFF),
        label: 'Quyền riêng tư',
        onTap: () => _showPlaceholder('Quyền riêng tư'),
      ),
      _SettingRowData(
        icon: Icons.verified_user_outlined,
        iconColor: const Color(0xFF6E5BFF),
        iconBackground: const Color(0xFFF1EEFF),
        label: 'Bảo mật đăng nhập',
        onTap: () => _showPlaceholder('Bảo mật đăng nhập'),
      ),
    ];

    final appRows = [
      _SettingRowData(
        icon: Icons.notifications_rounded,
        iconColor: const Color(0xFF2383FF),
        iconBackground: const Color(0xFFEAF4FF),
        label: 'Thông báo',
        trailing: _SettingRowTrailing.switcher(
          switchValue: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
      ),
      _SettingRowData(
        icon: Icons.folder_rounded,
        iconColor: const Color(0xFF2484FF),
        iconBackground: const Color(0xFFEAF4FF),
        label: 'Thư mục chat',
        onTap: () => _showPlaceholder('Thư mục chat'),
      ),
      _SettingRowData(
        icon: Icons.language_rounded,
        iconColor: const Color(0xFF1D7CFF),
        iconBackground: const Color(0xFFEAF4FF),
        label: 'Ngôn ngữ',
        trailing: _SettingRowTrailing.text('Tiếng Việt'),
        onTap: () => _showPlaceholder('Ngôn ngữ'),
      ),
      _SettingRowData(
        icon: Icons.storage_rounded,
        iconColor: const Color(0xFF1F7CFF),
        iconBackground: const Color(0xFFEAF4FF),
        label: 'Dữ liệu trên máy',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (subContext) => const StorageCacheView(),
            ),
          );
        },
      ),
      _SettingRowData(
        icon: Icons.brush_rounded,
        iconColor: const Color(0xFF1F7CFF),
        iconBackground: const Color(0xFFEAF4FF),
        label: 'Giao diện',
        trailing: _SettingRowTrailing.text('Sáng'),
        onTap: () => _showPlaceholder('Giao diện'),
      ),
    ];

    final supportRows = [
      _SettingRowData(
        icon: Icons.favorite_rounded,
        iconColor: const Color(0xFF7A59FF),
        iconBackground: const Color(0xFFF4EDFF),
        label: 'Trung tâm trợ giúp',
        onTap: () => _showPlaceholder('Trung tâm trợ giúp'),
      ),
      _SettingRowData(
        icon: Icons.help_rounded,
        iconColor: const Color(0xFF7A59FF),
        iconBackground: const Color(0xFFF4EDFF),
        label: 'Đặt câu hỏi',
        onTap: () => _showPlaceholder('Đặt câu hỏi'),
      ),
      _SettingRowData(
        icon: Icons.info_rounded,
        iconColor: const Color(0xFF7A59FF),
        iconBackground: const Color(0xFFF4EDFF),
        label: 'Về ứng dụng',
        onTap: () => _showPlaceholder('Về ứng dụng'),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FF),
      body: Stack(
        children: [
          const _SettingsBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth >= 900
                    ? 36.0
                    : constraints.maxWidth >= 700
                    ? 28.0
                    : 20.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cài đặt',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF171531),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Quản lý tài khoản và ứng dụng',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7E7A9B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _ProfileCard(
                            displayName: displayName,
                            username: username,
                            avatarUrl: avatarUrl,
                            onEdit: () => _showPlaceholder('Chỉnh sửa'),
                          ),
                          const SizedBox(height: 24),
                          _SettingsSectionCard(
                            title: 'Tài khoản & bảo mật',
                            icon: Icons.shield_rounded,
                            iconColor: const Color(0xFF6C4FFF),
                            iconBackground: const Color(0xFFF0ECFF),
                            rows: accountRows,
                          ),
                          const SizedBox(height: 24),
                          _SettingsSectionCard(
                            title: 'Tùy chọn ứng dụng',
                            icon: Icons.settings_rounded,
                            iconColor: const Color(0xFF2483FF),
                            iconBackground: const Color(0xFFEAF4FF),
                            rows: appRows,
                          ),
                          const SizedBox(height: 24),
                          _SettingsSectionCard(
                            title: 'Hỗ trợ',
                            icon: Icons.favorite_rounded,
                            iconColor: const Color(0xFF7A59FF),
                            iconBackground: const Color(0xFFF4EDFF),
                            rows: supportRows,
                          ),
                          const SizedBox(height: 24),
                          _LogoutCard(onTap: _logout),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsBackground extends StatelessWidget {
  const _SettingsBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -48,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x1A7D63FF), Color(0x104BDEFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: 62,
            right: 54,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                gradient: const LinearGradient(
                  colors: [Color(0x1EE394FF), Color(0x335E4BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          const Positioned(
            top: 82,
            right: 190,
            child: _StarSparkle(size: 16, color: Color(0x668A6DFF)),
          ),
          const Positioned(
            top: 98,
            right: 142,
            child: _StarSparkle(size: 12, color: Color(0x55FFF8FE)),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.onEdit,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        return Container(
          padding: EdgeInsets.all(isCompact ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120E1238),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                bottom: -50,
                child: Container(
                  width: 260,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    gradient: const LinearGradient(
                      colors: [Color(0x10A88CFF), Color(0x1D735BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileIdentity(
                          displayName: displayName,
                          username: username,
                          avatarUrl: avatarUrl,
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _EditButton(onTap: onEdit),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _ProfileIdentity(
                            displayName: displayName,
                            username: username,
                            avatarUrl: avatarUrl,
                          ),
                        ),
                        const SizedBox(width: 20),
                        _EditButton(onTap: onEdit),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEFEAFF), Color(0xFFD8E4FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) =>
                            _AvatarFallback(label: displayName, fontSize: 34),
                      )
                    : _AvatarFallback(label: displayName, fontSize: 34),
              ),
            ),
            Positioned(
              right: -2,
              bottom: 10,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B5CFF), Color(0xFF8D5CFF)],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x226B5CFF),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171531),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF767091),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: Color(0xFF6B4EFF),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tài khoản cá nhân',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B4EFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6DEFF)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_rounded, size: 18, color: Color(0xFF6B4EFF)),
            SizedBox(width: 10),
            Text(
              'Chỉnh sửa',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B4EFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final List<_SettingRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100E1238),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF212043),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++) ...[
              _SettingRow(data: rows[i]),
              if (i != rows.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0EEF9),
                  indent: 56,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.data});

  final _SettingRowData data;

  @override
  Widget build(BuildContext context) {
    final canTap = data.onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: data.trailing?.type == _TrailingType.switcher ? null : data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: data.iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, size: 22, color: data.iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF171531),
                ),
              ),
            ),
            if (data.trailing != null) ...[
              _SettingTrailingView(trailing: data.trailing!),
              if (canTap && data.trailing!.type != _TrailingType.switcher)
                const SizedBox(width: 10),
            ],
            if (canTap && data.trailing?.type != _TrailingType.switcher)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF918CAA),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingTrailingView extends StatelessWidget {
  const _SettingTrailingView({required this.trailing});

  final _SettingRowTrailing trailing;

  @override
  Widget build(BuildContext context) {
    switch (trailing.type) {
      case _TrailingType.text:
        return Text(
          trailing.textValue!,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF918CAA),
            fontWeight: FontWeight.w500,
          ),
        );
      case _TrailingType.switcher:
        return Transform.scale(
          scale: 0.96,
          child: Switch(
            value: trailing.switchValue!,
            onChanged: trailing.onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF694CFF),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E2F3),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        );
    }
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0E1238),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFFF3B30),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Đăng xuất',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF3B30),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF918CAA),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.label, required this.fontSize});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? 'M' : label.trim().characters.first;

    return Container(
      color: const Color(0xFFECE6FF),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6B4EFF),
        ),
      ),
    );
  }
}

class _StarSparkle extends StatelessWidget {
  const _StarSparkle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome, size: size, color: color);
  }
}

class _SettingRowData {
  const _SettingRowData({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final VoidCallback? onTap;
  final _SettingRowTrailing? trailing;
}

enum _TrailingType { text, switcher }

class _SettingRowTrailing {
  const _SettingRowTrailing.text(this.textValue)
    : type = _TrailingType.text,
      switchValue = null,
      onChanged = null;

  const _SettingRowTrailing.switcher({
    required this.switchValue,
    required this.onChanged,
  }) : type = _TrailingType.switcher,
       textValue = null;

  final _TrailingType type;
  final String? textValue;
  final bool? switchValue;
  final ValueChanged<bool>? onChanged;
}
