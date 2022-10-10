// deno run --allow-net main.ts

import { LiveroomServer } from "./Liveroom.ts";
const server = new LiveroomServer();
server.run();
