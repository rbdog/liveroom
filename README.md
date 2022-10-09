# liveroom

Simple WebSocket Room Server

- for **Flutter**
- (and others)

## Deno (run server)

```shell
$ deno run --allow-net main.ts
```

main.ts

```main.ts
import { Liveroom } from "https://deno.land/x/liveroom/mod.ts";
const liveroom = new Liveroom();
liveroom.run();
console.log("Liveroom is running ...");
```

## Flutter (client)

```
$ flutter pub add liveroom
```

main.dart

```
import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';
final liveroom = Liveroom();
void main() {
  final app = LiveroomTestApp(liveroom);
  runApp(app);
}
```

functions

```example.dart
liveroom.create(roomId: '0001');
liveroom.join(roomId: '0001');
liveroom.send(message: 'Hello');
liveroom.receive((message) {
  print(message);
});
liveroom.exit();
```

## More Infomation

WebSocket URL

| API         | URL                                                                 |
| ----------- | ------------------------------------------------------------------- |
| Create Room | ws://localhost:5000/liveroom/create?room_id=ROOM_ID&seat_id=SEAT_ID |
| Join Room   | ws://localhost:5000/liveroom/join?room_id=ROOM_ID&seat_id=SEAT_ID   |

Message Format

```
{
  "seat_id": "MY_SEAT_ID",
  "body_type": "message",
  "body": "Hello from MY_SEAT_ID",
}
```
