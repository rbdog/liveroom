import 'package:flutter/material.dart';
import 'package:room_server/room_server.dart';

final roomServer = RoomServer();

void main() {
  final app = RoomServerTestApp(roomServer);
  runApp(app);
}
