![Header](https://github.com/rbdog/liveroom/blob/main/static/img/liveroom-header.png?raw=true)

https://pub.dev/packages/liveroom

### LiveRoom, Super-Simple WebSocket Room kit

## 1. Server

1. setup **Deno** ([Official Manual](https://deno.land/manual/getting_started/installation))


```
### Mac
$ curl -fsSL https://deno.land/x/install/install.sh | sh
### Windows powershell
$ irm https://deno.land/install.ps1 | iex
```

2. create TypeScript file `main.ts`

```main.ts
import { Liveroom } from "https://deno.land/x/liveroom/mod.ts";
const liveroom = new Liveroom();
liveroom.run();
```

3. run

```
$ deno run --allow-net main.ts
```

<br />

## 2. Flutter App

```
import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';

final liveroom = Liveroom();

void main() {
  final app = LiveroomTestApp(liveroom);
  runApp(app);
}
```

<br />

more functions  
- liveroom.create(roomId: '0001');
- liveroom.join(roomId: '0001');
- liveroom.send(message: 'Hello');
- liveroom.receive((seatId, message) => print(message));
- liveroom.exit();


🎉 any issues, requests, contributions are welcomed!
