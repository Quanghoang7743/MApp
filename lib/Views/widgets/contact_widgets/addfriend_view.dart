import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../models/resolved_contact_suggestion.dart';
import '../../../providers/contact_sync_provider.dart';
import '../../../providers/friend_provider.dart';

class AddFriendView extends StatefulWidget {
  const AddFriendView({super.key});

  @override
  State<AddFriendView> createState() => _AddFriendViewState();
}

class _AddFriendViewState extends State<AddFriendView> {
  final TextEditingController _searchController = TextEditingController();
  _RequestTab _activeTab = _RequestTab.incoming;
  ContactSyncProvider? _contactSyncProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final friendProvider = context.read<FriendProvider>();
      final contactSyncProvider = context.read<ContactSyncProvider>();
      _contactSyncProvider = contactSyncProvider;
      friendProvider.fetchIncomingRequests();
      friendProvider.fetchOutgoingRequests();
      _bootstrapContacts(contactSyncProvider);
    });
  }

  @override
  void dispose() {
    _contactSyncProvider?.cancelOngoingSync();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapContacts(
    ContactSyncProvider contactSyncProvider,
  ) async {
    await contactSyncProvider.initialize();
    if (!mounted || !contactSyncProvider.hasContactsAccess) {
      return;
    }
    if (contactSyncProvider.suggestions.isNotEmpty ||
        contactSyncProvider.isSyncingSuggestions) {
      return;
    }

    await contactSyncProvider.loadAndResolveContacts();
  }

  Future<void> _resolveByPhone(FriendProvider friendProvider) async {
    final phone = _searchController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại')),
      );
      return;
    }
    await friendProvider.resolveByPhone(phone);
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label đang được phát triển')));
  }

  Future<void> _showContactsEducationPrompt(
    ContactSyncProvider contactSyncProvider,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cho phép truy cập danh bạ'),
        content: const Text(
          'MoxChat cần quyền danh bạ để đọc số điện thoại từ máy và gợi ý thêm bạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    await contactSyncProvider.markPrePermissionPromptHandled();
    if (accepted != true) {
      return;
    }

    final granted = await contactSyncProvider.requestContactsAccess();
    if (!mounted || !granted) {
      return;
    }

    await contactSyncProvider.loadAndResolveContacts(forceRefresh: true);
  }

  Future<void> _handleContactsSyncAction(
    ContactSyncProvider contactSyncProvider,
  ) async {
    await contactSyncProvider.initialize();
    if (!mounted || !contactSyncProvider.isSupportedPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tinh nang nay chi ho tro tren Android va iOS'),
        ),
      );
      return;
    }

    if (contactSyncProvider.shouldShowPrePermissionPrompt) {
      await _showContactsEducationPrompt(contactSyncProvider);
      return;
    }

    if (contactSyncProvider.shouldShowOpenSettings) {
      await contactSyncProvider.openSystemSettings();
      return;
    }

    if (!contactSyncProvider.hasContactsAccess) {
      final granted = await contactSyncProvider.requestContactsAccess();
      if (!mounted || !granted) {
        return;
      }
    }

    await contactSyncProvider.loadAndResolveContacts(forceRefresh: true);
  }

  Future<void> _sendSuggestionInvite(
    FriendProvider friendProvider,
    ResolvedContactSuggestion suggestion,
  ) async {
    final resolvedUser = suggestion.resolvedUser;
    final receiverId = (resolvedUser?['id'] ?? resolvedUser?['user_id'] ?? '')
        .toString();
    if (receiverId.isEmpty) {
      return;
    }

    final ok = await friendProvider.sendFriendRequest(receiverId: receiverId);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Đã gửi lời mời' : 'Gửi lời mời thất bại')),
    );

    if (ok) {
      await context.read<ContactSyncProvider>().loadAndResolveContacts();
    }
  }

  String _suggestionActionLabel(ResolvedContactSuggestionStatus status) {
    switch (status) {
      case ResolvedContactSuggestionStatus.canInvite:
        return 'Gửi lời mời';
      case ResolvedContactSuggestionStatus.alreadyFriend:
        return 'Đã là bạn';
      case ResolvedContactSuggestionStatus.requestSent:
        return 'Đã gửi';
      case ResolvedContactSuggestionStatus.requestReceived:
        return 'Đã nhận lời mời';
      case ResolvedContactSuggestionStatus.notFound:
        return 'Chưa có tài khoản';
      case ResolvedContactSuggestionStatus.lookupFailed:
        return 'Thử lại sau';
    }
  }

  bool _canInviteSuggestion(ResolvedContactSuggestion suggestion) {
    return suggestion.status == ResolvedContactSuggestionStatus.canInvite;
  }

  Widget _buildContactsSuggestionSection(
    FriendProvider friendProvider,
    ContactSyncProvider contactSyncProvider,
  ) {
    final hasResults = contactSyncProvider.suggestions.isNotEmpty;
    final buttonLabel = contactSyncProvider.shouldShowOpenSettings
        ? 'Mở cài đặt'
        : contactSyncProvider.hasContactsAccess
        ? 'Đồng bộ danh bạ'
        : 'Cho phép truy cập danh bạ';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140E123D),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gợi ý từ danh bạ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1D45),
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: contactSyncProvider.isSyncingSuggestions
                    ? null
                    : () => _handleContactsSyncAction(contactSyncProvider),
                child: Text(buttonLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            contactSyncProvider.hasContactsAccess
                ? 'Đọc toàn bộ số trên điện thoại và gợi ý tài khoản có thể kết bạn.'
                : 'Cấp quyền danh bạ để MoxChat có thể đọc số điện thoại trên máy.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF7A8097),
            ),
          ),
          if (contactSyncProvider.lookupError != null) ...[
            const SizedBox(height: 10),
            Text(
              contactSyncProvider.lookupError!,
              style: const TextStyle(
                color: Color(0xFFCC4660),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (contactSyncProvider.isLoadingContacts ||
              contactSyncProvider.isSyncingSuggestions) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              contactSyncProvider.isLoadingContacts
                  ? 'Đang đọc danh bạ trên máy...'
                  : 'Đang kiểm tra tài khoản từ danh bạ...',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF707792),
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (!hasResults) ...[
            const SizedBox(height: 16),
            Text(
              contactSyncProvider.hasContactsAccess
                  ? 'Chưa có gợi ý nào từ danh bạ. Hãy thử đồng bộ để tải dữ liệu mới.'
                  : 'Bạn chưa cấp quyền danh bạ nên MoxChat chưa thể đọc số điện thoại trên máy.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8B90A8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            for (final suggestion in contactSyncProvider.suggestions) ...[
              _ContactSuggestionTile(
                suggestion: suggestion,
                actionLabel: _suggestionActionLabel(suggestion.status),
                enabled:
                    _canInviteSuggestion(suggestion) &&
                    !friendProvider.isSendingRequest,
                onPressed: () =>
                    _sendSuggestionInvite(friendProvider, suggestion),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  String _requestId(Map<String, dynamic> request) {
    return (request['id'] ?? request['request_id'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final friendProvider = context.watch<FriendProvider>();
    final contactSyncProvider = context.watch<ContactSyncProvider>();
    final resolvedUser = friendProvider.resolvedUser;
    final isIncoming = _activeTab == _RequestTab.incoming;
    final activeRequests = isIncoming
        ? friendProvider.incomingRequests
        : friendProvider.outgoingRequests;
    final isLoading = isIncoming
        ? friendProvider.isLoadingIncoming
        : friendProvider.isLoadingOutgoing;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await friendProvider.fetchIncomingRequests();
                  await friendProvider.fetchOutgoingRequests();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 32,
                                      color: Color(0xFF1C1E45),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text(
                                    'Thêm bạn',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF181B42),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Kết nối với bạn bè bằng số điện thoại\nhoặc lời mời.',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Color(0xFF767B97),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const _HeroIllustration(),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 74,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x140E123D),
                                  blurRadius: 24,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      hintText: 'Nhập số điện thoại',
                                      hintStyle: TextStyle(
                                        color: Color(0xFFADB1C4),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: double.infinity,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF5D63FF),
                                          Color(0xFF7A53FF),
                                        ],
                                      ),
                                    ),
                                    child: FilledButton(
                                      onPressed: friendProvider.isResolving
                                          ? null
                                          : () =>
                                                _resolveByPhone(friendProvider),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 28,
                                        ),
                                      ),
                                      child: friendProvider.isResolving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Tìm',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _SquareActionButton(
                          onTap: () => _showComingSoon('Quét QR'),
                          child: SvgPicture.asset(
                            'assets/icons/qr-scanner.svg',
                            width: 28,
                            height: 28,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF2B2E54),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (friendProvider.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          friendProvider.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFCC4660),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (resolvedUser != null) ...[
                      const SizedBox(height: 18),
                      _ResolvedUserCard(
                        user: resolvedUser,
                        isSending: friendProvider.isSendingRequest,
                        onSendRequest: () async {
                          final receiverId =
                              (resolvedUser['id'] ??
                                      resolvedUser['user_id'] ??
                                      '')
                                  .toString();
                          if (receiverId.isEmpty) {
                            return;
                          }

                          final ok = await friendProvider.sendFriendRequest(
                            receiverId: receiverId,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Đã gửi lời mời' : 'Gửi lời mời thất bại',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildContactsSuggestionSection(
                      friendProvider,
                      contactSyncProvider,
                    ),
                    const SizedBox(height: 22),
                    _SegmentedTabs(
                      activeTab: _activeTab,
                      incomingCount: friendProvider.incomingRequests.length,
                      outgoingCount: friendProvider.outgoingRequests.length,
                      onChanged: (tab) {
                        setState(() {
                          _activeTab = tab;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      title: isIncoming
                          ? 'Lời mời nhận được'
                          : 'Lời mời đã gửi',
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 14),
                    if (activeRequests.isEmpty && !isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          isIncoming
                              ? 'Chưa có lời mời nào.'
                              : 'Chưa có lời mời đã gửi.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF8B90A8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ...activeRequests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _RequestTile(
                          request: request,
                          type: isIncoming
                              ? _RequestType.incoming
                              : _RequestType.outgoing,
                          isProcessing: friendProvider.isProcessingRequest,
                          onAccept: isIncoming
                              ? () async {
                                  final id = _requestId(request);
                                  if (id.isEmpty) {
                                    return;
                                  }
                                  final ok = await friendProvider.acceptRequest(
                                    id,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Đã chấp nhận lời mời'
                                            : 'Thao tác thất bại',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          onReject: isIncoming
                              ? () async {
                                  final id = _requestId(request);
                                  if (id.isEmpty) {
                                    return;
                                  }
                                  final ok = await friendProvider.rejectRequest(
                                    id,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Đã từ chối lời mời'
                                            : 'Thao tác thất bại',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          onCancel: !isIncoming
                              ? () async {
                                  final id = _requestId(request);
                                  if (id.isEmpty) {
                                    return;
                                  }
                                  final ok = await friendProvider.cancelRequest(
                                    id,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Đã hủy lời mời'
                                            : 'Hủy lời mời thất bại',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RequestTab { incoming, outgoing }

enum _RequestType { incoming, outgoing }

class _ContactSuggestionTile extends StatelessWidget {
  const _ContactSuggestionTile({
    required this.suggestion,
    required this.actionLabel,
    required this.enabled,
    required this.onPressed,
  });

  final ResolvedContactSuggestion suggestion;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final userName =
        (suggestion.resolvedUser?['name'] ??
                suggestion.resolvedUser?['full_name'] ??
                suggestion.resolvedUser?['username'])
            ?.toString()
            .trim();
    final subtitle = userName != null && userName.isNotEmpty
        ? '$userName • ${suggestion.contact.rawPhone}'
        : suggestion.contact.rawPhone;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFEAE3FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsFromDisplayName(suggestion.contact.displayName),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5F4CFF),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.contact.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191C44),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8187A0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: enabled ? onPressed : null,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  static String _initialsFromDisplayName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          _bubble(const Alignment(0.15, -0.75), 44, const Color(0xFF77A5FF)),
          _bubble(const Alignment(0.88, -0.25), 42, const Color(0xFFA46BFF)),
          _bubble(const Alignment(0.05, 0.38), 38, const Color(0xFFE4E3FF)),
          _bubble(const Alignment(-0.45, 0.18), 34, const Color(0xFFEFF0FF)),
          Align(
            alignment: const Alignment(0.4, 0.45),
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCFA6FF), Color(0xFF9D63FF)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x339F69FF),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Alignment alignment, double size, Color color) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0E123D),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareActionButton extends StatelessWidget {
  const _SquareActionButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140E123D),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.activeTab,
    required this.incomingCount,
    required this.outgoingCount,
    required this.onChanged,
  });

  final _RequestTab activeTab;
  final int incomingCount;
  final int outgoingCount;
  final ValueChanged<_RequestTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E123D),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTabButton(
              label: 'Đã nhận',
              count: incomingCount,
              selected: activeTab == _RequestTab.incoming,
              onTap: () => onChanged(_RequestTab.incoming),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SegmentTabButton(
              label: 'Đã gửi',
              count: outgoingCount,
              selected: activeTab == _RequestTab.outgoing,
              onTap: () => onChanged(_RequestTab.outgoing),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTabButton extends StatelessWidget {
  const _SegmentTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF5D63FF), Color(0xFF7A53FF)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF2B2E54),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF2F3F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF6E7391),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.isLoading});

  final String title;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D2148),
          ),
        ),
        const SizedBox(width: 8),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _ResolvedUserCard extends StatelessWidget {
  const _ResolvedUserCard({
    required this.user,
    required this.onSendRequest,
    required this.isSending,
  });

  final Map<String, dynamic> user;
  final VoidCallback onSendRequest;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final name =
        (user['name'] ??
                user['full_name'] ??
                user['username'] ??
                user['phone_number'] ??
                'Unknown')
            .toString();
    final subtitle = _userSubtitle(user);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E123D),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _UserAvatar(user: user, name: name, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202347),
                  ),
                ),
                const SizedBox(height: 4),
                _UserSubtitle(subtitle: subtitle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _GradientActionButton(
            label: 'Gửi lời mời',
            onTap: isSending ? null : onSendRequest,
            isLoading: isSending,
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.type,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
  });

  final Map<String, dynamic> request;
  final _RequestType type;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final userMap = _extractUserMap(request);
    final name =
        (userMap['name'] ??
                userMap['full_name'] ??
                userMap['username'] ??
                userMap['phone_number'] ??
                'Unknown')
            .toString();
    final subtitle = _userSubtitle(userMap);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E123D),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _UserAvatar(user: userMap, name: name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2348),
                  ),
                ),
                const SizedBox(height: 4),
                _UserSubtitle(subtitle: subtitle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (type == _RequestType.incoming) ...[
            _OutlineActionButton(
              label: 'Từ chối',
              onTap: isProcessing ? null : onReject,
            ),
            const SizedBox(width: 10),
            _GradientActionButton(
              label: 'Chấp nhận',
              onTap: isProcessing ? null : onAccept,
            ),
          ] else
            _OutlineActionButton(
              label: 'Hủy',
              onTap: isProcessing ? null : onCancel,
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _extractUserMap(Map<String, dynamic> request) {
    if (type == _RequestType.incoming) {
      final sender = request['sender'];
      if (sender is Map<String, dynamic>) {
        return sender;
      }
    }

    if (type == _RequestType.outgoing) {
      final receiver = request['receiver'];
      if (receiver is Map<String, dynamic>) {
        return receiver;
      }
    }

    final user = request['user'];
    if (user is Map<String, dynamic>) {
      return user;
    }

    return request;
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.user,
    required this.name,
    required this.size,
  });

  final Map<String, dynamic> user;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        (user['avatar_url'] ?? user['avatarUrl'] ?? user['photo_url'])
            ?.toString();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE8DEFF),
      ),
      child: avatarUrl != null && avatarUrl.trim().isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _AvatarFallback(name: name),
            )
          : _AvatarFallback(name: name),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6652E0),
        ),
      ),
    );
  }
}

class _UserSubtitle extends StatelessWidget {
  const _UserSubtitle({required this.subtitle});

  final _SubtitleData subtitle;

  @override
  Widget build(BuildContext context) {
    if (subtitle.isStatus) {
      return Row(
        children: [
          const Icon(Icons.circle, size: 10, color: Color(0xFF3ED16D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8A8FA8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      subtitle.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF8A8FA8),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF5D63FF), Color(0xFF7A53FF)],
        ),
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4A4E6D),
        side: const BorderSide(color: Color(0xFFDADCF0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SubtitleData {
  const _SubtitleData({required this.text, required this.isStatus});

  final String text;
  final bool isStatus;
}

_SubtitleData _userSubtitle(Map<String, dynamic> user) {
  final phone = (user['phone_number'] ?? '').toString().trim();
  if (phone.isNotEmpty) {
    return _SubtitleData(text: phone, isStatus: false);
  }

  final username = (user['username'] ?? '').toString().trim();
  if (username.isNotEmpty) {
    return _SubtitleData(text: username, isStatus: false);
  }

  return const _SubtitleData(text: 'Vừa hoạt động', isStatus: true);
}
