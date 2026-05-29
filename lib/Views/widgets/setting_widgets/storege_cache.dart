import 'package:flutter/material.dart';

import '../../../services/local/chat_cache_service.dart';

class StorageCacheView extends StatefulWidget {
  const StorageCacheView({super.key, this.cacheService});

  final ChatCacheService? cacheService;

  @override
  State<StorageCacheView> createState() => _StorageCacheViewState();
}

class _StorageCacheViewState extends State<StorageCacheView> {
  late final ChatCacheService _cacheService;
  ChatCacheStats _stats = const ChatCacheStats(
    chatListBytes: 0,
    messageBytes: 0,
    totalBytes: 0,
    conversationCacheCount: 0,
  );
  bool _isLoading = true;
  bool _isClearingChatList = false;
  bool _isClearingMessages = false;

  @override
  void initState() {
    super.initState();
    _cacheService = widget.cacheService ?? ChatCacheService();
    Future.microtask(_refreshStats);
  }

  Future<void> _refreshStats() async {
    final stats = await _cacheService.getStorageStats();
    if (!mounted) {
      return;
    }

    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _handleClearChatList() async {
    await _runClearAction(
      title: 'Xóa bộ nhớ đệm',
      content:
          'Thao tác này sẽ xóa danh sách trò chuyện đã lưu cục bộ. Tin nhắn trên máy chủ không bị ảnh hưởng.',
      onConfirm: () => _cacheService.clearChatList(),
      successMessage: 'Đã xóa bộ nhớ đệm danh sách trò chuyện',
      setLoading: (value) {
        _isClearingChatList = value;
      },
    );
  }

  Future<void> _handleClearMessages() async {
    await _runClearAction(
      title: 'Xóa dữ liệu cuộc trò chuyện',
      content:
          'Thao tác này sẽ xóa toàn bộ tin nhắn đã cache trên máy. Tin nhắn trên máy chủ không bị ảnh hưởng.',
      onConfirm: () => _cacheService.clearAllMessages(),
      successMessage: 'Đã xóa dữ liệu cuộc trò chuyện trên máy',
      setLoading: (value) {
        _isClearingMessages = value;
      },
    );
  }

  Future<void> _runClearAction({
    required String title,
    required String content,
    required Future<void> Function() onConfirm,
    required String successMessage,
    required void Function(bool value) setLoading,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      setLoading(true);
    });

    try {
      await onConfirm();
      await _refreshStats();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(successMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Không thể xóa dữ liệu: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        setLoading(false);
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isClearingChatList || _isClearingMessages;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Dữ liệu trên máy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng dữ liệu local',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const LinearProgressIndicator()
                    else
                      Text(
                        '${_formatBytes(_stats.totalBytes)} trên ${_stats.conversationCacheCount} cuộc trò chuyện được cache',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5E6477),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _StorageSectionCard(
                title: 'Bộ nhớ đệm',
                description:
                    'Dữ liệu tạm thời của danh sách trò chuyện. Xóa phần này không ảnh hưởng đến dữ liệu trên máy chủ.',
                usage: 'Đang dùng: ${_formatBytes(_stats.chatListBytes)}',
                busy: _isClearingChatList,
                enabled: !isBusy && _stats.chatListBytes > 0,
                buttonLabel: 'Xóa bộ nhớ đệm',
                onPressed: _handleClearChatList,
              ),
              const SizedBox(height: 20),
              _StorageSectionCard(
                title: 'Dữ liệu cuộc trò chuyện',
                description:
                    'Các tin nhắn đã lưu trên máy để mở lại nhanh khi không ổn định mạng.',
                usage:
                    'Đang dùng: ${_formatBytes(_stats.messageBytes)} trong ${_stats.conversationCacheCount} cuộc trò chuyện',
                busy: _isClearingMessages,
                enabled: !isBusy && _stats.messageBytes > 0,
                buttonLabel: 'Xóa dữ liệu cuộc trò chuyện',
                onPressed: _handleClearMessages,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageSectionCard extends StatelessWidget {
  const _StorageSectionCard({
    required this.title,
    required this.description,
    required this.usage,
    required this.buttonLabel,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String usage;
  final String buttonLabel;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(description),
          const SizedBox(height: 8),
          Text(
            usage,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5E6477),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            child: ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFF2C5C5),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
