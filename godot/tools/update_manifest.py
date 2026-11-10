"""Resource-aligned SHA-256 map for HTTP Range updates of the standalone Windows EXE.

The release EXE remains the only binary download. Unchanged local resource chunks
can be reused despite relocation inside the PCK. No old-version patch chain is needed.
"""
from pathlib import Path
import argparse,hashlib,json,mmap,struct

CHUNK=1024*1024
ASSET='YokaiNightMarket-win64.exe'
MAP_ASSET='YokaiNightMarket-update-map.json'
MAX_SIZE=2*1024**3

def blocks(data):
    """Yield a contiguous, nonoverlapping partition covering every byte exactly once."""
    length,magic=struct.unpack_from('<Q4s',data,len(data)-12)
    start=len(data)-12-length
    if magic!=b'GDPC' or start<4096:raise ValueError('Missing embedded PCK footer')
    pck_magic,version,major,minor,patch,flags=struct.unpack_from('<4s5I',data,start)
    if pck_magic!=b'GDPC' or version!=4:raise ValueError('Unsupported PCK layout')
    base,table=struct.unpack_from('<QQ',data,start+24)
    if base<48 or not base<table<length:raise ValueError('Invalid PCK index')
    cursor=start+table;count,=struct.unpack_from('<I',data,cursor);cursor+=4
    if count>100000:raise ValueError('Excessive PCK entry count')
    spans=set()
    for _ in range(count):
        size,=struct.unpack_from('<I',data,cursor);cursor+=4
        if size>65536:raise ValueError('Invalid PCK name')
        cursor+=size
        offset,size,_md5,entry_flags=struct.unpack_from('<QQ16sI',data,cursor);cursor+=36
        if entry_flags or offset+size>table-base:raise ValueError('Invalid PCK span')
        if size:spans.add((start+base+offset,size))
    at=0
    for offset,size in sorted(spans):
        if offset<at:raise ValueError('Overlapping PCK resources')
        for p in range(at,offset,CHUNK):yield p,min(CHUNK,offset-p)
        for p in range(offset,offset+size,CHUNK):yield p,min(CHUNK,offset+size-p)
        at=offset+size
    for p in range(at,len(data),CHUNK):yield p,min(CHUNK,len(data)-p)

def describe(path):
    with Path(path).open('rb') as handle,mmap.mmap(handle.fileno(),0,access=mmap.ACCESS_READ) as data:
        return [{'offset':offset,'size':size,'sha256':hashlib.sha256(data[offset:offset+size]).hexdigest()} for offset,size in blocks(data)]

def make(exe,version,build):
    exe=Path(exe)
    if not 0<exe.stat().st_size<MAX_SIZE:raise ValueError('Unsupported EXE size')
    segments=describe(exe)
    with exe.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
    return {'schema':1,'version':version,'build':build,'asset':ASSET,'size':exe.stat().st_size,'sha256':digest,'chunk_size':CHUNK,'segments':segments}

def estimate(old,target):
    existing={x['sha256'] for x in describe(old)}
    missing={x['sha256']:x['size'] for x in target['segments'] if x['sha256'] not in existing}
    return {'target_bytes':target['size'],'download_bytes':sum(missing.values()),'reuse_bytes':sum(x['size'] for x in target['segments'] if x['sha256'] in existing),'missing_unique_chunks':len(missing),'download_percent':round(sum(missing.values())/target['size']*100,3)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('exe',type=Path);parser.add_argument('--version',required=True);parser.add_argument('--build',required=True);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--compare',type=Path)
    a=parser.parse_args();payload=make(a.exe,a.version,a.build);a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(payload,separators=(',',':'),ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'map':str(a.out),'segments':len(payload['segments']),'bytes':payload['size'],'sha256':payload['sha256'],'delta':estimate(a.compare,payload) if a.compare else None},ensure_ascii=False))
if __name__=='__main__':main()
