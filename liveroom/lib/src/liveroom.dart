import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum _LiveAction {
  join(0),
  message(1),
  exit(2);

  final int rawValue;
  const _LiveAction(this.rawValue);
  factory _LiveAction.from({required int rawValue}) {
    final value = _LiveAction.values.firstWhere((e) => e.rawValue == rawValue);
    return value;
  }
}

class _LiveMail {
  _LiveMail({
    required this.action,
    required this.seatId,
    required this.message,
  });
  final _LiveAction action;
  final String seatId;
  final String message;
  _LiveMail.fromJson(Map<String, dynamic> json)
      : action = _LiveAction.from(rawValue: json['action']),
        seatId = json['seat_id'],
        message = json['message'];
  Map<String, dynamic> toJson() => {
        'action': action,
        'seat_id': seatId,
        'message': message,
      };
}

enum Scheme {
  ws('ws');

  final String rawValue;
  const Scheme(this.rawValue);
}

class _LiveroomConfig {
  _LiveroomConfig({
    required this.scheme,
    required this.host,
    required this.rootPath,
    required this.port,
  });

  final Scheme scheme;
  final String host;
  final String rootPath;
  final int port;
  String? roomId;
  String? seatId;
}

class Liveroom {
  Liveroom({
    Scheme scheme = Scheme.ws,
    String host = '0.0.0.0',
    String rootPath = '/liveroom',
    int port = 5000,
    this.logger,
  }) : _config = _LiveroomConfig(
          scheme: scheme,
          host: host,
          rootPath: rootPath,
          port: port,
        );

  WebSocketChannel? _channel;
  var _sendCtrl = StreamController<_LiveMail>.broadcast();
  var _joinCtrl = StreamController<String>.broadcast();
  var _exitCtrl = StreamController<String>.broadcast();
  var _errCtrl = StreamController<String>.broadcast();
  final _LiveroomConfig _config;
  final void Function(String log)? logger;

  // connect WebSocket
  void _connect(
    String apiPath,
    String roomId, {
    required String? optSeatId,
    required void Function(Object error) onError,
  }) {
    logger?.call('_connect called');
    final seatId = optSeatId ?? const Uuid().v4();
    final url = Uri(
      scheme: _config.scheme.rawValue,
      host: _config.host,
      path: _config.rootPath + apiPath,
      port: _config.port,
      queryParameters: {
        'room_id': roomId,
        'seat_id': seatId,
      },
    );
    logger?.call('Connecting: ${url.toString()}');
    _channel = WebSocketChannel.connect(url);

    // save roomId, seatId
    _config.roomId = roomId;
    _config.seatId = seatId;
    // WebSocket Listen
    _channel?.stream.listen(
      (event) {
        final json = jsonDecode(event);
        final mail = _LiveMail.fromJson(json);
        switch (mail.action) {
          case _LiveAction.join:
            _joinCtrl.sink.add(mail.seatId);
            break;
          case _LiveAction.message:
            _sendCtrl.sink.add(mail);
            break;
          case _LiveAction.exit:
            _exitCtrl.sink.add(mail.seatId);
            break;
          default:
            break;
        }
      },
      cancelOnError: true,
      onError: (Object error) {
        logger?.call('ConnectingError: ${error.toString()}');
        onError(error);
      },
      onDone: () {
        /// disconnected
        _exitCtrl.sink.add(seatId);
      },
    );
  }

  bool get isJoined {
    return _channel != null;
  }

  String? get mySeatId {
    return _config.seatId;
  }

  /// create Room
  Future<void> create({required String roomId, String? seatId}) async {
    logger?.call('create called');
    if (isJoined) {
      logger?.call('exiting old room ...');
      await exit();
      logger?.call('exited old room');
    }
    _connect(
      '/create',
      roomId,
      optSeatId: seatId,
      onError: (Object error) {
        _errCtrl.sink.add(error.toString());
      },
    );
  }

  /// join Room
  Future<void> join({required String roomId, String? seatId}) async {
    logger?.call('join called');
    if (isJoined) {
      logger?.call('exiting old room ...');
      await exit();
      logger?.call('exited old room');
    }
    _connect(
      '/join',
      roomId,
      optSeatId: seatId,
      onError: (Object error) {
        _errCtrl.sink.add(error.toString());
      },
    );
  }

  /// listen for someone's join
  StreamSubscription onJoin(void Function(String seatId) process) {
    logger?.call('onJoin called');
    final subs = _joinCtrl.stream.listen((body) {
      process(body);
    });
    return subs;
  }

  // send message to the room
  void send({required String message}) {
    logger?.call('send called');
    if (!isJoined) {
      logger?.call('Not joined Room');
      return;
    }
    _channel?.sink.add(message);
  }

  /// listen for someone's message
  StreamSubscription receive(
    void Function(String seatId, String message) process,
  ) {
    logger?.call('receive called');
    final subs = _sendCtrl.stream.listen((liveEvent) {
      process(liveEvent.seatId, liveEvent.message);
    });
    return subs;
  }

  // exit room
  Future<void> exit() async {
    logger?.call('exit called');
    await _channel?.sink.close();
    _channel = null;
    _config.roomId = null;
  }

  /// listen for someone's exit
  StreamSubscription onExit(void Function(String seatId) process) {
    logger?.call('onExit called');
    final subs = _exitCtrl.stream.listen((body) {
      process(body);
    });
    return subs;
  }

  /// listen for error
  StreamSubscription onError(void Function(String errorMessage) process) {
    logger?.call('onError called');
    final subs = _errCtrl.stream.listen((errString) {
      process(errString);
    });
    return subs;
  }

  /// * RESET ALL Liveroom state
  Future<void> reset() async {
    logger?.call('reset called');
    await _sendCtrl.sink.close();
    await _joinCtrl.sink.close();
    await _exitCtrl.sink.close();
    await _errCtrl.sink.close();
    _sendCtrl = StreamController<_LiveMail>.broadcast();
    _joinCtrl = StreamController<String>.broadcast();
    _exitCtrl = StreamController<String>.broadcast();
    _errCtrl = StreamController<String>.broadcast();
    await _channel?.sink.close();
    _channel = null;
    _config.roomId = null;
  }
}
