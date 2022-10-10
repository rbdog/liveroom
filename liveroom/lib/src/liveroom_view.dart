//
// * LiveroomView
//
import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';

class LiveroomView extends StatefulWidget {
  const LiveroomView({
    required this.liveroom,
    required this.child,
    this.onJoin,
    this.onMessage,
    this.onExit,
    Key? key,
  }) : super(key: key);

  final Liveroom liveroom;
  final void Function(String seatId)? onJoin;
  final void Function(String seatId, String message)? onMessage;
  final void Function(String seatId)? onExit;
  final Widget child;

  @override
  _LiveroomViewState createState() {
    return _LiveroomViewState();
  }
}

class _LiveroomViewState extends State<LiveroomView> {
  final List<String> messages = [];

  Widget itemBuilder(BuildContext context, int index) {
    return Text(messages[index]);
  }

  @override
  void initState() {
    super.initState();
    widget.liveroom.onJoin((seatId) {
      widget.onJoin?.call(seatId);
    });
    widget.liveroom.receive((seatId, message) {
      widget.onMessage?.call(seatId, message);
    });
    widget.liveroom.onExit((seatId) {
      widget.onExit?.call(seatId);
    });
  }

  @override
  void dispose() {
    print('will dispose');
    widget.liveroom.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
