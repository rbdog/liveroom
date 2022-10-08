// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ペイロード
class Payload {
  // join | message | exit
  final String bodyType;
  // クライアントID
  final String clientId;
  // メッセージ本文
  final String body;
  Payload({
    required this.bodyType,
    required this.clientId,
    required this.body,
  });
  // JSON 変換
  Payload.fromJson(Map<String, dynamic> json)
      : bodyType = json['body_type'],
        clientId = json['client_id'],
        body = json['body'];
  Map<String, dynamic> toJson() => {
        'body_type': bodyType,
        'client_id': clientId,
        'body': body,
      };
}

enum Scheme {
  ws('ws');

  final String rawValue;
  const Scheme(this.rawValue);
}

class RoomServerConfig {
  final Scheme scheme;
  final String host;
  final String path;
  final int port;
  String? clientId;
  String? roomId;

  RoomServerConfig({
    required this.scheme,
    required this.host,
    required this.path,
    required this.port,
  });
}

// オンラインのルーム
class RoomServer {
  // WebSocket
  WebSocketChannel? _channel;
  final _sendCtrl = StreamController<String>.broadcast();
  final _joinCtrl = StreamController<String>.broadcast();
  final _exitCtrl = StreamController<String>.broadcast();
  final RoomServerConfig config;
  final List<StreamSubscription> subsList = [];

  RoomServer({
    Scheme scheme = Scheme.ws,
    String host = '0.0.0.0',
    String path = '/rooms',
    int port = 3000,
  }) : config = RoomServerConfig(
          scheme: scheme,
          host: host,
          path: path,
          port: port,
        );

  // WebSocket接続
  void _connect(
    String command,
    String roomId, {
    required String? optClientId,
  }) {
    final clientId = optClientId ?? const Uuid().v4();
    final url = Uri(
      scheme: config.scheme.rawValue,
      host: config.host,
      path: config.path,
      port: config.port,
      queryParameters: {
        'command': command,
        'room_id': roomId,
        'client_id': clientId,
      },
    );
    _channel = WebSocketChannel.connect(url);
    // save roomId, clientId
    config.roomId = roomId;
    config.clientId = clientId;
    // WebSocket 受信
    final subs = _channel?.stream.listen((event) {
      final json = jsonDecode(event);
      final payload = Payload.fromJson(json);
      switch (payload.bodyType) {
        case 'join':
          _joinCtrl.sink.add(payload.body);
          break;
        case 'message':
          _sendCtrl.sink.add(payload.body);
          break;
        case 'exit':
          _exitCtrl.sink.add(payload.body);
          break;
        default:
          break;
      }
    });
    if (subs != null) {
      subsList.add(subs);
    }
  }

  // ルームを作成
  void create({required String roomId, String? clientId}) {
    if (_channel != null) {
      print('Error: already joined room');
      return;
    }
    _connect('create', roomId, optClientId: clientId);
  }

  // ルームに参加
  void join({required String roomId, String? clientId}) {
    if (_channel != null) {
      print('Error: already joined room');
      return;
    }
    _connect('join', roomId, optClientId: clientId);
  }

  // 誰かが入室した時
  void onJoin(void Function(String clientId) process) {
    final subs = _joinCtrl.stream.listen((body) {
      process(body);
    });
    subsList.add(subs);
  }

  // メッセージを受け取った時の処理
  void onSend(void Function(String message) process) {
    final subs = _sendCtrl.stream.listen((body) {
      process(body);
    });
    subsList.add(subs);
  }

  // 誰かが退出した時
  void onExit(void Function(String clientId) process) {
    final subs = _exitCtrl.stream.listen((body) {
      process(body);
    });
    subsList.add(subs);
  }

  // メッセージをルーム内全員に送信
  void send({required String message}) {
    _channel?.sink.add(message);
  }

  // ルームを退出
  Future<void> exit() async {
    for (final subs in subsList) {
      await subs.cancel();
    }
    subsList.clear();
    _channel?.sink.close();
    _channel = null;
    config.roomId = null;
  }
}
