"""Publish the tested v0.4 line and a complete Release. Never deletes older branches/assets."""
import base64, concurrent.futures, hashlib, importlib.util, json, sys, urllib.parse, time, threading
from pathlib import Path
from package_v040 import PROJECT,ROOT,RELEASE,VERSION,source_files,sha,validate

spec=importlib.util.spec_from_file_location('github_api',PROJECT/'tools/gh_push.py')
api=importlib.util.module_from_spec(spec);spec.loader.exec_module(api)
BASE=f'/repos/{api.OWNER}/{api.REPO}'

def optional(path):
    try:return api.call('GET',path)
    except SystemExit as exc:
        if '-> 404:' in str(exc):return None
        raise

def blob_hash(path):
    data=path.read_bytes()
    return hashlib.sha1(f'blob {len(data)}\0'.encode()+data).hexdigest()

def publish():
    validate()
    expected=json.loads((ROOT/'releases/v0.4.0_包校验.json').read_text(encoding='utf-8'))
    files=source_files()
    parent=api.branch_sha('v0.3')
    old=api.commit_info(parent)
    existing={e['sha'] for e in api.tree_paths(old['tree']['sha']) if e['type']=='blob'}
    current=optional(BASE+'/git/ref/heads/v0.4')
    if current:
        existing.update(e['sha'] for e in api.tree_paths(api.commit_info(current['object']['sha'])['tree']['sha']) if e['type']=='blob')
    entries=[];needed=[]
    for name,path in files:
        digest=blob_hash(path)
        entries.append({'path':name,'mode':'100644','type':'blob','sha':digest})
        if digest not in existing:needed.append((path,digest))
    unique={digest:path for path,digest in needed}
    print(f'SOURCE {len(files)} files; upload {len(unique)} blobs; reuse {len(files)-len(needed)}',flush=True)
    rate_lock=threading.Lock()
    next_request=[0.0]
    def upload(item):
        digest,path=item
        with rate_lock:
            wait=max(0.0,next_request[0]-time.monotonic())
            next_request[0]=max(time.monotonic(),next_request[0])+.9
        if wait:time.sleep(wait)
        result=api.call('POST',BASE+'/git/blobs',{'content':base64.b64encode(path.read_bytes()).decode(),'encoding':'base64'})
        assert result['sha']==digest
        return digest
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for i,_ in enumerate(pool.map(upload,unique.items()),1):
            if i%20==0:print(f'BLOBS {i}/{len(unique)}',flush=True)
    tree=api.call('POST',BASE+'/git/trees',{'tree':entries})
    if current:
        previous=api.commit_info(current['object']['sha'])
        if previous['tree']['sha']!=tree['sha']:
            raise SystemExit('v0.4 already exists with a different tree; no force update performed')
        commit=current['object']['sha']
    else:
        commit=api.call('POST',BASE+'/git/commits',{'message':'v0.4.0: 三章首领、鬼市深处与完整体验打磨',
            'tree':tree['sha'],'parents':[parent]})['sha']
        api.call('POST',BASE+'/git/refs',{'ref':'refs/heads/v0.4','sha':commit})
    print('BRANCH v0.4 '+commit,flush=True)
    body=(RELEASE/'更新说明.txt').read_text(encoding='utf-8-sig')
    release=optional(BASE+'/releases/tags/v'+VERSION)
    if release is None:
        release=api.call('POST',BASE+'/releases',{'tag_name':'v'+VERSION,'target_commitish':commit,
            'name':'妖怪夜市 v'+VERSION,'body':body,'draft':True,'prerelease':False})
    existing_assets={a['name']:a for a in release.get('assets',[])}
    for metadata,kind in zip(expected['archives'],['win64','source']):
        path=ROOT/'releases'/metadata['file']
        assert sha(path)==metadata['sha256']
        name=f'YokaiNightMarket-v{VERSION}-{kind}.zip'
        if name in existing_assets:
            asset=existing_assets[name]
            assert asset.get('digest')=='sha256:'+metadata['sha256'],'Existing asset differs; not deleted or overwritten'
        else:
            print(f'UPLOAD {name} {path.stat().st_size} bytes',flush=True)
            asset=api.call('POST',f'https://uploads.github.com/repos/{api.OWNER}/{api.REPO}/releases/{release["id"]}/assets?name='+urllib.parse.quote(name),
                raw=path.read_bytes(),content_type='application/zip')
        assert asset['size']==metadata['bytes']
        assert asset.get('digest')=='sha256:'+metadata['sha256'],'Server-side SHA-256 verification failed'
        print(f'VERIFIED {name} {metadata["sha256"]}',flush=True)
    release=api.call('PATCH',BASE+f'/releases/{release["id"]}',{'draft':False,'body':body,'make_latest':'true'})
    api.call('PATCH',BASE,{'default_branch':'v0.4'})
    branches=api.call('GET',BASE+'/branches?per_page=100')
    assert {'v0.2.4','v0.3','v0.4'}.issubset({b['name'] for b in branches})
    assert api.branch_sha('v0.3')==parent
    result={'branch':'v0.4','commit':commit,'parent_v03':parent,'release':release['html_url'],
            'assets':[{'name':a['name'],'bytes':a['size'],'digest':a.get('digest'),'url':a['browser_download_url']} for a in release['assets']],
            'branches':[b['name'] for b in branches],'default_branch':'v0.4'}
    (ROOT/'releases/v0.4.0_发布回执.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False),flush=True)

if __name__=='__main__':
    if sys.argv[1:]!=['publish']:raise SystemExit('Use: python tools/publish_v040.py publish')
    publish()
