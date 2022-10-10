import 'package:flutter/material.dart';
import 'package:liveroom/src/liveroom.dart';
import 'package:liveroom/src/liveroom_view.dart';

//
// * LiveroomTestApp
//
class LiveroomQuickApp extends StatelessWidget {
  LiveroomQuickApp({
    Key? key,
  }) : super(key: key);

  final liveroom = Liveroom();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () async {
            await liveroom.exit();
            liveroom.onJoin(
              (seatId) {
                if (liveroom.mySeatId == seatId) {
                  pushToMessageRoom(context);
                }
              },
            );
            liveroom.create(roomId: 'ROOM-01');
          },
          child: const Text('Create \n Room'),
        ),
        ElevatedButton(
          onPressed: () async {
            await liveroom.exit();
            liveroom.onJoin(
              (seatId) {
                if (liveroom.mySeatId == seatId) {
                  pushToMessageRoom(context);
                }
              },
            );
            liveroom.join(roomId: 'ROOM-01');
          },
          child: const Text('Join \n Room'),
        ),
      ],
    );
    final body = Center(
      child: buttonsRow,
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
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    final topBar = Container(
      width: double.infinity,
      height: 100,
      color: Colors.grey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {
              widget.liveroom.exit();
              Navigator.of(context).pop();
            },
            child: const Text('Exit'),
          ),
          const SizedBox(width: 300, height: 50),
        ],
      ),
    );
    final bottomBar = Container(
      width: double.infinity,
      height: 100,
      color: Colors.grey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 300,
            height: 50,
            child: TextField(
              decoration: const InputDecoration(
                fillColor: Colors.white,
                filled: true,
              ),
              controller: textController,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.liveroom.send(message: textController.text);
            },
            child: const Text('Send'),
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

    final scaffold = Scaffold(
      body: body,
    );

    return LiveroomView(
      liveroom: widget.liveroom,
      onJoin: (seatId) {
        setState(() {
          messages.add('joined');
        });
      },
      onMessage: ((seatId, message) {
        setState(() {
          messages.add(message);
        });
      }),
      onExit: ((seatId) {
        setState(() {
          messages.add('exited');
        });
      }),
      child: scaffold,
    );
  }
}
