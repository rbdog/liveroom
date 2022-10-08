// deno run --allow-net main.ts
import { RoomServer } from "./RoomServer.ts";
const server = new RoomServer();
server.listen();
