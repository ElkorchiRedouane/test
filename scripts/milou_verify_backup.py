#!/usr/bin/env python3
"""Verify a decrypted Milou tar.gz without extracting or logging private filenames."""
import hashlib
import json
import pathlib
import sys
import tarfile

def canonical(name):
    while name.startswith("./"):
        name = name[2:]
    if not name or name.startswith("/") or "\\" in name:
        raise ValueError("Invalid archive path")
    parts = name.split("/")
    if any(p in ("", ".", "..") for p in parts):
        raise ValueError("Invalid archive path")
    return pathlib.PurePosixPath(name).as_posix()

def verify(filename):
    with tarfile.open(filename, "r:gz") as archive:
        members = {}
        for member in archive:
            if member.isdir():
                continue
            if not member.isfile():
                raise ValueError("Unsupported archive entry")
            name = canonical(member.name)
            if name in members:
                raise ValueError("Duplicate archive entry")
            members[name] = member
        if "manifest.json" not in members:
            raise ValueError("Missing manifest")
        if members["manifest.json"].size > 16 * 1024 * 1024:
            raise ValueError("Manifest too large")
        manifest = json.load(archive.extractfile(members["manifest.json"]))
        entries = manifest["files"]
        if manifest.get("project") != "lgdapxduxmhcixjwzfrq":
            raise ValueError("Wrong project")
        if not isinstance(entries, dict) or manifest["file_count"] != len(entries):
            raise ValueError("Invalid manifest")
        if set(entries) != set(members) - {"manifest.json"}:
            raise ValueError("Manifest coverage mismatch")
        if not {"database.dump", "database-inventory.txt", "storage/storage-index.json"} <= set(entries):
            raise ValueError("Incomplete backup")
        for name, expected in entries.items():
            if canonical(name) != name or members[name].size != expected["bytes"]:
                raise ValueError("Entry size mismatch")
            digest = hashlib.sha256()
            with archive.extractfile(members[name]) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected["sha256"]:
                raise ValueError("Entry checksum mismatch")
    print("Archive: manifest coverage, sizes and SHA-256 verified.")

if __name__ == "__main__":
    try:
        verify(sys.argv[1])
    except Exception:
        print("Backup verification failed; private filenames and contents suppressed.", file=sys.stderr)
        sys.exit(1)
