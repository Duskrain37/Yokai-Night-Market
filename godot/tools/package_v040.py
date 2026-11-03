"""Curated local v0.4.0 package; also supplies the exact source file list to publishing."""
from pathlib import Path
import hashlib, importlib.util, json, re, shutil, zipfile

PROJECT=Path(__file__).resolve().parents[1]
ROOT=PROJECT.parent
VERSION='0.4.0'
RELEASE=ROOT/'releases'/('v'+VERSION)
QA_NAMES=['logic-tests.json','battle-tests.json','boss-tests.json','special-tests.json',
          'ui-tests.json','click-tests.json','player-ui-tests.json','boss-balance.json',
          'curve-v040.json','curve.csv','sfx_v040.json','approved-text-sync.json','boss-full-runs.json']
DOC_NAMES=['README.md','更新说明.txt','游玩说明.txt','V040_IMPLEMENTATION.md',
           'LICENSE_Godot.txt','THIRD_PARTY_Godot.txt','字体授权_OFL.txt','验收记录.json']

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def source_files():
    files=[]
    for path in sorted(PROJECT.rglob('*')):
        if not path.is_file():continue
        rel=path.relative_to(PROJECT)
        if rel.parts[0] not in {'assets','data','scripts','scenes','ui','tools'} and len(rel.parts)>1:continue
        if '__pycache__' in rel.parts or 'fonts-cache' in rel.parts:continue
        if path.suffix in {'.pyc','.tmp','.exe','.zip','.bak'}:continue
        if rel.parts[0] in {'.godot','build','qa','.git'}:continue
        files.append(('godot/'+rel.as_posix(),path))
    for name in QA_NAMES:
        path=PROJECT/'qa'/name
        if path.exists():files.append(('qa/'+name,path))
    for name in DOC_NAMES:
        path=RELEASE/name
        if path.exists():files.append((name,path))
    return files

def validate():
    totals={}
    for name in QA_NAMES[:7]:
        data=json.loads((PROJECT/'qa'/name).read_text(encoding='utf-8'))
        assert data['failures']==0,(name,data['failures'])
        totals[name]=data['total']
    data=json.loads((PROJECT/'qa/boss-balance.json').read_text(encoding='utf-8'))
    assert data['failures']==0 and len(data['runs'])==27
    assert not json.loads((PROJECT/'qa/curve-v040.json').read_text(encoding='utf-8'))['problems']
    spec=importlib.util.spec_from_file_location('stamp',PROJECT/'tools/stamp_build.py')
    stamp=importlib.util.module_from_spec(spec);spec.loader.exec_module(stamp)
    actual,_=stamp.source_hash()
    build=(PROJECT/'data/build_info.gd').read_text(encoding='utf-8')
    assert f'BUILD_HASH = "{actual}"' in build,'Source changed since final stamp/export'
    assert 'VERSION = "0.4.0"' in build
    return totals,data,actual

def main():
    RELEASE.mkdir(parents=True,exist_ok=True)
    totals,balance,build_hash=validate()
    source_exe=PROJECT/'build/v0.4.0/YokaiNightMarket.exe'
    target=RELEASE/'YokaiNightMarket.exe';shutil.copy2(source_exe,target)
    for name in ['README.md','V040_IMPLEMENTATION.md']:shutil.copy2(PROJECT/name,RELEASE/name)
    for name in ['LICENSE_Godot.txt','THIRD_PARTY_Godot.txt','字体授权_OFL.txt']:
        shutil.copy2(ROOT/'releases/v0.3.1'/name,RELEASE/name)
    center=[r for r in balance['runs'] if r['profile']=='reference']
    record={'version':VERSION,'build_hash':build_hash,'exe_bytes':target.stat().st_size,'exe_sha256':sha(target),
        'assertions':totals,'assertion_total':sum(totals.values()),'failures':0,
        'boss_simulations':27,'boss_reference_seconds':[min(r['combat_s'] for r in center),max(r['combat_s'] for r in center)],
        'scope':'Windows x64; headless tests and native rendered captures; no claim of human full clear, human listening or other-platform verification'}
    (RELEASE/'验收记录.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    screenshots=RELEASE/'验收画面';screenshots.mkdir(exist_ok=True)
    evidence=ROOT.parent/'tmp/v040-work'
    for name in ['release-boss1.png','release-boss2.png','release-boss3.png','release-gauntlet.png',
                 'release-prep.png','release-levels.png','release-almanac.png','release-settings.png',
                 'release-evolve1.png','release-evolve2.png','release-evolve3.png']:
        if (evidence/name).exists():shutil.copy2(evidence/name,screenshots/name)
    paths=[(ROOT/'releases'/f'妖怪夜市v{VERSION}_win64.zip',[(p.relative_to(RELEASE).as_posix(),p) for p in RELEASE.rglob('*') if p.is_file()]),
           (ROOT/'releases'/f'妖怪夜市v{VERSION}_源码.zip',source_files())]
    archives=[]
    for path,files in paths:
        with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=7) as z:
            for name,local in files:z.write(local,name)
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None
            if 'YokaiNightMarket.exe' in z.namelist():
                assert hashlib.sha256(z.read('YokaiNightMarket.exe')).hexdigest()==record['exe_sha256']
        archives.append({'file':path.name,'bytes':path.stat().st_size,'sha256':sha(path)})
    (ROOT/'releases'/'v0.4.0_包校验.json').write_text(json.dumps({'exe':record,'archives':archives},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'exe':record,'archives':archives},ensure_ascii=False))

if __name__=='__main__':main()
