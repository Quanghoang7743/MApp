import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const InterestCalculatorScreen(),
    );
  }
}

class InterestCalculatorScreen extends StatelessWidget {
  const InterestCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black,
        leading: const Icon(Icons.menu),
        title: const Text(
          "Máy tính lãi suất",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: const [
          Icon(Icons.more_vert),
          SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input 1
            const Text("Số tiền"),
            const SizedBox(height: 6),
            TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 16),

            // Input 2
            const Text("Lãi hằng năm"),
            const SizedBox(height: 6),
            TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 20),

            // Text result label
            const Text(
              "Số năm để tiền tăng gấp đôi",
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 20),

            // Button
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text("Tính toán"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}