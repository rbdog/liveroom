//
// RoomServer.ts
//

import { ApiRouter, ApiRouterServer } from "./ApiRouter.ts";

// イベント Body Type
const BodyType = {
  join: 0,
  message: 1,
  exit: 2,
};

// ライブイベント
type LiveEvent = {
  seat_id: string;
  body_type: number;
  body: string;
};

// クライアント
type Seat = {
  id: string;
  socket: WebSocket;
};

// ルーム
type Room = {
  id: string;
  seats: Seat[];
};

/// キーカード作成に必要な情報
type KeycardConfig = {
  roomId: string;
  seatId: string;
};

function getKeycardConfig(searchParams: URLSearchParams): KeycardConfig | null {
  // パラメータチェック
  const roomId = searchParams.get("room_id");
  const seatId = searchParams.get("seat_id");
  if (!roomId || !seatId) {
    return null;
  } else {
    return {
      roomId: roomId,
      seatId: seatId,
    };
  }
}

const CreateResult = {
  alreadyExist: 0,
  created: 1,
};

const JoinResult = {
  roomNotFound: 0,
  seatAlreadyFilled: 1,
  joined: 2,
};

const SendResult = {
  roomNotFound: 0,
  sent: 1,
  notReadyConnecting: 2,
  alreadyClosed: 3,
};

const ExitResult = {
  exitAndKeepRoom: 0,
  roomNotFound: 1,
  exitAndDeleteRoom: 2,
};

type Logger = (log: string) => void;

// ルームサーバー
export class Liveroom {
  // ルーム一覧
  rooms: Map<string, Room> = new Map();
  logger: Logger | null;

  constructor(logger: Logger | null = null) {
    this.logger = logger;
  }

  // 新しいルームを作成
  create(room_id: string, seat: Seat): number {
    const room: Room = {
      id: room_id,
      seats: [seat],
    };
    if (this.rooms.get(room_id)) {
      return CreateResult.alreadyExist;
    }
    this.rooms.set(room_id, room);
    return CreateResult.created;
  }

  // ルームに参加
  join(room_id: string, seat: Seat): number {
    // 対象のルームを見つける
    const room = this.rooms.get(room_id);
    if (!room) {
      return JoinResult.roomNotFound;
    }
    const oldSeats = room.seats.findIndex((e) => e.id === seat.id);
    if (oldSeats >= 0) {
      return JoinResult.seatAlreadyFilled;
    }
    room.seats.push(seat);
    return JoinResult.joined;
  }

  // ルームから退出
  exit(roomId: string, seat_id: string): number {
    // 対象のルームを見つける
    const room = this.rooms.get(roomId);
    if (!room) {
      return ExitResult.roomNotFound;
    }
    // クライアントを削除
    room.seats = room.seats.filter((e) => e.id !== seat_id);
    // クライアントが0人になったらルームを削除
    if (room.seats.length === 0) {
      this.rooms.delete(roomId);
      return ExitResult.exitAndDeleteRoom;
    } else {
      return ExitResult.exitAndKeepRoom;
    }
  }

  // ライブイベントを送る
  sendLiveEvent(liveEvent: LiveEvent, room_id: string): number {
    // 対象のルームを見つける
    const room = this.rooms.get(room_id);
    if (!room) {
      return SendResult.roomNotFound;
    }
    // 全員に送信
    for (const seat of room.seats) {
      if (seat.socket.readyState == WebSocket.CONNECTING) {
        // まだ接続中
        return SendResult.notReadyConnecting;
      } else if (seat.socket.readyState == WebSocket.OPEN) {
        // 接続できている
        const json = JSON.stringify(liveEvent);
        seat.socket.send(json);
      } else {
        // 既に切断されていた
        this.exit(room_id, liveEvent.seat_id);
        return SendResult.alreadyClosed;
      }
    }
    return SendResult.sent;
  }

