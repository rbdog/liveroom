## Blueprint For Developers

WebSocket URL

| API         | URL                                                                 |
| ----------- | ------------------------------------------------------------------- |
| Create Room | ws://localhost:5000/liveroom/create?room_id=ROOM_ID&seat_id=SEAT_ID |
| Join Room   | ws://localhost:5000/liveroom/join?room_id=ROOM_ID&seat_id=SEAT_ID   |

Data Message Format

```
{
  "seat_id": "MY_SEAT_ID",
  "body_type": "message",
  "body": "Hello from MY_SEAT_ID",
}
```
