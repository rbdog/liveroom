//
// RoomServer.ts
//

// 汎用 APIルーター

type ApiProcess = (req: Deno.RequestEvent, url: URL) => void;

type ApiRoute = {
  method: string;
  path: string;
  process: ApiProcess;
};

class ApiRouter {
  routes: ApiRoute[] = [];
  get(path: string, process: ApiProcess): ApiRouter {
    const route: ApiRoute = {
      method: "GET",
      path: path,
      process: process,
    };
    this.routes.push(route);
    return this;
  }

  post(path: string, process: ApiProcess): ApiRouter {
    const route: ApiRoute = {
      method: "POST",
      path: path,
      process: process,
    };
    this.routes.push(route);
    return this;
  }

  //
  // --- server ---
  //

  // Http リクエスト 1つずつに対する処理
  requestHandler(req: Deno.RequestEvent) {
    const url = new URL(req.request.url);
    console.log("リクエストを受け取りました");
    for (const route of this.routes) {
      console.log(req.request.method);
      console.log(url.pathname);
      if (req.request.method === route.method && url.pathname === route.path) {
        route.process(req, url);
      }
    }
  }

  // 全ての Http 接続に対する処理
  async connHandler(conn: Deno.Conn) {
    const httpConn = Deno.serveHttp(conn);
    for await (const requestEvent of httpConn) {
      this.requestHandler(requestEvent);
    }
  }

  // 起動
  async listen(port: number) {
    const server = Deno.listen({ port: port });
    for await (const conn of server) {
      this.connHandler(conn);
    }
  }
}

//
// ルーム作成
// ws://0.0.0.0:3000/rooms?command=create&room_id=x&client_id=x
// ルーム参加
// ws://0.0.0.0:3000/rooms?command=join&room_id=x&client_id=x
//

// ペイロード
type Payload = {
  body_type: string;
  client_id: string;
  body: string;
};

// クライアント
type Client = {
  id: string;
  socket: WebSocket;
};

// ルーム
type Room = {
  id: string;
  clients: Client[];
};

type RoomServerConfig = { port?: number; path?: string };
const defaultConfig: RoomServerConfig = {
  port: 3000,
  path: "/rooms",
};

const ExitRoomResult = {
  exitOne: 0,
  notFound: 1,
  exitAllDeleted: 2,
};

// ルームサーバー
export class RoomServer {
  // ルーム一覧
  rooms: Map<string, Room> = new Map();
  // API ルーター
  router = new ApiRouter();
  // Config
  config?: RoomServerConfig;

  constructor(config?: RoomServerConfig) {
    this.config = config;
  }

  // 新しいルームを作成
  createRoom(room_id: string, client: Client): boolean {
    const room: Room = {
      id: room_id,
      clients: [client],
    };
    if (this.rooms.get(room_id)) {
      console.log(`すでに同じIDのルームが存在します: ${room_id}`);
      return true;
    }
    this.rooms.set(room_id, room);
    return true;
  }

  // ルームに参加
  joinRoom(room_id: string, client: Client): boolean {
    // 対象のルームを見つける
    const room = this.rooms.get(room_id);
    if (!room) {
      console.log(`join ルームが見つかりませんでした: ${room_id}`);
      return false;
    }
    const oldClient = room.clients.findIndex((e) => e.id === client.id);
    if (oldClient >= 0) {
      console.log(`すでに参加中のクライアントです: ${room_id}`);
      return true;
    }
    room.clients.push(client);
    return true;
  }

  // ルームから退出
  exitRoom(room_id: string, client_id: string): number {
    // 対象のルームを見つける
    const room = this.rooms.get(room_id);
    if (!room) {
      console.log(`exit ルームが見つかりませんでした: ${room_id}`);
      return ExitRoomResult.notFound;
    }
    // クライアントを削除
    room.clients = room.clients.filter((e) => e.id !== client_id);
    // クライアントが0人になったらルームを削除
    if (room.clients.length === 0) {
      this.rooms.delete(room_id);
      return ExitRoomResult.exitAllDeleted;
    } else {
      return ExitRoomResult.exitOne;
    }
  }

  // メッセージを送る
  sendPayload(message: Payload, room_id: string) {
    // 対象のルームを見つける
    const room = this.rooms.get(room_id);
    if (!room) {
      console.log(`send ルームが見つかりませんでした: ${room_id}`);
      return;
    }
    // 全員に送信
    for (const client of room.clients) {
      const json = JSON.stringify(message);
      client.socket.send(json);
    }
  }

  // クライアント1人ずつに対する処理
  clientHandler(room_id: string, client: Client) {
    // クライアントが接続したとき
    client.socket.onopen = () => {
      // 送信するメッセージ
      const payload: Payload = {
        body_type: "join",
        client_id: client.id,
        body: "参加しました",
      };
      this.sendPayload(payload, room_id);
    };
    // クライアントからメッセージを受け取ったとき
    client.socket.onmessage = (event) => {
      console.log(event.data);
      // 送信するメッセージ
      const payload: Payload = {
        body_type: "message",
        client_id: client.id,
        body: event.data,
      };
      this.sendPayload(payload, room_id);
    };
    // クライアントが切断したとき
    client.socket.onclose = () => {
      // 自動的に退出
      const result = this.exitRoom(room_id, client.id);
      if (result == ExitRoomResult.exitOne) {
        // 送信するメッセージ
        const payload: Payload = {
          body_type: "exit",
          client_id: client.id,
          body: "退出しました",
        };
        this.sendPayload(payload, room_id);
      }
    };
  }

  // 起動
  listen() {
    const path = this.config?.path ?? defaultConfig.path!;
    this.router.get(path, (req, url) => {
      // パラメータチェック
      const command = url.searchParams.get("command");
      const room_id = url.searchParams.get("room_id");
      const client_id = url.searchParams.get("client_id");
      if (!command || !room_id || !client_id) {
        console.log("必要なパラメータが見つかりません");
        return;
      }
      // WebSocket で接続
      const { socket, response } = Deno.upgradeWebSocket(req.request);
      const client: Client = {
        id: client_id,
        socket: socket,
      };
      // ルーム作成または参加
      let result = false;
      if (command === "create") {
        result = this.createRoom(room_id, client);
      } else if (command === "join") {
        result = this.joinRoom(room_id, client);
      }
      if (!result) {
        // 失敗
        req.respondWith(new Response("ルーム作成または参加に失敗しました"));
        return;
      }
      this.clientHandler(room_id, client);
      req.respondWith(response);
    });

    this.router.listen(this.config?.port ?? defaultConfig.port!);
  }
}
