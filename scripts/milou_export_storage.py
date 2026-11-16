#!/usr/bin/env python3
"""Export all Supabase Storage objects for a nightly encrypted off-site backup."""
import json
import os
import pathlib
import sys
import time
from urllib.parse import quote
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

base=os.environ["SUPABASE_URL"].rstrip("/")
token=os.environ["SUPABASE_SERVICE_ROLE_KEY"]
target=pathlib.Path(sys.argv[1])
target.mkdir(parents=True,exist_ok=True)
headers={"Authorization":"Bearer "+token,"apikey":token}
def call(method,path,payload=None):
    body=None if payload is None else json.dumps(payload).encode()
    req=Request(base+path, data=body,method=method,headers={
        **headers,**({"Content-Type":"application/json"} if body is not None else {})
    })
    last=None
    for attempt in range(5):
        try:
            with urlopen(req,timeout=60) as resp:
                return resp.read()
        except (HTTPError,URLError,TimeoutError) as err:
            last=err
            if isinstance(err,HTTPError) and err.code in (400,401,403,404):
                raise RuntimeError(f"Storage access HTTP {err.code} for {path.split('?')[0]}") from err
            time.sleep(2**attempt)
    raise RuntimeError(f"Storage export failed: {path}") from last

def listing(bucket,prefix=""):
    offset=0
    while True:
        path="/storage/v1/object/list/"+quote(bucket,safe="")
        rows=json.loads(call("POST",path,{"prefix":prefix,"limit":1000,"offset":offset,"sortBy":{"column":"name","order":"asc"}}))
        if not isinstance(rows,list):
            raise RuntimeError("Unexpected Storage list response")
        for row in rows:
            name=row.get("name")
            if not isinstance(name,str) or not name:
                raise RuntimeError("Invalid storage object name")
            if row.get("id") is None:
                yield from listing(bucket,prefix+name+"/")
            else:
                yield prefix+name
        if len(rows)<1000:
            return
        offset+=len(rows)

buckets=json.loads(call("GET","/storage/v1/bucket"))
if not isinstance(buckets,list):
    raise RuntimeError("Storage buckets response invalid")
summary={}
for item in buckets:
    bucket=item["id"]
    folder=target/bucket
    folder.mkdir(parents=True,exist_ok=True)
    count=0
    for object_path in listing(bucket):
        parts=pathlib.PurePosixPath(object_path).parts
        if any(part in (".","..") for part in parts) or object_path.startswith("/"):
            raise RuntimeError("Unsafe storage path")
        path=folder.joinpath(*parts)
        path.parent.mkdir(parents=True,exist_ok=True)
        raw=call("GET","/storage/v1/object/authenticated/"+quote(bucket,safe="")+"/"+quote(object_path,safe="/"))
        path.write_bytes(raw)
        count+=1
    summary[bucket]=count
(target/"storage-index.json").write_text(json.dumps({"buckets":summary},indent=2))
print("Storage objects exported:",sum(summary.values()))
