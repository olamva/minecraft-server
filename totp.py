import base64, hmac, struct, sys, time
seed = sys.stdin.read().strip().upper()
key = base64.b32decode(seed + "=" * (-len(seed) % 8))
counter = int(time.time()) // 30
digest = hmac.new(key, struct.pack(">Q", counter), "sha1").digest()
offset = digest[-1] & 0x0F
print(f"{(struct.unpack('>I', digest[offset:offset + 4])[0] & 0x7FFFFFFF) % 1000000:06d}", 30 - int(time.time()) % 30)
