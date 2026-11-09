"""Check every approved day track against its local master, including weeks 4 and 5."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def main():
 rows=[]
 for day in range(1,6):
  for phase in ['battle','hot','final']:
   name=f'day{day}-{phase}.ogg';source=ROOT.parent/'music'/name;target=ROOT/'assets/music/complete'/name
   assert source.is_file() and target.is_file(),name
   a=hashlib.sha256(source.read_bytes()).hexdigest();b=hashlib.sha256(target.read_bytes()).hexdigest();assert a==b,f'Music master mismatch: {name}'
   rows.append({'name':name,'sha256':a,'bytes':target.stat().st_size})
 out=ROOT/'qa/music-source-verification.json';out.write_text(json.dumps({'total':15,'failures':0,'tracks':rows},indent=2)+'\n','utf-8');print('15 approved music tracks match their source SHA-256')
if __name__=='__main__':main()
