import 'dart:async';

import 'package:flutter/material.dart';

/// 系统时间显示组件 - 使用 StatefulWidget 避免 Stream 多次监听问题
class SystemTimeDisplay extends StatefulWidget {
  const SystemTimeDisplay({super.key});

  @override
  State<SystemTimeDisplay> createState() => _SystemTimeDisplayState();
}

class _SystemTimeDisplayState extends State<SystemTimeDisplay> {
  late Timer _timer;
  late String _timeStr;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _timeStr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
