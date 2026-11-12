"""Builds zzz_APFoxy_P.pak, so the game itself plays the Foxy Trap sound.

The game has an unused event, Play_mus_foreverAndEver_old (bank MusicStreaming). The pak holds
a copy of the player's own MusicStreaming.bnk where only that track changes: it plays Foxy's
sound on the Jumpscare volume bus. No game file is shipped: the bank is read from the player's
install when the client starts. Delete the pak to undo.
"""
import ctypes
import hashlib
import os
import struct
import sys
import wave

WEM_ID = 1059007789
TRACK_ID = 32819896
PLUGIN_ADPCM, PLUGIN_PCM = 0x00020001, 0x00010001
JUMPSCARE_BUS = 3520998787
MOUNT = b"../../../fnaf9/Content/\0"
GAME_PAK = "fnaf9-WindowsNoEditor.pak"
BANK = "fnaf9/Content/WwiseAudio/Windows/MusicStreaming.bnk"
PAK_NAME = "zzz_APFoxy_P.pak"
GAME_KEY = "0x85F7D4007015493ED0359C9007266038F8F7B1F96988F19A610103874CC95286"
GAIN_DB = 7.0


def aes_ecb_decrypt(key, data):
    import ctypes.wintypes as wt
    bc = ctypes.WinDLL("bcrypt")

    def ok(r):
        if r != 0:
            raise OSError(f"bcrypt status {r & 0xffffffff:#x}")
    alg, hkey = wt.HANDLE(), wt.HANDLE()
    ok(bc.BCryptOpenAlgorithmProvider(ctypes.byref(alg), ctypes.c_wchar_p("AES"), None, 0))
    mode = ctypes.create_unicode_buffer("ChainingModeECB")
    ok(bc.BCryptSetProperty(alg, ctypes.c_wchar_p("ChainingMode"), mode, ctypes.sizeof(mode), 0))
    kb = ctypes.create_string_buffer(key, len(key))
    ok(bc.BCryptGenerateSymmetricKey(alg, ctypes.byref(hkey), None, 0, kb, len(key), 0))
    inp, out, n = ctypes.create_string_buffer(data, len(data)), ctypes.create_string_buffer(len(data)), wt.ULONG()
    ok(bc.BCryptDecrypt(hkey, inp, len(data), None, None, 0, out, len(data), ctypes.byref(n), 0))
    return out.raw[:n.value]


def parse_key(text):
    key = bytes.fromhex(text.strip().lower().replace("0x", ""))
    if len(key) != 32:
        raise ValueError("the AES key must be 32 bytes (64 hex digits)")
    return key


def fstr(b, o):
    n = struct.unpack_from("<i", b, o)[0]
    o += 4
    if n < 0:
        return b[o:o - 2 * n].decode("utf-16-le").rstrip("\0"), o - 2 * n
    return b[o:o + n].decode("utf-8", "replace").rstrip("\0"), o + n


