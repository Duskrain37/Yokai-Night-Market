"""Original quiet material-resonance sounds for six existing plants, never remasters music."""
from pathlib import Path
import numpy as np,wave,json,hashlib
ROOT=Path(__file__).resolve().parents[1];RATE=44100
RECIPES={
 'reed_breath':(.42,[(164,.35,8),(247,.14,12)],1.0,1100,-31,'hollow bamboo reed with quiet leaf air'),
 'relay_release':(.35,[(196,.6,12),(392,.18,16)],.2,1200,-31,'lotus wood latch and old brass seed'),
 'ruin_bloom':(.8,[(58,.8,6),(103,.25,9),(174,.1,12)],.45,650,-27,'stone cavity, low ash rush'),
 'kite_shot':(.28,[(185,.4,16),(311,.2,20)],.9,1600,-30,'bamboo frame and paper flutter'),
 'till_income':(.3,[(247,.65,18),(412,.25,23)],.16,1300,-30,'abacus bead against wood'),
 'till_shot':(.23,[(294,.6,19),(521,.2,25)],.20,1500,-31,'short bamboo counting slip'),
 'till_call':(.48,[(196,.6,8),(329,.28,12)],.15,1300,-29,'wood tally with muted bronze'),
 'pod_income':(.32,[(349,.6,14),(587,.24,21),(907,.08,25)],.1,1800,-30,'soft round coin clink'),
 'cicada_shot':(.32,[(131,.6,15),(233,.24,20)],.7,1300,-29,'clay fire shell and warm air'),
 'cicada_reload':(.48,[(164,.5,11),(277,.2,16)],.55,1000,-30,'dry wing fold and ceramic click'),
 'herb_heal':(.6,[(220,.6,6),(330,.25,8),(495,.1,10)],.35,1200,-29,'gourd hollow note and leaf breath'),
}
def make(key):
 seconds,modes,noise_amp,cutoff,db,material=RECIPES[key];t=np.arange(round(seconds*RATE))/RATE
 rng=np.random.default_rng(int.from_bytes(hashlib.sha256(key.encode()).digest()[:4],'little'))
 noise=rng.normal(size=t.size);noise=np.convolve(noise,np.hanning(101)/np.hanning(101).sum(),mode='same')
 y=sum(a*np.sin(2*np.pi*f*t)*np.exp(-dec*t) for f,a,dec in modes)+noise*noise_amp*np.exp(-t*10)
 n=np.arange(301)-150;kernel=2*cutoff/RATE*np.sinc(2*cutoff/RATE*n)*np.hanning(301);kernel/=kernel.sum();y=np.convolve(y,kernel,mode='same')
 y*=np.sin(np.minimum(1,t/.025)*np.pi/2)**2*np.sin(np.minimum(1,(seconds-t)/.06)*np.pi/2)**2
 y-=y.mean();y*=10**(db/20)/max(1e-8,np.sqrt(np.mean(y*y)));y*=min(1,.28/max(abs(y)));y[:2]=0;y[-2:]=0
 return y

def save(path,y):
 with wave.open(str(path),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.round(y*32767).astype('<i2').tobytes())
def main():
 dest=ROOT/'assets/sfx/v040';records=[];parts=[]
 for key in RECIPES:
  y=make(key);save(dest/(key+'.wav'),y)
  energy=abs(np.fft.rfft(y))**2;hz=np.fft.rfftfreq(len(y),1/RATE)
  record={'key':key,'material':RECIPES[key][-1],'duration':len(y)/RATE,'peak_dbfs':float(20*np.log10(max(abs(y)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(y*y)))),'above_3khz':float(energy[hz>3000].sum()/energy.sum())};assert record['peak_dbfs']<-10 and record['above_3khz']<.005
  records.append(record);parts.extend([y,np.zeros(RATE//2)])
 save(ROOT/'qa/v054-sfx-audition.wav',np.concatenate(parts))
 (ROOT/'data/v054_sfx_mastering.json').write_text(json.dumps({'origin':'original material modal sound design, no third-party recordings','files':records,'audition_order':list(RECIPES),'listening_limit':'Level and spectrum checked; awaiting user headphone/speaker listening.'},ensure_ascii=False,indent=2)+'\n','utf-8')
 print(str(len(RECIPES))+' distinct material samples; peak<-10dBFS, high-frequency energy<0.5%')
if __name__=='__main__':main()
