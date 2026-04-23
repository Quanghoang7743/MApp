import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/friend_provider.dart';

class AddFriendView extends StatefulWidget {
  const AddFriendView({super.key});

  @override
  State<AddFriendView> createState() => _AddFriendViewState();
}

class _AddFriendViewState extends State<AddFriendView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final friendProvider = context.read<FriendProvider>();
      friendProvider.fetchIncomingRequests();
      friendProvider.fetchOutgoingRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendProvider = context.watch<FriendProvider>();
    final resolvedUser = friendProvider.resolvedUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  const Text(
                    'Thêm bạn',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Nhap so dien thoai',
                        hintStyle: const TextStyle(color: Colors.black45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: friendProvider.isResolving
                        ? null
                        : () => _resolveByPhone(friendProvider),
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(0xFF007AFF),
                    ),
                    child: friendProvider.isResolving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tìm'),
                  ),
                ],
              ),
            ),
            if (friendProvider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  friendProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            if (resolvedUser != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ResolvedUserCard(
                  user: resolvedUser,
                  isSending: friendProvider.isSendingRequest,
                  onSendRequest: () async {
                    final receiverId =
                        (resolvedUser['id'] ?? resolvedUser['user_id'] ?? '')
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
                          ok ? 'Da gui loi moi' : 'Gui loi moi that bai',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await friendProvider.fetchIncomingRequests();
                  await friendProvider.fetchOutgoingRequests();
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _SectionTitle(
                      title: 'Lời mời nhận được',
                      isLoading: friendProvider.isLoadingIncoming,
                    ),
                    const SizedBox(height: 8),
                    ...friendProvider.incomingRequests.map(
                      (request) => _RequestTile(
                        request: request,
                        type: _RequestType.incoming,
                        isProcessing: friendProvider.isProcessingRequest,
                        onAccept: () async {
                          final id = _requestId(request);
                          if (id.isEmpty) {
                            return;
                          }
                          final ok = await friendProvider.acceptRequest(id);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Da chap nhan loi moi'
                                    : 'Thao tac that bai',
                              ),
                            ),
                          );
                        },
                        onReject: () async {
                          final id = _requestId(request);
                          if (id.isEmpty) {
                            return;
                          }
                          final ok = await friendProvider.rejectRequest(id);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Da tu choi loi moi' : 'Thao tac that bai',
                              ),
                            ),
                          );
                        },
                        onCancel: null,
                      ),
                    ),
                    if (friendProvider.incomingRequests.isEmpty)
                      const Text('Khong co loi moi nao'),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      title: 'Lời mời đã gửi',
                      isLoading: friendProvider.isLoadingOutgoing,
                    ),
                    const SizedBox(height: 8),
                    ...friendProvider.outgoingRequests.map(
                      (request) => _RequestTile(
                        request: request,
                        type: _RequestType.outgoing,
                        isProcessing: friendProvider.isProcessingRequest,
                        onAccept: null,
                        onReject: null,
                        onCancel: () async {
                          final id = _requestId(request);
                          if (id.isEmpty) {
                            return;
                          }
                          final ok = await friendProvider.cancelRequest(id);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Da huy loi moi' : 'Huy loi moi that bai',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (friendProvider.outgoingRequests.isEmpty)
                      const Text('Khong co loi moi da gui'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveByPhone(FriendProvider friendProvider) async {
    final phone = _searchController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui long nhap so dien thoai')),
      );
      return;
    }
    await friendProvider.resolveByPhone(phone);
  }

  String _requestId(Map<String, dynamic> request) {
    return (request['id'] ?? request['request_id'] ?? '').toString();
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        if (isLoading)
          const SizedBox(
            width: 14,
            height: 14,
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
    final subtitle = (user['phone_number'] ?? user['username'] ?? '')
        .toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(
              name.trim().isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          FilledButton(
            onPressed: isSending ? null : onSendRequest,
            child: isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Gửi lời mời'),
          ),
        ],
      ),
    );
  }
}

enum _RequestType { incoming, outgoing }

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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(
              name.trim().isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name)),
          if (type == _RequestType.incoming) ...[
            OutlinedButton(
              onPressed: isProcessing ? null : onReject,
              child: const Text('Từ chối'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isProcessing ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: Color(0xFF007AFF),
              ),
              child: const Text('Chấp nhận'),
            ),
          ] else
            OutlinedButton(
              onPressed: isProcessing ? null : onCancel,
              child: const Text('Hủy'),
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
