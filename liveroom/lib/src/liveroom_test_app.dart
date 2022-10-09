import 'package:flutter/material.dart';
import 'package:liveroom/src/liveroom.dart';

//
// * LiveroomTestApp
//
class LiveroomTestApp extends StatelessWidget {
  const LiveroomTestApp(
    this.liveroom, {
    Key? key,
  }) : super(key: key);

  final Liveroom liveroom;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _CreateJoinView(liveroom: liveroom),
    );
  }
}

//
// * CreateJoinView
//
class _CreateJoinView extends StatelessWidget {
  const _CreateJoinView({
    required this.liveroom,
    Key? key,
  }) : super(key: key);

  final Liveroom liveroom;

  @override
  Widget build(BuildContext context) {
    final buttonsRow = Row(
      children: [
        ElevatedButton(
          onPressed: () {
            liveroom.onJoin(
              (seatId) {
                if (liveroom.mySeatId == seatId) {
                  pushToMessageRoom(context);
                }
              },
            );
            liveroom.create(roomId: 'ROOM-01');
          },
          child: Text('Create'),
        ),
        ElevatedButton(
          onPressed: () {
            liveroom.onJoin(
              (seatId) {
                if (liveroom.mySeatId == seatId) {
                  pushToMessageRoom(context);
                }
              },
            );
            liveroom.join(roomId: 'ROOM-01');
          },
          child: Text('Join'),
        ),
      ],
    );
    final body = Column(
      children: [
        buttonsRow,
      ],
    );
    return Scaffold(
      body: body,
    );
  }

  void pushToMessageRoom(
    BuildContext context,
  ) {
    final route = MaterialPageRoute(
      builder: (context) => _MessageRoomView(
        liveroom: liveroom,
      ),
    );
    Navigator.of(context).push(route);
  }
}

//
// * MessageRoomView
//
class _MessageRoomView extends StatefulWidget {
  const _MessageRoomView({
    required this.liveroom,
    Key? key,
  }) : super(key: key);

  final Liveroom liveroom;

  @override
  _MessageRoomState createState() {
    return _MessageRoomState();
  }
}

class _MessageRoomState extends State<_MessageRoomView> {
  final List<String> messages = [];

  Widget itemBuilder(BuildContext context, int index) {
    return Text(messages[index]);
  }

  @override
  void initState() {
    super.initState();
    widget.liveroom.receive((seatId, message) {
      setState(() {
        messages.add(seatId + ': ' + message);
      });
    });
  }

  @override
  void dispose() {
    widget.liveroom.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    final topBar = Container(
      width: double.infinity,
      height: 100,
      color: Colors.blue,
      child: Row(
        children: [
          ElevatedButton(
            onPressed: () {
              widget.liveroom.exit();
              Navigator.of(context).pop();
            },
            child: Text('Exit'),
          ),
          SizedBox(width: 300, height: 50),
        ],
      ),
    );
    final bottomBar = Container(
      width: double.infinity,
      height: 100,
      color: Colors.blue,
      child: Row(
        children: [
          SizedBox(
            width: 300,
            height: 50,
            child: TextField(
              controller: textController,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('画面から　送ります');
              widget.liveroom.send(message: textController.text);
            },
            child: Text('Send'),
          ),
        ],
      ),
    );

    final messageListView = Expanded(
      child: ListView.builder(
        itemBuilder: itemBuilder,
        itemCount: messages.length,
      ),
    );
    final body = Column(
      children: [
        topBar,
        messageListView,
        bottomBar,
      ],
    );

    return Scaffold(
      body: body,
    );
  }
}
