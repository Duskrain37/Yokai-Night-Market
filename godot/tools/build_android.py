"""Build signed Android APK; secrets must come from private environment variables."""
import argparse,json,os,subprocess,hashlib,zipfile,re,struct
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--godot',type=Path,required=True)
 parser.add_argument('--sdk',type=Path,required=True)
 parser.add_argument('--jdk',type=Path,required=True)
 parser.add_argument('--out',type=Path,default=PROJECT/'build/v0.5.3/YokaiNightMarket-android.apk')
 parser.add_argument('--qa',action='store_true')
 args=parser.parse_args()
 required=['GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']
 assert all(os.environ.get(k) for k in required),'Provide private signing environment variables, never store them in this project.'
 env={**os.environ,'JAVA_HOME':str(args.jdk.resolve()),'ANDROID_SDK_ROOT':str(args.sdk.resolve())}
 args.out=args.out.resolve();args.out.parent.mkdir(parents=True,exist_ok=True)
 result=subprocess.run([str(args.godot.resolve()),'--headless','--editor','--path',str(PROJECT),'--export-release','Android QA' if args.qa else 'Android',str(args.out)],capture_output=True,env=env,timeout=1200)
 output=(result.stdout+result.stderr).decode('utf-8','replace').replace(env[required[-1]],'[REDACTED]')
 log=PROJECT/'qa'/('export-android-qa.log' if args.qa else 'export-android.log');log.write_text(output,'utf-8')
 assert result.returncode==0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output,f'Export failed: see {log}'
 tools=next((args.sdk/'build-tools').glob('35.0.1'))
 verify=subprocess.run([str(args.jdk/'bin/java.exe'),'-jar',str(tools/'lib/apksigner.jar'),'verify','--verbose','--print-certs',str(args.out)],capture_output=True,check=True)
 cert=verify.stdout.decode('utf-8','replace')
 badging=subprocess.run([str(tools/'aapt.exe'),'dump','badging',args.out.name],cwd=args.out.parent,capture_output=True,check=True).stdout.decode('utf-8','replace')
 with zipfile.ZipFile(args.out) as archive:
  assert archive.testzip() is None
  files=archive.namelist()
  abis=sorted({name.split('/')[1] for name in files if name.startswith('lib/') and name.endswith('libgodot_android.so')})
  assert abis==(['x86_64'] if args.qa else ['arm64-v8a','armeabi-v7a']),abis
  motion=json.loads(archive.read('assets/data/actor_motion_mobile.json'))
  frame_count=0
  for actor,info in motion.items():
   for clip,frames in info['clips'].items():
    source=info.get('clip_files',{}).get(clip,info['file'])
    remap=archive.read('assets/'+source+'.import').decode('utf-8')
    found=re.search(r'^path="res://([^\"]+)"',remap,re.M);assert found,source
    texture=archive.read('assets/'+found[1]);assert texture[:4]==b'GST2',source
    width,height=struct.unpack_from('<II',texture,8)
    assert max(width,height)<=4096,(actor,clip,width,height)
    assert len(frames)==32,(actor,clip)
    for f in frames:
     x,y,w,h=f['rect'];assert x>=0 and y>=0 and x+w<=width and y+h<=height,(actor,clip,f)
    frame_count+=len(frames)
  if not args.qa:assert not any('qa_mobile_device' in name for name in files)
  assert not any(name.startswith('assets/tools/') or name.startswith('assets/qa/') for name in files)
 with args.out.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
 report={'file':args.out.name,'bytes':args.out.stat().st_size,'sha256':digest,'abis':abis,'animation_frames':frame_count,'signature':cert,'manifest':[line for line in badging.splitlines() if line.startswith(('package:','sdkVersion:','targetSdkVersion:','uses-permission:','supports-screens:','native-code:','launchable-activity:'))]}
 (PROJECT/'qa'/('android-qa-package.json' if args.qa else 'android-package.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n','utf-8')
 print(json.dumps({k:v for k,v in report.items() if k!='signature'},ensure_ascii=False))
if __name__=='__main__':main()
