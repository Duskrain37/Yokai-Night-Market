"""Analyze and make a byte-preserving candidate from the known 4.7.2 Windows export."""
import argparse
import hashlib
import json
import mmap
import struct
from pathlib import Path


PORTRAITS = {"bride", "gust", "firework", "squash", "dragon", "returner", "matchmaker",
             "phase-veil", "tamer", "shieldguard", "reedboat", "dreambell",
             "ruin-cap", "sky-kite", "wish-till", "cash-pod", "ember-cicada",
             "flinch", "wave-herald", "formless", "reed-shot"}
DESTRUCTION = {"sedan-loaded", "sedan-empty"}
BOSS_PORTRAITS = {"boss-island", "boss-magistrate-bound", "boss-magistrate-full"}


class Pack:
    def __init__(self, data):
        self.data = data
        length, magic = struct.unpack_from("<Q4s", data, len(data) - 12)
        self.start = len(data) - 12 - length
        assert magic == b"GDPC" and self.start > 4096
        assert struct.unpack_from("<4s5I", data, self.start) == (b"GDPC", 4, 4, 7, 2, 2)
        self.base, table = struct.unpack_from("<QQ", data, self.start + 24)
        assert self.base == 112 and self.base < table < length
        cursor = self.start + table
        count, = struct.unpack_from("<I", data, cursor)
        cursor += 4
        self.entries = {}
        for _ in range(count):
            size, = struct.unpack_from("<I", data, cursor)
            cursor += 4
            raw_name = data[cursor:cursor + size]
            cursor += size
            name = raw_name.rstrip(bytes(1)).decode("utf-8")
            offset, length, md5, flags = struct.unpack_from("<QQ16sI", data, cursor)
            cursor += 36
            assert flags == 0 and offset + length <= table - self.base and name not in self.entries
            self.entries[name] = (raw_name, offset, length, md5)

    def file(self, name):
        _, offset, size, _ = self.entries[name]
        at = self.start + self.base + offset
        return self.data[at:at + size]

    def imported(self, path):
        import_path = path + ".import"
        text = self.file(import_path).decode()
        locations = [line.split('"')[1].removeprefix("res://") for line in text.splitlines()
                     if line.startswith('path="res://')]
        assert len(locations) == 1 and locations[0] in self.entries
        return {import_path, locations[0]}


def remove_candidates(pack):
    keys = json.loads(pack.file("data/actor_frames.json"))
    motion = json.loads(pack.file("data/actor_motion.json"))
    assert keys and keys.keys() == motion.keys()
    retained_sources = {keys[actor]["file"] for actor in PORTRAITS | DESTRUCTION | BOSS_PORTRAITS}
    removable_sources = set()
    for actor, info in keys.items():
        animated = motion[actor]
        assert animated["clips"].keys() == info["clips"].keys()
        assert all(len(frames) == 32 for frames in animated["clips"].values())
        pack.imported(animated["file"])
        if info["file"] not in retained_sources:
            assert info["file"].startswith("assets/sprites/animation/")
            removable_sources.add(info["file"])
    unused = {"assets/bg/board.jpg", "assets/boss/weakpoint.svg", "assets/boss/boss_bar_frame.svg",
              "assets/bg/loading-menu.png"}
    return {
        "fallback_key_atlases": set().union(*(pack.imported(x) for x in removable_sources)),
        "unused_and_art_prompts": {name for name in pack.entries if name.startswith("data/") and (name.endswith("_art_prompts.json") or name in {"data/v055_art_sources.json","data/v055_generation_prompts.json","data/v055_sfx.json","data/news_v054.json"})}
            | set().union(*(pack.imported(x) for x in unused if x + ".import" in pack.entries)),
    }


def update_section(image, start, size):
    pe, = struct.unpack_from("<I", image, 60)
    count, = struct.unpack_from("<H", image, pe + 6)
    optional_length, = struct.unpack_from("<H", image, pe + 20)
    sections = pe + 24 + optional_length
    for index in range(count):
        at = sections + index * 40
        name, virtual, _, _, raw = struct.unpack_from("<8sIIII", image, at)
        if name.rstrip(bytes(1)) == b"pck":
            assert virtual == 8 and raw == start and index == count - 1
            struct.pack_into("<I", image, at + 16, size)
            return at + 16
    raise ValueError("Missing PCK section")


def write_candidate(pack, removed, target):
    header = bytearray(pack.data[:pack.start + pack.base])
    indexed = {}
    stored = {}
    duplicates = 0
    with target.with_suffix(".tmp").open("w+b") as out:
        out.write(header)
        for path, (raw_name, _, size, md5) in pack.entries.items():
            if path in removed:
                continue
            content = pack.file(path)
            assert hashlib.md5(content).digest() == md5
            strong = hashlib.sha256(content).digest()
            if strong not in stored:
                stored[strong] = out.tell() - len(header)
                out.write(content)
                out.write(bytes((-out.tell()) % 16))
            else:
                duplicates += size
            indexed[path] = (raw_name, stored[strong], size, md5)
        table = out.tell() - pack.start
        out.write(struct.pack("<I", len(indexed)))
        for raw_name, offset, size, md5 in indexed.values():
            out.write(struct.pack("<I", len(raw_name)))
            out.write(raw_name)
            out.write(struct.pack("<QQ16sI", offset, size, md5, 0))
        length = out.tell() - pack.start
        out.write(struct.pack("<Q4s", length, b"GDPC"))
        section_field = update_section(header, pack.start, length + 12)
        out.seek(section_field)
        out.write(header[section_field:section_field + 4])
        out.seek(pack.start + 32)
        out.write(struct.pack("<Q", table))
    target.with_suffix(".tmp").replace(target)
    with target.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        candidate = Pack(data)
        assert candidate.entries.keys() == indexed.keys()
        assert data[:section_field] == pack.data[:section_field]
        assert data[section_field + 4:pack.start] == pack.data[section_field + 4:pack.start]
        for path in indexed:
            assert candidate.file(path) == pack.file(path), path
    return duplicates, len(indexed)


def main():
    parser = argparse.ArgumentParser(description="Trim unused Godot assets and reuse identical payloads")
    parser.add_argument("exe", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    candidate = args.exe.with_suffix(".slim.exe")
    with args.exe.open("rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as data:
        pack = Pack(data)
        groups = remove_candidates(pack)
        removed = set().union(*groups.values())
        duplicates, kept = write_candidate(pack, removed, candidate)
        report = {"original_bytes": len(data), "candidate_bytes": candidate.stat().st_size,
                  "untouched_files": kept, "removed_files": len(removed),
                  "removed_by_group": {k: sum(pack.entries[p][2] for p in v) for k, v in groups.items()},
                  "identical_payload_reuse": duplicates,
                  "removed_paths": {k: sorted(v) for k, v in groups.items()}}
    candidate.replace(args.exe)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Package trim: {report['original_bytes']:,} → {report['candidate_bytes']:,} bytes")


if __name__ == "__main__":
    main()
