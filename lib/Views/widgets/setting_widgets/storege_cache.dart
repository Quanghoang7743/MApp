import 'package:flutter/material.dart';

class StorageCacheView extends StatefulWidget {
  const StorageCacheView({super.key});

  @override
  State<StorageCacheView> createState() => _StorageCacheViewState();
}

class _StorageCacheViewState extends State<StorageCacheView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
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
            ),
            
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bộ nhớ đệm',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    const Text (
                      'Dữ liệu tạm thời được sinh ra khi dùng Moxchat, Dọn dẹp bộ nhớ đệm không ảnh hưởng đến các tin nhắn và tệp đã gửi, tải về'
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      // width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Implement delete cache
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Xóa bộ nhớ đệm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              )
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                width: double.infinity,
                decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dữ liệu cuộc trò chuyện',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  const Text (
                    'Các tin nhắn văn bản, ảnh, video, tin nhắn thoại và file của bạn'
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    // width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement delete cache
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Xóa bộ nhớ đệm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
                )
              )
              
            ),
          ],
        ),
      ),
    );
  }
}