#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
: "${DATABASE_URL:?Missing database URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Missing Supabase service key}"
: "${SUPABASE_URL:?Missing Supabase URL}"
: "${BACKUP_PASSPHRASE:?Missing encryption passphrase}"

workspace="$RUNNER_TEMP/milou-backup"
mkdir -p "$workspace/plain"
stamp="$(TZ=America/Toronto date +%Y-%m-%dT%H-%M-%S)"
pg_dump --version >/dev/null
# Custom format preserves structure and data. All included schemas and permissions depend on the DB role.
PGCONNECT_TIMEOUT=30 pg_dump --format=custom --no-owner --no-acl   --file="$workspace/plain/database.dump" "$DATABASE_URL"
test -s "$workspace/plain/database.dump"
pg_restore --list "$workspace/plain/database.dump" > "$workspace/plain/database-inventory.txt"
test -s "$workspace/plain/database-inventory.txt"

python3 scripts/milou_export_storage.py "$workspace/plain/storage"
python3 - "$workspace/plain" <<'PY'
import datetime, hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1])
entries={}
for p in sorted(root.rglob("*")):
    if p.is_file():
        rel=p.relative_to(root).as_posix()
        digest=hashlib.sha256()
        with p.open("rb") as f:
            for chunk in iter(lambda:f.read(1024*1024),b""):
                digest.update(chunk)
        entries[rel]={"bytes":p.stat().st_size,"sha256":digest.hexdigest()}
manifest={
 "project":"lgdapxduxmhcixjwzfrq",
 "created_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
 "file_count":len(entries),
 "files":entries
}
(root/"manifest.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
PY

archive="$workspace/milou-$stamp.tar.gz"
tar -C "$workspace/plain" -czf "$archive" .
test -s "$archive"
tar -tzf "$archive" | grep -q './manifest.json'
# AES-256 symmetric encryption: never upload plain database or files to public artifacts.
printf '%s' "$BACKUP_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback   --passphrase-fd 0 --symmetric --cipher-algo AES256   --output "$archive.gpg" "$archive"
test -s "$archive.gpg"
# Verify decryptability and tar structure before any remote copy.
printf '%s' "$BACKUP_PASSPHRASE" | gpg --batch --yes --quiet --pinentry-mode loopback   --passphrase-fd 0 --decrypt "$archive.gpg" | tar -tzf - | grep -q './manifest.json'
rm -rf "$workspace/plain" "$archive"
echo "Archive chiffrée créée, inventaire présent, déchiffrement contrôlé."
