import 'package:flutter/material.dart';
import 'package:room_server_test/room_server.dart';

//
// * RoomServerTestView
//
class RoomServerTestApp extends StatelessWidget {
  const RoomServerTestApp(
    this.server, {
    Key? key,
  }) : super(key: key);

  final RoomServer server;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CreateJoinView(server: server),
    );
  }
}

//
// * CreateJoinView
//
class CreateJoinView extends StatelessWidget {
  const CreateJoinView({
    required this.server,
    Key? key,
  }) : super(key: key);

  final RoomServer server;

  @override
  Widget build(BuildContext context) {
    final buttonsRow = Row(
      children: [
        ElevatedButton(
          onPressed: () {
            server.create(roomId: 'ROOM-01');
            pushToMessageRoom(context);
          },
          child: Text('Create'),
        ),
        ElevatedButton(
          onPressed: () {
            server.join(roomId: 'ROOM-01');
            pushToMessageRoom(context);
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
      builder: (context) => MessageRoomView(server: server),
    );
    Navigator.of(context).push(route);
  }
}

//
// * MessageRoomView
//
class MessageRoomView extends StatefulWidget {
  const MessageRoomView({
    required this.server,
    Key? key,
  }) : super(key: key);

  final RoomServer server;

  @override
  MessageRoomState createState() {
    return MessageRoomState();
  }
}

class MessageRoomState extends State<MessageRoomView> {
  final List<String> messages = [];

  Widget itemBuilder(BuildContext context, int index) {
    return Text(messages[index]);
  }

  @override
  void initState() {
    super.initState();
    widget.server.onSend((text) {
      setState(() {
        messages.add(text);
      });
    });
  }

  @override
  void dispose() {
    widget.server.exit();
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
              widget.server.exit();
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
              widget.server.send(message: textController.text);
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
