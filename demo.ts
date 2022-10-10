// deno run --allow-net https://deno.land/x/liveroom/demo.ts
import { LiveroomServer } from "./deno/Liveroom.ts";
const server = new LiveroomServer();
server.run();
console.log('+----------+');
console.log('| Liveroom |');
console.log('+----------+');
