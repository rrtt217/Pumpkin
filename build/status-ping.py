#!/usr/bin/env python3
"""Minimal Minecraft Java Edition status ping (server list ping, next state 1)."""
import json
import socket
import struct
import sys


def varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def read_varint(sock) -> int:
    n = 0
    shift = 0
    while True:
        b = sock.recv(1)
        if not b:
            raise EOFError("connection closed")
        b = b[0]
        n |= (b & 0x7F) << shift
        if not b & 0x80:
            return n
        shift += 7


def read_exact(sock, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise EOFError("connection closed")
        buf += chunk
    return buf


def main() -> int:
    host, port, protocol = "127.0.0.1", 25565, 777
    if len(sys.argv) > 1:
        host = sys.argv[1]
    if len(sys.argv) > 2:
        port = int(sys.argv[2])
    if len(sys.argv) > 3:
        protocol = int(sys.argv[3])

    handshake = (
        varint(0x00)
        + varint(protocol)
        + varint(len(host)) + host.encode()
        + struct.pack(">H", port)
        + varint(1)
    )
    with socket.create_connection((host, port), timeout=15) as s:
        # status handshake, then status request
        s.sendall(varint(len(handshake)) + handshake)
        s.sendall(varint(1) + varint(0x00))
        length = read_varint(s)
        body = read_exact(s, length)
        # body: packet id (varint 0x00) + JSON string
        i = 0
        while True:
            b = body[i]
            i += 1
            if not b & 0x80:
                break
        strlen = 0
        shift = 0
        while True:
            b = body[i]
            i += 1
            strlen |= (b & 0x7F) << shift
            if not b & 0x80:
                break
            shift += 7
        data = json.loads(body[i:i + strlen].decode())

    version = data.get("version", {})
    players = data.get("players", {})
    print(f"version : {version.get('name')} protocol={version.get('protocol')}")
    print(f"players : {players.get('online')}/{players.get('max')}")
    print(f"motd    : {json.dumps(data.get('description'), ensure_ascii=False)[:160]}")
    favicon = data.get("favicon", "")
    print(f"favicon : {'present ' + str(len(favicon)) + ' chars' if favicon else 'MISSING'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
