const pool = require('./db');
const { userFromToken, RANK } = require('./auth');

const SEATS = 8;
const rooms = new Map(); // roomId -> { seats: [] }

const stateOf = (roomId) => {
  if (!rooms.has(roomId)) rooms.set(roomId, { seats: Array(SEATS).fill(null) });
  return rooms.get(roomId);
};

module.exports = function attachSocket(io) {
  const channel = (roomId) => `room:${roomId}`;

  const broadcast = (roomId) => {
    io.to(channel(roomId)).emit('room:state', {
      seats: stateOf(roomId).seats,
      online: io.sockets.adapter.rooms.get(channel(roomId))?.size || 0,
    });
  };

  const freeSeats = (roomId, userId) => {
    const s = stateOf(roomId);
    s.seats = s.seats.map((x) => (x && x.userId === userId ? null : x));
  };

  io.use(async (socket, next) => {
    const user = await userFromToken(socket.handshake.auth && socket.handshake.auth.token);
    if (!user) return next(new Error('unauthorized'));
    socket.user = user;
    next();
  });

  io.on('connection', (socket) => {
    const me = socket.user;
    const brief = { userId: me.id, name: me.display_name, avatar: me.avatar_url, frameId: me.frame_id };

    socket.on('room:join', (roomId) => {
      if (socket.data.roomId) return;
      socket.data.roomId = String(roomId);
      socket.join(channel(socket.data.roomId));
      io.to(channel(socket.data.roomId)).emit('chat:system', { text: `${me.display_name} masuk` });
      broadcast(socket.data.roomId);
    });

    const leave = () => {
      const roomId = socket.data.roomId;
      if (!roomId) return;
      freeSeats(roomId, me.id);
      socket.leave(channel(roomId));
      socket.data.roomId = null;
      broadcast(roomId);
    };
    socket.on('room:leave', leave);
    socket.on('disconnect', leave);

    socket.on('mic:take', ({ seat }) => {
      const roomId = socket.data.roomId;
      if (!roomId || !Number.isInteger(seat) || seat < 0 || seat >= SEATS) return;
      const s = stateOf(roomId);
      if (s.seats[seat]) return socket.emit('error:msg', 'Kursi sudah terisi');
      freeSeats(roomId, me.id);
      s.seats[seat] = { ...brief, muted: false };
      broadcast(roomId);
    });

    socket.on('mic:leave', () => {
      if (!socket.data.roomId) return;
      freeSeats(socket.data.roomId, me.id);
      broadcast(socket.data.roomId);
    });

    // Pemilik kursi boleh membisukan dirinya; admin ke atas boleh membisukan siapa saja.
    socket.on('mic:mute', ({ seat, muted }) => {
      const roomId = socket.data.roomId;
      if (!roomId) return;
      const s = stateOf(roomId);
      const target = s.seats[seat];
      if (!target) return;
      if (target.userId !== me.id && RANK[me.role] < RANK.admin) return;
      target.muted = !!muted;
      broadcast(roomId);
    });

    socket.on('chat:send', ({ text }) => {
      const roomId = socket.data.roomId;
      const msg = (text || '').toString().trim().slice(0, 300);
      if (!roomId || !msg) return;
      io.to(channel(roomId)).emit('chat:message', { ...brief, text: msg, ts: Date.now() });
    });

    socket.on('gift:send', async ({ giftId, toUserId, qty }) => {
      const roomId = socket.data.roomId;
      const count = Math.min(Math.max(parseInt(qty, 10) || 1, 1), 99);
      if (!roomId) return;

      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const { rows: [gift] } = await client.query('SELECT * FROM gifts WHERE id = $1 AND active = TRUE', [giftId]);
        const { rows: [sender] } = await client.query('SELECT coins FROM users WHERE id = $1 FOR UPDATE', [me.id]);
        if (!gift) throw new Error('Gift tidak tersedia');
        const total = Number(gift.price) * count;
        if (Number(sender.coins) < total) throw new Error('Koin tidak cukup');

        const { rows: [after] } = await client.query(
          'UPDATE users SET coins = coins - $1 WHERE id = $2 RETURNING coins',
          [total, me.id]
        );
        await client.query(
          'INSERT INTO coin_transactions (user_id, amount, reason) VALUES ($1, $2, $3)',
          [me.id, -total, `Kirim gift: ${gift.name} x${count}`]
        );
        await client.query('COMMIT');

        socket.emit('wallet:update', { coins: after.coins });
        io.to(channel(roomId)).emit('gift:sent', {
          from: brief,
          toUserId,
          gift: { id: gift.id, name: gift.name, icon_url: gift.icon_url, animation_url: gift.animation_url },
          qty: count,
        });
      } catch (e) {
        await client.query('ROLLBACK');
        socket.emit('error:msg', e.message);
      } finally {
        client.release();
      }
    });

    // Admin ke atas dapat mengeluarkan pengguna dari room.
    socket.on('room:kick', async ({ userId }) => {
      const roomId = socket.data.roomId;
      if (!roomId || RANK[me.role] < RANK.admin) return;
      for (const s of await io.in(channel(roomId)).fetchSockets()) {
        if (s.user.id === userId && RANK[s.user.role] < RANK[me.role]) {
          s.emit('room:kicked');
          s.disconnect(true);
        }
      }
    });
  });
};
