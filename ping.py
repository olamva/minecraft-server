import json, socket, struct, sys
def varint(n):
    out = b""
    while True:
        b = n & 0x7F; n >>= 7
        out += bytes([b | (0x80 if n else 0)])
        if not n: return out
def read_varint(s):
    n = shift = 0
    while True:
        b = s.recv(1)[0]; n |= (b & 0x7F) << shift; shift += 7
        if not b & 0x80: return n
host, port = sys.argv[1], int(sys.argv[2])
s = socket.create_connection((host, port), timeout=10)
h = b"\x00" + varint(-1 & 0xFFFFFFFF) + varint(len(host)) + host.encode() + struct.pack(">H", port) + b"\x01"
s.sendall(varint(len(h)) + h + b"\x01\x00")
read_varint(s); read_varint(s); slen = read_varint(s)
data = b""
while len(data) < slen: data += s.recv(slen - len(data))
d = json.loads(data)
d.pop("favicon", None); print(json.dumps(d))
