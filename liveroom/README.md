# Liveroom

functions

- liveroom.create(roomId: '0001');
- liveroom.join(roomId: '0001');
- liveroom.send(message: 'Hello');
- liveroom.receive((seatId, message) => print(message));
- liveroom.exit();