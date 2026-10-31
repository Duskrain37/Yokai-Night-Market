export function drawShell(ctx, shell, t) {
  const ratio = shell.maxHp > 0 ? Math.max(0, Math.min(1, shell.hp / shell.maxHp)) : 1;
  const pulse = Math.sin(t * 1.35) * 0.012;
  ctx.save();
  ctx.translate(0, -10 + pulse * 18);
  ctx.scale(1 + pulse, 1 - pulse * 0.5);
  ctx.fillStyle = 'rgba(18,26,20,0.5)';
  ctx.beginPath();
  ctx.ellipse(0, 34, 38, 8, 0, 0, Math.PI * 2);
  ctx.fill();
  const g = ctx.createRadialGradient(-8, -26, 6, 0, -18, 48);
  g.addColorStop(0, '#7d8d68');
  g.addColorStop(0.6, '#4d5c43');
  g.addColorStop(1, '#2b3527');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.ellipse(0, -12, 44, 36, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(220,200,140,0.65)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(0, -12, 44, 36, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(198,176,116,0.32)';
  ctx.lineWidth = 1.4;
  for (let i = -2; i <= 2; i++) {
    ctx.beginPath();
    ctx.ellipse(0, -12, 44 - Math.abs(i) * 7, 36 - Math.abs(i) * 5, 0, 0.2, Math.PI - 0.2);
    ctx.stroke();
  }
  for (let i = -1; i <= 1; i++) {
    ctx.beginPath();
    ctx.moveTo(i * 17, -44);
    ctx.lineTo(i * 14, 18);
    ctx.stroke();
  }
  ctx.strokeStyle = 'rgba(196,176,116,0.28)';
  ctx.lineWidth = 1.1;
  ctx.beginPath();
  ctx.moveTo(-30, -26);
  ctx.lineTo(-12, -34);
  ctx.lineTo(0, -22);
  ctx.lineTo(-10, -8);
  ctx.lineTo(-28, -8);
  ctx.closePath();
  ctx.moveTo(30, -26);
  ctx.lineTo(12, -34);
  ctx.lineTo(0, -22);
  ctx.lineTo(10, -8);
  ctx.lineTo(28, -8);
  ctx.closePath();
  ctx.moveTo(-10, 4);
  ctx.lineTo(0, 14);
  ctx.lineTo(10, 4);
  ctx.lineTo(6, -8);
  ctx.lineTo(-6, -8);
  ctx.closePath();
  ctx.stroke();
  ctx.fillStyle = 'rgba(44,56,38,0.55)';
  ctx.beginPath();
  ctx.ellipse(-30, 20, 7, 4, -0.3, 0, Math.PI * 2);
  ctx.ellipse(30, 20, 7, 4, 0.3, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(240,215,150,0.85)';
  ctx.font = '700 12px serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('镇', 0, -12);
  if (ratio < 0.66) {
    ctx.strokeStyle = 'rgba(30,22,16,0.7)';
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.moveTo(-26, -36);
    ctx.lineTo(-12, -22);
    ctx.lineTo(-18, -4);
    ctx.moveTo(20, -38);
    ctx.lineTo(9, -24);
    ctx.lineTo(16, -8);
    ctx.stroke();
  }
  if (ratio < 0.33) {
    ctx.strokeStyle = 'rgba(20,14,10,0.85)';
    ctx.beginPath();
    ctx.moveTo(-4, -46);
    ctx.lineTo(2, -26);
    ctx.lineTo(-6, -12);
    ctx.lineTo(3, 4);
    ctx.stroke();
  }
  ctx.restore();
}

export function drawShellFront(ctx, shell, t) {
  const ratio = shell.maxHp > 0 ? Math.max(0, Math.min(1, shell.hp / shell.maxHp)) : 1;
  const breathe = Math.sin(t * 1.35) * 0.012;
  ctx.save();
  ctx.translate(0, breathe * 18);
  ctx.scale(1 + breathe, 1 - breathe * 0.5);
  const g = ctx.createRadialGradient(-10, -30, 8, 0, -12, 50);
  g.addColorStop(0, '#87976f');
  g.addColorStop(0.55, ratio > 0.35 ? '#566647' : '#46543b');
  g.addColorStop(1, '#2f3a29');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.ellipse(0, -12, 45, 37, 0, 0, Math.PI * 2);
  ctx.ellipse(0, -12, 32, 25, 0, 0, Math.PI * 2);
  ctx.fill('evenodd');
  ctx.strokeStyle = ratio > 0.35 ? 'rgba(232,210,154,0.9)' : 'rgba(156,142,104,0.85)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(0, -12, 45, 37, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(226,206,152,0.55)';
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  ctx.ellipse(0, -12, 32, 25, 0, 0, Math.PI * 2);
  ctx.stroke();
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2 + Math.PI / 6;
    ctx.beginPath();
    ctx.moveTo(Math.cos(a) * 32, -12 + Math.sin(a) * 25);
    ctx.lineTo(Math.cos(a) * 45, -12 + Math.sin(a) * 37);
    ctx.stroke();
  }
  ctx.fillStyle = 'rgba(34,44,30,0.92)';
  ctx.beginPath();
  ctx.roundRect(-11, 15, 22, 15, 4);
  ctx.fill();
  ctx.strokeStyle = 'rgba(226,204,148,0.9)';
  ctx.lineWidth = 1.4;
  ctx.stroke();
  ctx.fillStyle = 'rgba(244,222,164,0.95)';
  ctx.font = '700 10px serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('镇', 0, 22.5);
  if (ratio < 0.33) {
    ctx.strokeStyle = 'rgba(24,18,12,0.85)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-30, 8);
    ctx.lineTo(-22, 0);
    ctx.lineTo(-28, -12);
    ctx.moveTo(28, -18);
    ctx.lineTo(20, -6);
    ctx.lineTo(27, 6);
    ctx.stroke();
  }
  ctx.restore();
}

export function shellPlant(ctx, t, bob) {
  ctx.save();
  ctx.translate(0, bob * 0.3);
  drawShell(ctx, { hp: 1, maxHp: 1, pulse: 0 }, t);
  ctx.restore();
}

export function catPlant(ctx, t, bob, opt) {
  ctx.save();
  ctx.translate(0, bob * 0.5);
  ctx.fillStyle = '#3a2a20';
  ctx.beginPath();
  ctx.ellipse(0, 28, 22, 6, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#5f3b27';
  ctx.lineWidth = 7;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(-4, 24);
  ctx.quadraticCurveTo(-20, 2, -12, -20);
  ctx.quadraticCurveTo(-5, -38, 8, -42);
  ctx.stroke();
  ctx.strokeStyle = '#d98a3e';
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(-4, 24);
  ctx.quadraticCurveTo(-18, 2, -10, -18);
  ctx.quadraticCurveTo(-4, -33, 8, -38);
  ctx.stroke();
  ctx.fillStyle = '#d98a3e';
  ctx.beginPath();
  ctx.moveTo(2, -42);
  ctx.lineTo(-7, -54);
  ctx.lineTo(4, -50);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(10, -41);
  ctx.lineTo(19, -52);
  ctx.lineTo(15, -40);
  ctx.closePath();
  ctx.fill();
  const glow = 0.55 + Math.sin(t * 4.5) * 0.15;
  const g = ctx.createRadialGradient(10, -45, 1, 10, -45, 20);
  g.addColorStop(0, `rgba(255,230,160,${glow})`);
  g.addColorStop(1, 'rgba(255,150,60,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(10, -45, 20, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ffda8a';
  ctx.beginPath();
  ctx.arc(10, -45, 4.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#2a1811';
  ctx.beginPath();
  ctx.arc(-1, -29, 1.6, 0, Math.PI * 2);
  ctx.arc(7, -33, 1.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

export function lobberPlant(ctx, t, bob, opt) {
  const charge = opt.charge || 0;
  ctx.save();
  ctx.translate(0, bob * 0.4);
  ctx.fillStyle = '#4a2e1e';
  ctx.beginPath();
  ctx.ellipse(0, 26, 26, 7, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#7a4a28';
  ctx.beginPath();
  ctx.ellipse(0, 18, 22, 8, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#c49a5c';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(0, 17, 22, 8, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = '#f4ead2';
  ctx.beginPath();
  ctx.arc(0, -8, 17, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#b79a6a';
  ctx.lineWidth = 1.6;
  ctx.stroke();
  ctx.fillStyle = '#2a1811';
  ctx.beginPath();
  ctx.arc(-6, -10, 1.8, 0, Math.PI * 2);
  ctx.arc(6, -10, 1.8, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#c96a52';
  ctx.beginPath();
  ctx.arc(0, -13 - charge, 1.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#8a5a38';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-12, 2);
  ctx.quadraticCurveTo(-22, -6 - charge * 8, -18, -16 - charge * 8);
  ctx.stroke();
  ctx.fillStyle = '#f4ead2';
  ctx.beginPath();
  ctx.arc(-18, -18 - charge * 8, 4, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(210,190,150,0.7)';
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.moveTo(12, 2);
  ctx.quadraticCurveTo(22, -4 - charge * 6, 18, -12 - charge * 6);
  ctx.stroke();
  ctx.restore();
}

export function torchPlant(ctx, t, bob, opt) {
  const pulse = opt.pulse || 0;
  ctx.save();
  ctx.translate(0, bob * 0.3);
  const g = ctx.createRadialGradient(0, -20, 3, 0, -20, 42);
  g.addColorStop(0, `rgba(255,190,90,${0.35 + pulse * 0.3})`);
  g.addColorStop(1, 'rgba(255,110,40,0)');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(0, -20, 42, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#3a2a20';
  ctx.beginPath();
  ctx.ellipse(0, 28, 22, 5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#8a5a30';
  ctx.beginPath();
  ctx.moveTo(-20, 8);
  ctx.lineTo(-14, 26);
  ctx.lineTo(14, 26);
  ctx.lineTo(20, 8);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#b98442';
  ctx.beginPath();
  ctx.ellipse(0, 8, 21, 7, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#3a2418';
  ctx.beginPath();
  ctx.ellipse(0, 8, 15, 4.5, 0, 0, Math.PI * 2);
  ctx.fill();
  for (let i = 0; i < 5; i++) {
    const a = t * 2.2 + i * 1.7;
    const h = 26 + Math.sin(t * 5 + i) * 8 + pulse * 10;
    ctx.fillStyle = i % 2 ? '#ffca6a' : '#ff8a3c';
    ctx.beginPath();
    ctx.moveTo(Math.cos(a) * 8, 6);
    ctx.quadraticCurveTo(Math.cos(a) * 13 + Math.sin(t * 4 + i) * 3, -h * 0.5, Math.sin(a) * 6, -h);
    ctx.quadraticCurveTo(Math.cos(a) * 3, -h * 0.4, Math.cos(a) * 8, 6);
    ctx.fill();
  }
  ctx.fillStyle = '#ffe7ae';
  ctx.beginPath();
  ctx.arc(0, -18, 3.5 + pulse * 2, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

export function starPlant(ctx, t, bob, opt) {
  ctx.save();
  ctx.translate(0, bob * 0.4);
  ctx.fillStyle = '#3a2a20';
  ctx.beginPath();
  ctx.ellipse(0, 28, 18, 5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#6b4a2c';
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(0, 24);
  ctx.lineTo(0, -20);
  ctx.stroke();
  const cx = 0;
  const cy = -40;
  const glow = ctx.createRadialGradient(cx, cy, 2, cx, cy, 34);
  glow.addColorStop(0, 'rgba(255,225,140,0.5)');
  glow.addColorStop(1, 'rgba(255,180,70,0)');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(cx, cy, 34, 0, Math.PI * 2);
  ctx.fill();
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(t * 0.8);
  ctx.fillStyle = '#f0d48a';
  ctx.strokeStyle = '#9a6b2c';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2 - Math.PI / 2;
    const r = i % 2 === 0 ? 25 : 11;
    const px = Math.cos(a) * r;
    const py = Math.sin(a) * r;
    if (i === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  }
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#c8402f';
  ctx.beginPath();
  ctx.arc(0, 0, 6, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#ffe9b0';
  ctx.beginPath();
  ctx.arc(0, 0, 2.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
  ctx.fillStyle = 'rgba(255,220,150,0.45)';
  for (let i = 0; i < 3; i++) {
    const a = t * 1.7 + i * 2.1;
    ctx.beginPath();
    ctx.arc(Math.cos(a) * 20, cy + Math.sin(a) * 12, 1.8, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

export function needlePlant(ctx, t, bob, opt) {
  const charge = opt.charge || 0;
  ctx.save();
  ctx.translate(0, bob * 0.3);
  ctx.fillStyle = '#2a1e18';
  ctx.beginPath();
  ctx.ellipse(0, 28, 18, 5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#6d6255';
  ctx.beginPath();
  ctx.ellipse(0, 22, 15, 5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(230,220,190,0.55)';
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.moveTo(-9, 22);
  ctx.quadraticCurveTo(-16, 4, -10, -12);
  ctx.quadraticCurveTo(-6, -22, 0, -30);
  ctx.stroke();
  ctx.strokeStyle = '#d8d2c0';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(0, 20);
  ctx.lineTo(0, -42);
  ctx.stroke();
  ctx.fillStyle = '#f4ead2';
  ctx.beginPath();
  ctx.moveTo(0, -52);
  ctx.lineTo(-4, -40);
  ctx.lineTo(4, -40);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = 'rgba(230,215,170,0.7)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.ellipse(0, 4, 5, 2.5, 0, 0, Math.PI * 2);
  ctx.stroke();
  if (charge > 0.2) {
    ctx.fillStyle = `rgba(255,240,190,${charge * 0.8})`;
    ctx.beginPath();
    ctx.arc(0, -46, 2 + charge * 3, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

export function judgePlant(ctx, t, bob, opt) {
  const charge = opt.charge || 0;
  ctx.save();
  ctx.translate(0, bob * 0.35);
  ctx.fillStyle = 'rgba(0,0,0,0.28)';
  ctx.beginPath();
  ctx.ellipse(0, 29, 24, 6, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#4b2a20';
  ctx.fillRect(-20, 18, 6, 12);
  ctx.fillRect(14, 18, 6, 12);
  ctx.fillStyle = '#a83a2b';
  ctx.strokeStyle = '#3a1d16';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.roundRect(-22, -30, 44, 52, 5);
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = 'rgba(226,192,122,0.6)';
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  ctx.roundRect(-18, -26, 36, 44, 4);
  ctx.stroke();
  ctx.fillStyle = '#e8d5b0';
  ctx.beginPath();
  ctx.ellipse(0, 0, 15, 18, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#2a1811';
  ctx.beginPath();
  ctx.moveTo(-16, -14);
  ctx.lineTo(16, -14);
  ctx.lineTo(10, -24);
  ctx.lineTo(-10, -24);
  ctx.closePath();
  ctx.fill();
  ctx.fillRect(-15, -16, 30, 4);
  ctx.strokeStyle = '#2a1811';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-10, -4);
  ctx.lineTo(-3, -6);
  ctx.moveTo(3, -6);
  ctx.lineTo(10, -4);
  ctx.stroke();
  ctx.fillStyle = '#2a1811';
  ctx.beginPath();
  ctx.arc(-6, -3, 2, 0, Math.PI * 2);
  ctx.arc(6, -3, 2, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#3a1d16';
  ctx.lineWidth = 2.4;
  ctx.beginPath();
  ctx.moveTo(-7, 8);
  ctx.quadraticCurveTo(0, 16, 7, 8);
  ctx.stroke();
  if (charge > 0.2) {
    ctx.strokeStyle = `rgba(255,220,150,${charge * 0.8})`;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(0, 0, 26 + charge * 5, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();
}

export function drawNewZombie(ctx, type, chomp, opt) {  const hurt = opt.hurt > 0;
  const body = {
    straw: '#8fae8a', stonehat: '#8d9288', bucket: '#7d918e',
    vault: '#a5b58f', artisan: '#d7cdb8', ironjudge: '#6b6f6c'
  }[type] || '#93a992';
  const dark = hurt ? '#c56b4e' : '#24201c';
  ctx.save();
  ctx.fillStyle = body;
  ctx.strokeStyle = dark;
  ctx.lineWidth = 2.2;
  ctx.beginPath();
  if (type === 'artisan') {
    ctx.moveTo(-22, 30);
    ctx.quadraticCurveTo(-26, -8, -16, -24);
    ctx.lineTo(0, -32);
    ctx.lineTo(16, -24);
    ctx.quadraticCurveTo(26, -8, 22, 30);
    ctx.closePath();
  } else if (type === 'ironjudge') {
    ctx.moveTo(-25, 31);
    ctx.quadraticCurveTo(-30, -14, -14, -32);
    ctx.lineTo(0, -38);
    ctx.lineTo(14, -32);
    ctx.quadraticCurveTo(30, -14, 25, 31);
    ctx.closePath();
  } else {
    ctx.moveTo(-18, 30);
    ctx.quadraticCurveTo(-23, -8, -12, -26);
    ctx.quadraticCurveTo(0, -36, 12, -26);
    ctx.quadraticCurveTo(23, -8, 18, 30);
    ctx.closePath();
  }
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = 'rgba(20,16,14,0.9)';
  ctx.beginPath();
  ctx.ellipse(-7, -14, 3.2, 4, 0, 0, Math.PI * 2);
  ctx.ellipse(7, -14, 3.2, 4, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#f0c06a';
  ctx.beginPath();
  ctx.arc(-7, -14, 1.1, 0, Math.PI * 2);
  ctx.arc(7, -14, 1.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#241210';
  ctx.beginPath();
  ctx.ellipse(0, -3 + chomp * 0.5, 5, 3.2 + Math.abs(chomp) * 0.3, 0, 0, Math.PI * 2);
  ctx.fill();
  if (type === 'artisan') {
    ctx.strokeStyle = '#8a6a3e';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-20, 24);
    ctx.lineTo(-20, -34);
    ctx.lineTo(20, -34);
    ctx.lineTo(20, 24);
    ctx.stroke();
    ctx.fillStyle = '#ece0c2';
    for (let i = 0; i < 4; i++) {
      ctx.fillRect(-20 + i * 10, -34 - (i % 2) * 5, 8, 12);
    }
  } else if (type === 'vault') {
    ctx.strokeStyle = '#9a7444';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(18, 28);
    ctx.lineTo(34, -54);
    ctx.stroke();
    ctx.strokeStyle = '#d8c49a';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(18, 28);
    ctx.lineTo(20, -8);
    ctx.stroke();
  }
  ctx.restore();
}
