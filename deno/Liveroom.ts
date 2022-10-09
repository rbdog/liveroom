//
// RoomServer.ts
//

import { ApiRouter } from "./ApiRouter.ts";

//
// ルーム作成
// ws://0.0.0.0:3000/rooms?command=create&room_id=x&client_id=x
// ルーム参加
// ws://0.0.0.0:3000/rooms?command=join&room_id=x&client_id=x
//

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

type LiveroomConfig = { port?: number; rootPath?: string };
const defaultConfig: LiveroomConfig = {
  port: 3000,
  rootPath: "/liveroom",
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
};

const ExitResult = {
  exitAndKeepRoom: 0,
  roomNotFound: 1,
  exitAndDeleteRoom: 2,
};

// ルームサーバー
export class Liveroom {
  // ルーム一覧
  rooms: Map<string, Room> = new Map();
  // API ルーター
  router = new ApiRouter();
  // Config
  config?: LiveroomConfig;

  constructor(config?: LiveroomConfig) {
    this.config = config;
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
  exit(room_id: string, seat_id: string): number {
    // 対象のルームを見つける
    const room = this.rooms.get(room_id);
    if (!room) {
      return ExitResult.roomNotFound;
    }
    // クライアントを削除
    room.seats = room.seats.filter((e) => e.id !== seat_id);
    // クライアントが0人になったらルームを削除
    if (room.seats.length === 0) {
      this.rooms.delete(room_id);
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
      const json = JSON.stringify(liveEvent);
      seat.socket.send(json);
    }
    return SendResult.sent;
  }

  // クライアント1人ずつに対する処理
  clientHandler(room_id: string, seat: Seat) {
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

  // 起動
  run() {
    const rootPath = this.config?.rootPath ?? defaultConfig.rootPath!;
    this.router
      .get(rootPath + "/create", (req, url) => {
        const keycardConfig = getKeycardConfig(url.searchParams);
        if (keycardConfig === null) {
          req.respondWith(new Response("Error: パラメータが不足しています"));
          return;
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
          req.respondWith(new Response("Error: 既に同じルームIDが存在します"));
          return;
        } else if (result === CreateResult.created) {
          this.clientHandler(keycardConfig.roomId, seat);
          req.respondWith(response);
          return;
        } else {
          req.respondWith(new Response("Error: 予期せぬエラーです"));
          return;
        }
      })
      .get(rootPath + "/join", (req, url) => {
        const keycardConfig = getKeycardConfig(url.searchParams);
        if (keycardConfig === null) {
          req.respondWith(new Response("Error: パラメータが不足しています"));
          return;
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
          req.respondWith(new Response("Error: ルームIDが見つかりません"));
          return;
        } else if (result === JoinResult.seatAlreadyFilled) {
          // 失敗
          req.respondWith(new Response("Error: 既にシートが埋まっています"));
          return;
        } else if (result === JoinResult.joined) {
          this.clientHandler(keycardConfig.roomId, seat);
          req.respondWith(response);
          return;
        } else {
          req.respondWith(new Response("Error: 予期せぬエラーです"));
          return;
        }
      });

    this.router.listen(this.config?.port ?? defaultConfig.port!);
  }
}
