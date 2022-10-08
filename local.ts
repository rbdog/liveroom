//
// $ deno run --allow-net https://raw.githubusercontent.com/rbdog/room-server/main/local.ts
//
import { RoomServer } from "./deno/RoomServer.ts";
const server = new RoomServer();
server.listen();
