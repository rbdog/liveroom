# Live Room

- Simple WebSocket Room Server
- for **Flutter App** (and others)


## Deno (run server)

$ deno run --allow-net main.ts

```main.ts
// main.ts
import { Liveroom } from "https://deno.land/x/liveroom/mod.ts";
const liveroom = new Liveroom();
liveroom.run();
console.log("Liveroom is running ...");
```

## Flutter (client app)


$ flutter pub add liveroom

```
// main.dart
import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';
final liveroom = Liveroom();
void main() {
  final app = LiveroomTestApp(liveroom);
  runApp(app);
}
```

modr info  
https://pub.dev/packages/liveroom
