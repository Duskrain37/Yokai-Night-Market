"""Seal only a validated PC v0.5.5 executable, with reproducible release evidence."""
from pathlib import Path
import hashlib,json,re,shutil
from stamp_build import source_hash
PROJECT=Path(__file__).resolve().parents[1];ROOT=PROJECT.parent
VERSION='0.5.5';RELEASES=ROOT/'releases';RELEASE=RELEASES/('v'+VERSION);QA=PROJECT/'qa'
SUITES=('logic-tests','battle-tests','boss-tests','special-tests','ui-tests','click-tests','player-ui-tests','animation-tests','v050-tests','v051-refresh-tests','v052-tests','v053-tests','v054-tests','v054-new-content-tests','v054-nightmare-tests','v054-dual-soak','v055-tests','v055-ui-tests')
EVIDENCE=('nightmare-info','prep-twelve','prep-eight','battle-twelve','new-forms','mortar-blast','almanac-year-banyan','almanac-sky-mortar','firework-forms','news')
def read(name):return json.loads((QA/(name+'.json')).read_text(encoding='utf-8-sig'))
def digest(path):
 with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def source_entries():
 for path in sorted(PROJECT.rglob('*')):
  rel=path.relative_to(PROJECT)
  if rel.parts[0] not in {'assets','data','scripts','scenes','ui','tools'} and len(rel.parts)!=1:continue
  if not path.is_file() or any(x in rel.parts for x in {'__pycache__','fonts-cache'}):continue
  if path.suffix in {'.pyc','.tmp','.exe','.zip','.bak'}:continue
  yield 'godot/'+rel.as_posix(),path
 for name in [*(s+'.json' for s in SUITES),'curve-v040.json','v055-final-regression.json','v055-motion-check.json','v055-font-check.json','v055-pack-check.log','v055-release-smoke.log','v055-packed-visual.log','v055-patch.log','pack-audit.json','music-source-verification.json']:
  yield 'qa/'+name,QA/name
 for path in sorted(RELEASE.iterdir()):
  if path.is_file() and path.suffix!='.exe':yield path.name,path
def main():
 stamp,count=source_hash();info=(PROJECT/'data/build_info.gd').read_text(encoding='utf-8')
 assert f'BUILD_HASH = "{stamp}"' in info and f'VERSION = "{VERSION}"' in info
 totals={}
 for suite in SUITES:
  d=read(suite);assert d['failures']==0 and d['total']>0,suite;totals[suite]=d['total']
 patch=(QA/'v055-patch.log').read_text(encoding='utf-8-sig');m=re.search(r'TOTAL (\d+)\s+FAILURES 0',patch);assert m and 'SCRIPT ERROR' not in patch;totals['patch-tests']=int(m[1])
 regression=read('v055-final-regression');assert len(regression)==17 and all(r['exit']==0 and not r['issues'] for r in regression)
 curve=read('curve-v040');assert len(curve['runs'])==100 and not curve['problems']
 lines=(QA/'v055-pack-check.log').read_text(encoding='utf-8-sig').splitlines();pack=json.loads(next(x for x in reversed(lines) if x.startswith('{')));assert stamp in lines and pack['failures']==0 and pack['frames']>=12672
 for name,token in [('v055-release-smoke.log','V055_EXPORT_OK'),('v055-packed-visual.log','CAPTURE firework-forms')]:
  text=(QA/name).read_text(encoding='utf-8-sig');assert token in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text
 assert all(r['frames']==32 and r['unique']>=24 for r in read('v055-motion-check'))
 assert all(not r['missing'] for r in read('v055-font-check'))
 assert not (PROJECT/'data/challenges.gd').exists() and not (PROJECT/'ui/screen_challenges.gd').exists()
 RELEASE.mkdir(parents=True,exist_ok=True);exe=RELEASE/'YokaiNightMarket.exe';shutil.copy2(PROJECT/'build/v0.5.5/YokaiNightMarket.exe',exe)
 for name in ['README.md','ANIMATION_RIG.md','V055_REVIEW.md','V055_ART.md','V055_NIGHTMARE.md']:shutil.copy2(PROJECT/name,RELEASE/name)
 shutil.copy2(PROJECT/'V055_CHANGES.md',RELEASE/'更新说明.md')
 for name in ['LICENSE_Godot.txt','THIRD_PARTY_Godot.txt','字体授权_OFL.txt']:shutil.copy2(RELEASES/'v0.4.0'/name,RELEASE/name)
 (RELEASE/'游玩说明.txt').write_text('妖怪夜市 v0.5.5 Windows x64\n下载EXE后双击直接启动，无需安装或解压。\n左键选卡、种植与进化，右键取消；1—9、0、-、=切换十二个卡槽；P/空格暂停，Esc返回，F11全屏。设置中可以改键。\n噩梦难度只在局外修改，备战时选择因子；行囊受限可改为限带10/8株。难度旁i可滚动阅读说明。\n本次只更新PC，仅EXE上传GitHub；移动版保留v0.5.3-mobile。\n',encoding='utf-8')
 shots=RELEASE/'验收画面';shots.mkdir(exist_ok=True)
 for name in EVIDENCE:shutil.copy2(QA/('v055-'+name+'.png'),shots/(name+'.png'))
 docs={p.name:digest(p) for p in [ROOT/'pc端待办1.docx',ROOT/'草木改动与新增1.docx']}
 record={'version':VERSION,'build_hash':stamp,'build_files':count,'exe_bytes':exe.stat().st_size,'exe_sha256':digest(exe),'assertions':totals,'assertion_total':sum(totals.values()),'failures':0,'pack_checks':pack,'pack_trim':read('pack-audit'),'input_documents':docs,'new_clips':26,'new_frames':832,'portraits':11,'campaigns':{d:{'runs':25,'won':sum(r['won'] for r in curve['runs'] if r['difficulty']==d)} for d in ['easy','normal','hard','nightmare']},'platform':'Windows x64','verification':'规则、交互、存档、100场固定十卡策略回归、实际渲染、EXE启动与包内资源；并非人工全夜通关或低端设备实测。移动版未改。'}
 (RELEASE/'验收记录.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');(RELEASES/'v0.5.5_包校验.json').write_text(json.dumps({'exe':record},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'build':stamp,'bytes':record['exe_bytes'],'sha256':record['exe_sha256'],'assertions':record['assertion_total'],'pack_checks':pack['checks']},ensure_ascii=False))
if __name__=='__main__':main()
