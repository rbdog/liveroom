import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';

final liveroom = Liveroom();

void main() {
  final app = LiveroomTestApp(liveroom);
  runApp(app);
}
