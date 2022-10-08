import 'package:flutter/material.dart';
import 'package:room_server_test/room_server.dart';
import 'package:room_server_test/room_server_test_view.dart';

final roomServer = RoomServer();

void main() {
  final app = RoomServerTestApp(roomServer);
  runApp(app);
}
