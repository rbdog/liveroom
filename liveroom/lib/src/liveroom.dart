// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum _BodyType {
  join(0),
  message(1),
  exit(2);

  final int rawValue;
  const _BodyType(this.rawValue);
  factory _BodyType.from({required int rawValue}) {
    final value = _BodyType.values.firstWhere((e) => e.rawValue == rawValue);
    return value;
  }
}

// ライブイベント
class _LiveEvent {
  // シートID
  final String seatId;
  // join | message | exit
  final _BodyType bodyType;
  // メッセージ本文
  final String body;
  _LiveEvent({
    required this.seatId,
    required this.bodyType,
    required this.body,
  });
  // JSON 変換
  _LiveEvent.fromJson(Map<String, dynamic> json)
      : seatId = json['seat_id'],
        bodyType = _BodyType.from(rawValue: json['body_type']),
        body = json['body'];
  Map<String, dynamic> toJson() => {
        'seat_id': seatId,
        'body_type': bodyType,
        'body': body,
      };
}

enum Scheme {
  ws('ws');

  final String rawValue;
  const Scheme(this.rawValue);
}

class LiveroomConfig {
  final Scheme scheme;
  final String host;
  final String rootPath;
  final int port;
  String? roomId;
  String? seatId;

  LiveroomConfig({
    required this.scheme,
    required this.host,
    required this.rootPath,
    required this.port,
  });
}

// ライブルーム
class Liveroom {
  // WebSocket
  WebSocketChannel? _channel;
  final _sendCtrl = StreamController<String>.broadcast();
  final _joinCtrl = StreamController<String>.broadcast();
  final _exitCtrl = StreamController<String>.broadcast();
  final LiveroomConfig config;
  final List<StreamSubscription> subsList = [];

  Liveroom({
    Scheme scheme = Scheme.ws,
    String host = '0.0.0.0',
    String rootPath = '/liveroom',
    int port = 3000,
  }) : config = LiveroomConfig(
          scheme: scheme,
          host: host,
          rootPath: rootPath,
          port: port,
        );

  // WebSocket接続
  void _connect(
    String apiPath,
    String roomId, {
    required String? optSeatId,
  }) {
    final seatId = optSeatId ?? const Uuid().v4();
    final url = Uri(
      scheme: config.scheme.rawValue,
      host: config.host,
      path: config.rootPath + apiPath,
      port: config.port,
      queryParameters: {
        'room_id': roomId,
        'seat_id': seatId,
      },
    );
    _channel = WebSocketChannel.connect(url);
    // save roomId, seatId
    config.roomId = roomId;
    config.seatId = seatId;
    // WebSocket 受信
    final subs = _channel?.stream.listen((event) {
      final json = jsonDecode(event);
      final liveEvent = _LiveEvent.fromJson(json);
      switch (liveEvent.bodyType) {
        case _BodyType.join:
          _joinCtrl.sink.add(liveEvent.body);
          break;
        case _BodyType.message:
          _sendCtrl.sink.add(liveEvent.body);
          break;
        case _BodyType.exit:
          _exitCtrl.sink.add(liveEvent.body);
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
  void create({required String roomId, String? seatId}) {
    if (_channel != null) {
      print('Error: already joined room');
      return;
    }
    _connect('/create', roomId, optSeatId: seatId);
  }

  // ルームに参加
  void join({required String roomId, String? seatId}) {
    if (_channel != null) {
      print('Error: already joined room');
      return;
    }
    _connect('/join', roomId, optSeatId: seatId);
  }

  // 誰かが入室した時
  void onJoin(void Function(String seatId) process) {
    final subs = _joinCtrl.stream.listen((body) {
      process(body);
    });
    subsList.add(subs);
  }

  // メッセージをルーム内全員に送信
  void send({required String message}) {
    if (_channel == null) {
      debugPrint('channel null');
    } else {
      debugPrint('message を送ります');
    }
    _channel?.sink.add(message);
  }

  // メッセージを受け取った時の処理
  void onSend(void Function(String message) process) {
    debugPrint('message を受け取りました');
    final subs = _sendCtrl.stream.listen((body) {
      process(body);
    });
    subsList.add(subs);
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

  // 誰かが退出した時
  void onExit(void Function(String seatId) process) {
    final subs = _exitCtrl.stream.listen((body) {
      process(body);
    });
    subsList.add(subs);
  }
}
