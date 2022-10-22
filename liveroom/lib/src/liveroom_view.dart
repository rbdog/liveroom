import 'dart:async';
import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';

/// LiveroomView can receive events
class LiveroomView extends StatefulWidget {
  const LiveroomView({
    required this.liveroom,
    this.onJoin,
    this.onReceive,
    this.onExit,
    required this.child,
    Key? key,
  }) : super(key: key);

  final Liveroom liveroom;

  /// Someone Joined
  final void Function(String seatId)? onJoin;

  /// Someone Sent message
  final void Function(String seatId, String message)? onReceive;

  /// Someone Exited
  final void Function(String seatId)? onExit;
  final Widget child;

  @override
  // ignore: library_private_types_in_public_api
  _LiveroomViewState createState() {
    return _LiveroomViewState();
  }
}

class _LiveroomViewState extends State<LiveroomView> {
  final List<StreamSubscription> subsList = [];

  @override
  void initState() {
    super.initState();
    widget.liveroom.logger?.call('LiveroomView initState');
    final joinSubs = widget.liveroom.onJoin((seatId) {
      widget.onJoin?.call(seatId);
    });
    final receiveSubs = widget.liveroom.receive((seatId, message) {
      widget.onReceive?.call(seatId, message);
    });
    final exitSubs = widget.liveroom.onExit((seatId) {
      widget.onExit?.call(seatId);
    });
    setState(() {
      subsList.add(receiveSubs);
      subsList.add(joinSubs);
      subsList.add(exitSubs);
    });
  }

  @override
  void dispose() {
    widget.liveroom.logger?.call('LiveroomView dispose');
    for (final subs in subsList) {
      subs.cancel();
    }
    subsList.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}