def read_from_pak(pak, wanted, key):
    with open(pak, "rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(size - 512)
        tail = f.read(512)
        mi = tail.rfind(struct.pack("<I", 0x5A6F12E1))
        if struct.unpack_from("<i", tail, mi + 4)[0] != 11 or tail[mi - 1] != 0:
            raise ValueError("unexpected pak version (game update?)")
        io, isz = struct.unpack_from("<QQ", tail, mi + 8)
        f.seek(io)
        idx = f.read(isz)
        mount, o = fstr(idx, 0)
        o += 4 + 8
        o += 4 + 36 if struct.unpack_from("<I", idx, o)[0] else 4
        if not struct.unpack_from("<I", idx, o)[0]:
            raise ValueError("no full directory index in the pak")
        o += 4
        fdi_off, fdi_size = struct.unpack_from("<QQ", idx, o)
        o += 36
        enc_size = struct.unpack_from("<i", idx, o)[0]
        o += 4
        encoded = idx[o:o + enc_size]
        f.seek(fdi_off)
        fdi = f.read(fdi_size)
        p = 0
        ndirs = struct.unpack_from("<i", fdi, p)[0]
        p += 4
        for _ in range(ndirs):
            d, p = fstr(fdi, p)
            nf = struct.unpack_from("<i", fdi, p)[0]
            p += 4
            for _ in range(nf):
                name, p = fstr(fdi, p)
                loc = struct.unpack_from("<i", fdi, p)[0]
                p += 4
                if (mount + d + name).replace("../../../", "") != wanted:
                    continue
                bits = struct.unpack_from("<I", encoded, loc)[0]
                q = loc + 4
                if (bits & 0x3f) == 0x3f:
                    q += 4
                if (bits >> 23) & 0x3f:
                    raise ValueError("compressed entry")
                if (bits >> 31) & 1:
                    off = struct.unpack_from("<I", encoded, q)[0]
                    q += 4
                else:
                    off = struct.unpack_from("<Q", encoded, q)[0]
                    q += 8
                usz = struct.unpack_from("<I" if (bits >> 30) & 1 else "<Q", encoded, q)[0]
                f.seek(off)
                hdr = f.read(53)
                encrypted = hdr[48] & 1
                data = f.read((usz + 15) // 16 * 16 if encrypted else usz)
                if encrypted:
                    data = aes_ecb_decrypt(key, data)
                return data[:usz]
    raise ValueError(f"{wanted} not found in {pak}")


def pcm_wem(wav_path):
    with wave.open(wav_path) as w:
        ch, rate, width, frames = w.getnchannels(), w.getframerate(), w.getsampwidth(), w.getnframes()
        if width != 2 or ch not in (1, 2):
            raise ValueError("16-bit mono or stereo WAV expected")
        data = w.readframes(frames)
    cfg = ch | (1 << 8) | ((4 if ch == 1 else 3) << 12)
    fmt = struct.pack("<HHIIHHHHI", 0xFFFE, ch, rate, rate * ch * 2, ch * 2, 16, 6, 0, cfg)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(data)) + data
    return b"RIFF" + struct.pack("<I", len(body)) + body, frames * 1000.0 / rate


def chunks(b):
    o, out = 0, []
    while o < len(b):
        cid, sz = b[o:o + 4], struct.unpack_from("<I", b, o + 4)[0]
        out.append([cid, bytearray(b[o + 8:o + 8 + sz])])
        o += 8 + sz
    return out


def patch_bank(bnk, wem, length_ms, gain_db=0.0):
    ch = chunks(bnk)
    get = {c[0]: c for c in ch}
    didx, data, hirc = get[b"DIDX"][1], get[b"DATA"][1], get[b"HIRC"][1]
    n = struct.unpack_from("<I", hirc, 0)[0]
    p = 4
    for _ in range(n):
        t, size = hirc[p], struct.unpack_from("<I", hirc, p + 1)[0]
        body = p + 5
        if t == 11 and struct.unpack_from("<I", hirc, body)[0] == TRACK_ID:
            break
        p = body + size
    else:
        raise ValueError("track not found in the bank")
    q = body + 5
    if struct.unpack_from("<I", hirc, q)[0] != 1:
        raise ValueError("one source expected")
    q += 4
    plugin, stype, src = struct.unpack_from("<IBI", hirc, q)
    if (src, stype, plugin) != (WEM_ID, 2, PLUGIN_ADPCM):
        raise ValueError("the bank is not the expected one (already patched, or a game update)")
    struct.pack_into("<IBII", hirc, q, PLUGIN_PCM, 0, WEM_ID, len(wem))
    q += 14
    if struct.unpack_from("<I", hirc, q)[0] != 1 or struct.unpack_from("<I", hirc, q + 8)[0] != WEM_ID:
        raise ValueError("unexpected track layout")
    q += 4
    struct.pack_into("<d", hirc, q + 12 + 24, length_ms)
    q += 44
    if struct.unpack_from("<II", hirc, q) != (1, 0) or bytes(hirc[q + 8:q + 17]) != bytes(9):
        raise ValueError("unexpected track layout")
    q += 8
    struct.pack_into("<I", hirc, q + 5, JUMPSCARE_BUS)
    if gain_db:
        k = q + 13 + 1
        if hirc[k] != 0:
            raise ValueError("the track already has properties")
        hirc[k:k + 1] = struct.pack("<BBf", 1, 0, gain_db)
        struct.pack_into("<I", hirc, p + 1, struct.unpack_from("<I", hirc, p + 1)[0] + 5)
    ids = [struct.unpack_from("<I", didx, k)[0] for k in range(0, len(didx), 12)]
    if WEM_ID in ids or WEM_ID <= max(ids):
        raise ValueError("unexpected media list in the bank")
    off = (len(data) + 15) // 16 * 16
    data += bytes(off - len(data)) + wem
    didx += struct.pack("<III", WEM_ID, off, len(wem))
    return b"".join(c[0] + struct.pack("<I", len(c[1])) + bytes(c[1]) for c in ch)


def entry(offset, data):
    return struct.pack("<QQQI", offset, len(data), len(data), 0) + hashlib.sha1(data).digest() + b"\0" + struct.pack("<I", 0)


def write_pak(out, files):
    blob, index = bytearray(), bytearray()
    for name, data in files:
        off = len(blob)
        blob += entry(0, data) + data
        n = name.encode() + b"\0"
        index += struct.pack("<i", len(n)) + n + entry(off, data)
    index = struct.pack("<i", len(MOUNT)) + MOUNT + struct.pack("<i", len(files)) + index
    footer = struct.pack("<IiQQ", 0x5A6F12E1, 3, len(blob), len(index)) + hashlib.sha1(index).digest()
    with open(out, "wb") as f:
        f.write(bytes(blob) + bytes(index) + footer)


def build(paks_dir, wav, out, key=GAME_KEY, gain_db=GAIN_DB):
    """Returns a one-line summary. Raises on any problem."""
    key = parse_key(key) if isinstance(key, str) else key
    bnk = read_from_pak(os.path.join(paks_dir, GAME_PAK), BANK, key)
    if not bnk.startswith(b"BKHD"):
        raise ValueError("the bank could not be read: wrong AES key?")
    wem, ms = pcm_wem(wav)
    new_bnk = patch_bank(bnk, wem, ms, gain_db)
    tmp = out + ".tmp"
    write_pak(tmp, [("WwiseAudio/Windows/MusicStreaming.bnk", new_bnk)])
    os.replace(tmp, out)
    return f"{out}: Foxy sound {ms / 1000:.2f} s, +{gain_db:.0f} dB"


def install(mod_dir):
    """Builds the pak next to the game's paks if it is missing or older than the game's pak.
    Returns True when a new pak was written."""
    paks = os.path.normpath(os.path.join(mod_dir, "..", "..", "..", "..", "Content", "Paks"))
    game_pak = os.path.join(paks, GAME_PAK)
    out = os.path.join(paks, PAK_NAME)
    if not os.path.isfile(game_pak):
        raise FileNotFoundError(f"{game_pak} not found, is the mod in fnaf9/Binaries/Win64/Mods?")
    if os.path.isfile(out) and os.path.getmtime(out) >= os.path.getmtime(game_pak):
        return False
    build(paks, os.path.join(mod_dir, "Media", "foxy.wav"), out)
    return True


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("usage: python foxy_pak.py <game Paks folder> <foxy.wav> <out.pak>")
        sys.exit(1)
    print(build(sys.argv[1], sys.argv[2], sys.argv[3]))
