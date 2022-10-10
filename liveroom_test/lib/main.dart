import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';

void main() {
  const app = MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CreateJoinView(),
  );
  runApp(app);
}

final liveroom = Liveroom(logger: print);

class CreateJoinView extends StatelessWidget {
  const CreateJoinView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonsRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () {
            liveroom.create(roomId: 'ROOM-01');
          },
          child: const Text('Create \n Room'),
        ),
        ElevatedButton(
          onPressed: () {
            liveroom.join(roomId: 'ROOM-01');
          },
          child: const Text('Join \n Room'),
        ),
      ],
    );
    final scaffold = Scaffold(
      body: Center(
        child: buttonsRow,
      ),
    );

    return LiveroomView(
      liveroom: liveroom,
      onJoin: (seatId) {
        if (liveroom.mySeatId == seatId) {
          pushToMessageRoom(context);
        }
      },
      child: scaffold,
    );
  }

  void pushToMessageRoom(BuildContext context) {
    final route = MaterialPageRoute(
      builder: (context) => const MessageRoomView(),
    );
    Navigator.of(context).push(route);
  }
}

class MessageRoomView extends StatefulWidget {
  const MessageRoomView({Key? key}) : super(key: key);

  @override
  MessageRoomState createState() => MessageRoomState();
}

class MessageRoomState extends State<MessageRoomView> {
  final List<String> messages = [];

  Widget itemBuilder(BuildContext context, int index) {
    return Text(messages[index]);
  }

  void printMessage(String message) {
    setState(() {
      messages.add(message);
    });
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
              liveroom.exit();
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
              liveroom.send(message: textController.text);
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

    final scaffold = Scaffold(
      body: Column(
        children: [
          topBar,
          messageListView,
          bottomBar,
        ],
      ),
    );

    return LiveroomView(
      liveroom: liveroom,
      onJoin: (seatId) {
        printMessage('joined');
      },
      onMessage: ((seatId, message) {
        printMessage(message);
      }),
      onExit: ((seatId) {
        printMessage('exited');
      }),
      child: scaffold,
    );
  }
}
