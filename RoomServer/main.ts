// deno run --allow-net main.ts

import { RoomServer } from "https://raw.githubusercontent.com/rbdog/room-server/main/mod.ts";
const server = new RoomServer();
server.listen();
