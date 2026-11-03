"""Original, deterministic, soft modal wood/bronze/skin/paper sound library.
44.1 kHz PCM, 18 ms minimum attack, low-pass 1.6 kHz, quiet RMS, no pitch slides.
"""
from pathlib import Path
import json,hashlib,wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
RATE=44100
NAMES=['click','collect','produce','place','deny','place_bad','shoot','gravel_shot','needle_shot',
 'cat_shot','star_shot','lob_shot','eat','bell','censer','umbrella','lion','judge','upgrade',
 'shell','explode','mine','zombie_die','plant_down','wave','alert','mower','wail','grant','win','lose','kill',
 'boss_intro','boss_warning','boss_impact','boss_paper','boss_defeat','mushroom_grow']
NAMES += [prefix+material for prefix in ['hit_','break_'] for material in ['body','straw','stone','urn','iron','paper']]

def modal(t,tones,decay):
 out=np.zeros_like(t)
 for freq,amp in tones:out+=amp*np.sin(2*np.pi*freq*t)*np.exp(-t*decay*(1+freq/1500))
 return out

def make(name):
 seconds=.32
 group='wood';rms_db=-28
 if name in ['collect','produce','bell','upgrade','grant','mushroom_grow']:group='bronze';seconds=.62;rms_db=-29 if name=='produce' else -26
 if name in ['wave','alert','boss_intro','boss_warning','boss_impact','mower','explode','mine','lion','judge']:
  group='drum';seconds=.8;rms_db=-24 if name.startswith('boss') else -26
 if name in ['censer','umbrella','wail','plant_down','zombie_die','kill','boss_paper'] or 'paper' in name or 'straw' in name:
  group='paper';seconds=.45;rms_db=-28
 if name in ['win','lose','boss_defeat']:group='gong';seconds=1.3;rms_db=-26
 if name in ['click','deny','place_bad']:seconds=.22;rms_db=-30
 if name.startswith('hit_'):seconds=.22;rms_db=-29
 if name.startswith('break_'):seconds=.42;rms_db=-27
 t=np.arange(round(seconds*RATE))/RATE
 rng=np.random.default_rng(int.from_bytes(hashlib.sha256(name.encode()).digest()[:4],'little'))
 noise=rng.normal(size=t.size)
 # Gentle noise resonance; never a raw digital click or full-band hiss.
 breath=np.convolve(noise,np.hanning(181)/np.hanning(181).sum(),mode='same')
 if group=='wood':y=modal(t,[(245,.7),(432,.23),(706,.07)],13)+breath*.25*np.exp(-t*16)
 elif group=='bronze':y=modal(t,[(293.66,.7),(490,.20),(773,.07)],5.5)+breath*.06*np.exp(-t*8)
 elif group=='drum':y=modal(t,[(67,.6),(109,.3),(183,.14)],6)+breath*.45*np.exp(-t*9)
 elif group=='paper':y=modal(t,[(146.83,.25),(220,.1)],8)+breath*.8*np.exp(-t*7)
 else:
  y=modal(t,[(110,.6),(185,.27),(294,.12)],3)
  if name in ['win','boss_defeat']:
   for start,f in [(.18,220),(.39,293.66),(.65,349.23)]:
    q=np.maximum(0,t-start);y+=(t>=start)*.13*np.sin(2*np.pi*f*q)*(1-np.exp(-q/0.06))*np.exp(-q*6)
 # Raised-cosine attack and release remove both discontinuities.
 attack=.018 if group=='wood' else .035
 y*=np.sin(np.minimum(1,t/attack)*np.pi/2)**2
 y*=np.sin(np.minimum(1,(seconds-t)/.06)*np.pi/2)**2
 taps=301;n=np.arange(taps)-(taps-1)/2
 kernel=2*1600/RATE*np.sinc(2*1600/RATE*n)*np.hanning(taps);kernel/=kernel.sum()
 y=np.convolve(y,kernel,mode='same')
 y-=np.mean(y)
 y*=10**(rms_db/20)/max(1e-8,np.sqrt(np.mean(y*y)))
 y*=min(1,.35/max(1e-8,np.max(np.abs(y))))
 y[:2]=0;y[-2:]=0
 return y,group

def main():
 out=ROOT/'assets/sfx/v040';out.mkdir(parents=True,exist_ok=True)
 records=[]
 for name in NAMES:
  y,group=make(name);pcm=np.round(y*32767).astype('<i2')
  with wave.open(str(out/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm.tobytes())
  spectrum=np.abs(np.fft.rfft(y))**2;freq=np.fft.rfftfreq(y.size,1/RATE)
  records.append(dict(name=name,material=group,duration_s=len(y)/RATE,
   peak_dbfs=round(20*np.log10(max(1e-8,np.max(np.abs(y)))),2),
   rms_dbfs=round(20*np.log10(max(1e-8,np.sqrt(np.mean(y*y)))),2),
   energy_above_3khz=float(spectrum[freq>=3000].sum()/max(1e-12,spectrum.sum()))))
 assert all(r['energy_above_3khz']<.005 and r['peak_dbfs']<=-9 and r['rms_dbfs']<=-23.9 for r in records)
 report={'origin':'original procedural modal synthesis, no external recordings','files':records,
  'listening_note':'spectral/level checks reduce harshness but do not replace human listening on headphones and speakers'}
 (ROOT/'qa/sfx_v040.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 # A review reel, at the same quiet gain used by the game.
 parts=[]
 for name in ['click','collect','produce','place','shoot','bell','upgrade','boss_intro','boss_warning','boss_impact','boss_paper','boss_defeat']:
  parts.extend([make(name)[0],np.zeros(int(RATE*.35))])
 with wave.open(str(ROOT/'qa/sfx_v040_audition.wav'),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes((np.concatenate(parts)*32767).astype('<i2').tobytes())
 print('Mastered',len(records),'quiet modal sounds; peak <= -9 dBFS; >3 kHz energy < 0.5%.')

if __name__=='__main__':main()
