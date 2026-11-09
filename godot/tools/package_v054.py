"""Seal validated PC v0.5.4. GitHub release attachment is the standalone EXE only."""
from pathlib import Path
import hashlib,json,re,shutil
from stamp_build import source_hash
PROJECT=Path(__file__).resolve().parents[1];ROOT=PROJECT.parent
VERSION='0.5.4';RELEASES=ROOT/'releases';RELEASE=RELEASES/('v'+VERSION);QA=PROJECT/'qa'
SUITES=('logic-tests','battle-tests','boss-tests','special-tests','ui-tests','click-tests','player-ui-tests','animation-tests','v050-tests','v051-refresh-tests','v052-tests','v053-tests','v054-tests','v054-new-content-tests','v054-nightmare-tests','v054-dual-soak')
EVIDENCE=('nightmare-settings','nightmare-info','nightmare-prep','nightmare-factors','nightmare-twins','nightmare-result','nightmare-stars','nightmare-badges','battle-settings-no-difficulty','new-roster','new-barge','new-barge-sink')
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
 for name in [*(s+'.json' for s in SUITES),'boss-balance.json','curve-v040.json','curve.csv','v054-final-patch.log','pack-audit.json','v054-campaign-verification.json','v054-new-motion-uniqueness.json','v054-new-font-coverage.json','v054-final-pack-check.log','v054-release-smoke.log','v054-packed-nightmare-visual.log','music-source-verification.json']:
  yield 'qa/'+name,QA/name
 for path in sorted(RELEASE.iterdir()):
  if path.is_file() and path.suffix!='.exe':yield path.name,path

def main():
 stamp,count=source_hash();info=(PROJECT/'data/build_info.gd').read_text(encoding='utf-8')
 assert f'BUILD_HASH = "{stamp}"' in info and f'VERSION = "{VERSION}"' in info
 totals={}
 for suite in SUITES:
  data=read(suite);assert data['failures']==0 and data['total']>0,suite;totals[suite]=data['total']
 patch=(QA/'v054-final-patch.log').read_text(encoding='utf-8');match=re.search(r'TOTAL (\d+)\s+FAILURES 0',patch);assert match and 'SCRIPT ERROR' not in patch;totals['patch-tests']=int(match[1])
 build=(QA/'build-v054-release.log').read_text(encoding='utf-8-sig');assert all(x not in build for x in ['SCRIPT ERROR','Parse Error','Compilation failed'])
 curves=read('curve-v040');assert len(curves['runs'])==100 and not curves['problems']
 verification=read('v054-campaign-verification');assert len(verification)==4 and all(r['exit']==0 and not r['errors'] for r in verification)
 balance=read('boss-balance');assert balance['failures']==0 and len(balance['runs'])==33
 challenges=read('challenge-validation');assert len(challenges)==6 and all(r['won'] and r['same_trace'] for r in challenges)
 lines=(QA/'v054-final-pack-check.log').read_text(encoding='utf-8-sig').splitlines();pack=json.loads(next(line for line in reversed(lines) if line.startswith('{')))
 assert stamp in lines and pack['failures']==0 and pack['checks']>12000
 assert not any('SCRIPT ERROR' in line or line.startswith('ERROR:') for line in lines)
 smoke=(QA/'v054-release-smoke.log').read_text(encoding='utf-8-sig');assert 'V054_EXPORT_OK' in smoke and 'ERROR:' not in smoke
 visuals=(QA/'v054-packed-nightmare-visual.log').read_text(encoding='utf-8-sig');assert 'CAPTURE nightmare-twins' in visuals and 'ERROR:' not in visuals
 assert all(r['frames']==32 and r['unique']>=24 for r in read('v054-new-motion-uniqueness'))
 assert all(not r['missing'] for r in read('v054-new-font-coverage'))
 RELEASE.mkdir(parents=True,exist_ok=True);exe=RELEASE/'YokaiNightMarket.exe';shutil.copy2(PROJECT/'build/v0.5.4/YokaiNightMarket.exe',exe)
 for name in ['README.md','ANIMATION_RIG.md','V054_REVIEW.md','V054_NIGHTMARE.md','V054_ART.md']:shutil.copy2(PROJECT/name,RELEASE/name)
 shutil.copy2(PROJECT/'V054_CHANGES.md',RELEASE/'更新说明.md')
 for name in ['LICENSE_Godot.txt','THIRD_PARTY_Godot.txt','字体授权_OFL.txt']:shutil.copy2(RELEASES/'v0.4.0'/name,RELEASE/name)
 (RELEASE/'游玩说明.txt').write_text('妖怪夜市 v0.5.4 PC\n\n下载 Windows 64位独立EXE，双击直接启动，无需安装或解压。\n左键选卡、落子、查看、进化，右键取消；数字键切卡，P或空格暂停，Esc返回，F11切换全屏。可在设置重绑卡槽和倍速键。\n难度只在局外修改；噩梦难度旁的圆形i可查看红星和十三种因子说明。因子在备战选择，开战后锁定。\n噩梦通关独立获得红星，带因子通关可留下朱印与挑战徽章，作弊局不领奖。\n旧进度兼容，数据仍位于 %APPDATA%\\YokaiNightMarket\\。本轮不重封移动版。\n',encoding='utf-8')
 shots=RELEASE/'验收画面';shots.mkdir(exist_ok=True)
 for name in EVIDENCE:shutil.copy2(QA/('v054-'+name+'.png'),shots/(name+'.png'))
 inputs={p.name:digest(p) for p in [ROOT/'人工_草木 改动与新增说明.txt',ROOT/'人工_恶客 改动与新增说明.txt']}
 campaigns={d:{'wins':sum(r['won'] for r in curves['runs'] if r['difficulty']==d),'runs':25} for d in ['easy','normal','hard','nightmare']}
 record={'version':VERSION,'build_hash':stamp,'build_files':count,'exe_bytes':exe.stat().st_size,'exe_sha256':digest(exe),'assertions':totals,'assertion_total':sum(totals.values()),'failures':0,'pack_checks':pack,'pack_trim':read('pack-audit'),'campaigns':campaigns,'independent_campaign_repeat':100,'boss_simulations':33,'challenge_runs':6,'new_motion_clips':34,'new_motion_frames':1088,'motion_frames':pack['frames'],'input_documents':inputs,'platform':'Windows x64','verification':'PC源码规则与交互、100场四档策略基线及独立复验、双恶首事务与读档、实际EXE启动、瘦身包资源和Godot画面。机器人失守并非人类不可通证明；未宣称人工25夜全通或低端机实测。移动v0.5.3-mobile保持原样。'}
 (RELEASE/'验收记录.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');(RELEASES/'v0.5.4_包校验.json').write_text(json.dumps({'exe':record},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'build':stamp,'bytes':record['exe_bytes'],'sha256':record['exe_sha256'],'assertions':record['assertion_total'],'pack_checks':pack['checks']},ensure_ascii=False))
if __name__=='__main__':main()