  // クライアント1人ずつに対する処理
  clientHandler(room_id: string, seat: Seat) {
    this.logger?.(`New join => Room: ${room_id}, Seat: ${seat.id}`);
    // クライアントが接続したとき
    seat.socket.onopen = () => {
      // 送信するメッセージ
      const liveEvent: LiveEvent = {
        body_type: BodyType.join,
        seat_id: seat.id,
        body: "参加しました",
      };
      this.sendLiveEvent(liveEvent, room_id);
    };
    // クライアントからメッセージを受け取ったとき
    seat.socket.onmessage = (event) => {
      // 送信するメッセージ
      const liveEvent: LiveEvent = {
        body_type: BodyType.message,
        seat_id: seat.id,
        body: event.data,
      };
      this.sendLiveEvent(liveEvent, room_id);
    };
    // クライアントが切断したとき
    seat.socket.onclose = () => {
      // 自動的に退出
      const result = this.exit(room_id, seat.id);
      if (result == ExitResult.exitAndKeepRoom) {
        // 送信するメッセージ
        const liveEvent: LiveEvent = {
          seat_id: seat.id,
          body_type: BodyType.exit,
          body: "退出しました",
        };
        this.sendLiveEvent(liveEvent, room_id);
      }
    };
  }

  callCreateApi(req: Deno.RequestEvent): Response {
    const url = new URL(req.request.url);
    const keycardConfig = getKeycardConfig(url.searchParams);
    if (keycardConfig === null) {
      return new Response("Error: パラメータが不足しています");
    }
    // WebSocket で接続
    const { socket, response } = Deno.upgradeWebSocket(req.request);
    // ルーム作成
    const seat: Seat = {
      id: keycardConfig.seatId,
      socket: socket,
    };
    const result = this.create(keycardConfig.roomId, seat);
    if (result === CreateResult.alreadyExist) {
      // 失敗
      return new Response("Error: 既に同じルームIDが存在します");
    } else if (result === CreateResult.created) {
      this.clientHandler(keycardConfig.roomId, seat);
      return response;
    } else {
      return new Response("Error: 予期せぬエラーです");
    }
  }

  callJoinApi(req: Deno.RequestEvent): Response {
    const url = new URL(req.request.url);
    const keycardConfig = getKeycardConfig(url.searchParams);
    if (keycardConfig === null) {
      return new Response("Error: パラメータが不足しています");
    }
    // WebSocket で接続
    const { socket, response } = Deno.upgradeWebSocket(req.request);
    // ルーム参加
    const seat: Seat = {
      id: keycardConfig.seatId,
      socket: socket,
    };
    const result = this.join(keycardConfig.roomId, seat);
    if (result === JoinResult.roomNotFound) {
      // 失敗
      return new Response("Error: ルームIDが見つかりません");
    } else if (result === JoinResult.seatAlreadyFilled) {
      // 失敗
      return new Response("Error: 既にシートが埋まっています");
    } else if (result === JoinResult.joined) {
      this.clientHandler(keycardConfig.roomId, seat);
      return response;
    } else {
      return new Response("Error: 予期せぬエラーです");
    }
  }
}

type LiveroomServerConfig = { port?: number; rootPath?: string };
const defaultConfig: LiveroomServerConfig = {
  port: 5000,
  rootPath: "/liveroom",
};

export class LiveroomServer {
  // API ルーター
  router = new ApiRouter();
  // LiveRoom
  liveroom = new Liveroom((log) => {
    console.log(log);
  });
  // Config
  config?: LiveroomServerConfig;

  constructor(config?: LiveroomServerConfig) {
    this.config = config;
  }

  // 起動
  run() {
    const rootPath = this.config?.rootPath ?? defaultConfig.rootPath!;
    this.router
      .get(rootPath + "/create", (req) => {
        return this.liveroom.callCreateApi(req);
      })
      .get(rootPath + "/join", (req) => {
        return this.liveroom.callJoinApi(req);
      });

    const port = this.config?.port ?? defaultConfig.port!;
    const server = new ApiRouterServer(this.router, { port: port });
    server.run();
    this.liveroom.logger?.(`running on port ${port}`);
  }
}
