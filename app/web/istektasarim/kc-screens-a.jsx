// kc-screens-a.jsx — Onboarding, Home, Matching
// Exports: KCOnboarding, KCHome, KCMatching

// ── ONBOARDING ──────────────────────────────────────────────
function KCOnboarding({ ctx }) {
  const tiles = [KC_USERS[0], KC_USERS[1], KC_USERS[3], KC_USERS[4]];
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', background: 'var(--kc-bg)',
      display: 'flex', flexDirection: 'column' }}>
      {/* aurora */}
      <div style={{ position: 'absolute', width: 360, height: 360, top: -120, right: -110, borderRadius: '50%',
        background: 'var(--kc-accent)', filter: 'blur(90px)', opacity: 0.4 }} />
      <div style={{ position: 'absolute', width: 320, height: 320, top: 40, left: -120, borderRadius: '50%',
        background: 'var(--kc-accent2)', filter: 'blur(90px)', opacity: 0.35 }} />

      {/* floating collage */}
      <div style={{ position: 'relative', flex: 1, marginTop: 64 }}>
        {[
          { u: tiles[0], top: 40,  left: 28,  w: 116, h: 152, r: -7 },
          { u: tiles[1], top: 22,  left: 178, w: 132, h: 168, r: 6 },
          { u: tiles[2], top: 214, left: 40,  w: 130, h: 162, r: 5 },
          { u: tiles[3], top: 200, left: 196, w: 120, h: 152, r: -6 },
        ].map((p, i) => (
          <div key={i} style={{ position: 'absolute', top: p.top, left: p.left, width: p.w, height: p.h,
            borderRadius: 22, overflow: 'hidden', transform: `rotate(${p.r}deg)`,
            boxShadow: '0 18px 40px rgba(0,0,0,0.5)', border: '2px solid rgba(255,255,255,0.1)',
            animation: `kcFloat ${4 + i*0.6}s ease-in-out ${i*0.3}s infinite alternate` }}>
            <KCVideoFeed user={p.u} label={`${p.u.name}, ${p.u.age}`} />
            <span style={{ position: 'absolute', top: 8, right: 8, width: 8, height: 8, borderRadius: '50%',
              background: '#2BE0A6', boxShadow: '0 0 8px #2BE0A6' }} />
          </div>
        ))}
      </div>

      {/* copy + CTA */}
      <div style={{ position: 'relative', padding: '0 26px 40px', textAlign: 'center' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '6px 13px', borderRadius: 999,
          background: 'var(--kc-surface2)', border: '1px solid var(--kc-border)', marginBottom: 18 }}>
          <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#2BE0A6', boxShadow: '0 0 7px #2BE0A6' }} />
          <span style={{ fontFamily: 'Manrope, sans-serif', fontWeight: 600, fontSize: 12.5, color: 'var(--kc-text)' }}>
            şu an <b>{kcNum(48213)}</b> kişi çevrimiçi
          </span>
        </div>
        <h1 style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 33, lineHeight: 1.08,
          color: 'var(--kc-text)', margin: '0 0 10px', letterSpacing: -0.5, textWrap: 'balance' }}>
          Dünyayla<br/>göz göze gel
        </h1>
        <p style={{ fontFamily: 'Manrope, sans-serif', fontSize: 15, lineHeight: 1.45, color: 'var(--kc-muted)',
          margin: '0 0 22px', maxWidth: 300, marginInline: 'auto' }}>
          Saniyeler içinde yeni biriyle görüntülü sohbet et. Anlık çeviriyle dil engeli yok.
        </p>
        <KCButton icon="video" onClick={() => ctx.nav('home')}>Hemen başla</KCButton>
        <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
          <KCButton variant="ghost" size="md" onClick={() => ctx.nav('home')}> Apple</KCButton>
          <KCButton variant="ghost" size="md" onClick={() => ctx.nav('home')}>G Google</KCButton>
        </div>
        <p style={{ fontFamily: 'Manrope, sans-serif', fontSize: 11.5, color: 'var(--kc-muted)', marginTop: 18, opacity: 0.7 }}>
          Devam ederek <b style={{ opacity: 0.9 }}>Kullanım Koşulları</b> ve <b style={{ opacity: 0.9 }}>Gizlilik</b> politikasını kabul edersin.
        </p>
      </div>
    </div>
  );
}

// ── HOME ────────────────────────────────────────────────────
function KCHome({ ctx }) {
  const [sheet, setSheet] = React.useState(null); // 'gender' | 'country' | 'lang'
  const f = ctx.filters;
  const genderLabel = { all: 'Herkes', k: 'Kadın', e: 'Erkek' }[f.gender];
  const countryLabel = f.country === 'all' ? 'Tüm dünya' : f.country;

  const startHint = {
    buton: 'Rastgele biriyle anında bağlan',
    kaydir: 'Başlamak için yukarı kaydır',
    otomatik: 'Otomatik eşleşme — sırada kim varsa',
  }[ctx.matchFlow];

  // swipe-up on hero
  const startY = React.useRef(null);
  const onDown = e => { startY.current = (e.touches ? e.touches[0] : e).clientY; };
  const onUp = e => {
    if (startY.current == null) return;
    const y = (e.changedTouches ? e.changedTouches[0] : e).clientY;
    if (ctx.matchFlow === 'kaydir' && startY.current - y > 50) ctx.startMatch();
    startY.current = null;
  };

  return (
    <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
      paddingTop: 54, background: 'var(--kc-bg)' }}>
      {/* header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '6px 18px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
          <KCAvatar user={KC_ME} size={42} ring onClick={() => ctx.nav('profile')} />
          <div>
            <div style={{ fontFamily: 'Manrope, sans-serif', fontSize: 12.5, color: 'var(--kc-muted)', fontWeight: 600 }}>İyi akşamlar 👋</div>
            <div style={{ fontFamily: 'Sora, sans-serif', fontSize: 17, fontWeight: 700, color: 'var(--kc-text)' }}>{KC_ME.name}</div>
          </div>
        </div>
        <button onClick={() => ctx.nav('store')} style={{ display: 'flex', alignItems: 'center', gap: 7,
          height: 40, padding: '0 7px 0 13px', borderRadius: 999, border: '1px solid var(--kc-border)',
          background: 'var(--kc-surface2)', cursor: 'pointer', WebkitTapHighlightColor: 'transparent' }}>
          <KCDiamond size={17} />
          <span style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 14.5, color: 'var(--kc-text)' }}>{kcNum(ctx.coins)}</span>
          <span style={{ width: 26, height: 26, borderRadius: '50%', background: 'var(--kc-grad)', display: 'flex',
            alignItems: 'center', justifyContent: 'center' }}><KCIcon name="plus" size={15} color="#fff" stroke={2.6} /></span>
        </button>
      </div>

      {/* filters */}
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '2px 18px 14px', scrollbarWidth: 'none' }}>
        <KCChip icon="sliders" onClick={() => setSheet('gender')} active={f.gender !== 'all'}>{genderLabel}</KCChip>
        <KCChip icon="globe" onClick={() => setSheet('country')} active={f.country !== 'all'}>{countryLabel}</KCChip>
        <KCChip icon="chat" onClick={() => setSheet('lang')}>Çeviri: {f.lang}</KCChip>
      </div>

      {/* hero self-cam */}
      <div style={{ flex: 1, position: 'relative', margin: '0 18px', borderRadius: 'var(--kc-radius-lg)',
        overflow: 'hidden', border: '1px solid var(--kc-border)' }}
        onMouseDown={onDown} onMouseUp={onUp} onTouchStart={onDown} onTouchEnd={onUp}>
        <KCVideoFeed user={KC_ME} self dim />
        {/* online count */}
        <div style={{ position: 'absolute', top: 12, left: 12, display: 'flex', alignItems: 'center', gap: 7,
          padding: '7px 12px', borderRadius: 999, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(8px)',
          border: '1px solid rgba(255,255,255,0.12)' }}>
          <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#2BE0A6', boxShadow: '0 0 7px #2BE0A6' }} />
          <span style={{ fontFamily: 'Manrope, sans-serif', fontWeight: 700, fontSize: 12.5, color: '#fff' }}>{kcNum(48213)} çevrimiçi</span>
        </div>
        {/* self controls */}
        <div style={{ position: 'absolute', top: 12, right: 12, display: 'flex', flexDirection: 'column', gap: 9 }}>
          <button style={selfCtrlStyle} onClick={() => ctx.toast('Kamera çevrildi')}><KCIcon name="flip" size={20} color="#fff" /></button>
          <button style={selfCtrlStyle} onClick={() => ctx.toast('Güzelleştirme açık ✨')}><KCIcon name="sparkle" size={20} color="#fff" /></button>
        </div>
        {/* swipe hint for kaydir */}
        {ctx.matchFlow === 'kaydir' && (
          <div style={{ position: 'absolute', left: 0, right: 0, bottom: 18, display: 'flex', flexDirection: 'column',
            alignItems: 'center', gap: 2, pointerEvents: 'none' }}>
            <KCIcon name="chevronUp" size={26} color="rgba(255,255,255,0.9)" style={{ animation: 'kcBob 1.4s ease-in-out infinite' }} />
            <span style={{ fontFamily: 'Manrope, sans-serif', fontWeight: 700, fontSize: 13, color: '#fff', textShadow: '0 2px 8px rgba(0,0,0,0.5)' }}>Yukarı kaydır</span>
          </div>
        )}
      </div>

      {/* start CTA */}
      <div style={{ padding: '16px 18px 116px' }}>
        <p style={{ textAlign: 'center', fontFamily: 'Manrope, sans-serif', fontSize: 13, color: 'var(--kc-muted)',
          fontWeight: 600, margin: '0 0 12px' }}>{startHint}</p>
        {ctx.matchFlow === 'otomatik' ? (
          <KCButton icon="bolt" onClick={ctx.startMatch}>Otomatik eşleşmeyi başlat</KCButton>
        ) : (
          <KCButton icon="video" onClick={ctx.startMatch}>Eşleş</KCButton>
        )}
      </div>

      {/* sheets */}
      <KCSheet open={sheet === 'gender'} onClose={() => setSheet(null)} title="Kiminle eşleşmek istersin?">
        {[['all','Herkes'],['k','Kadınlar'],['e','Erkekler']].map(([v, l]) => (
          <SheetOption key={v} label={l} selected={f.gender === v} locked={v !== 'all'}
            onClick={() => { if (v !== 'all') { ctx.toast('Cinsiyet filtresi VIP özelliğidir'); ctx.nav('store'); setSheet(null); return; } ctx.setFilters({ ...f, gender: v }); setSheet(null); }} />
        ))}
        <p style={{ fontFamily: 'Manrope, sans-serif', fontSize: 12.5, color: 'var(--kc-muted)', marginTop: 6, textAlign: 'center' }}>
          Cinsiyet filtresi <b style={{ color: 'var(--kc-accent)' }}>VIP</b> ile açılır.
        </p>
      </KCSheet>
      <KCSheet open={sheet === 'country'} onClose={() => setSheet(null)} title="Bölge seç">
        {[['all','Tüm dünya'],['Avrupa','Avrupa'],['Asya','Asya'],['Amerika','Amerika']].map(([v, l]) => (
          <SheetOption key={v} label={l} selected={f.country === v}
            onClick={() => { ctx.setFilters({ ...f, country: v }); setSheet(null); }} />
        ))}
      </KCSheet>
      <KCSheet open={sheet === 'lang'} onClose={() => setSheet(null)} title="Çeviri dili">
        {['TR','EN','ES','DE'].map(v => (
          <SheetOption key={v} label={{ TR:'Türkçe', EN:'İngilizce', ES:'İspanyolca', DE:'Almanca' }[v]} selected={f.lang === v}
            onClick={() => { ctx.setFilters({ ...f, lang: v }); setSheet(null); }} />
        ))}
        <p style={{ fontFamily: 'Manrope, sans-serif', fontSize: 12.5, color: 'var(--kc-muted)', marginTop: 6, textAlign: 'center' }}>
          Karşı tarafın konuştuğu dil bu dile anlık çevrilir.
        </p>
      </KCSheet>
    </div>
  );
}

const selfCtrlStyle = {
  width: 40, height: 40, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.18)',
  background: 'rgba(0,0,0,0.35)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center',
  justifyContent: 'center', cursor: 'pointer', WebkitTapHighlightColor: 'transparent',
};

function SheetOption({ label, selected, onClick, locked }) {
  return (
    <button onClick={onClick} style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%',
      height: 54, padding: '0 18px', marginBottom: 8, borderRadius: 16, cursor: 'pointer',
      background: selected ? 'var(--kc-accent-soft)' : 'var(--kc-surface2)',
      border: selected ? '1px solid var(--kc-accent)' : '1px solid var(--kc-border)',
      WebkitTapHighlightColor: 'transparent',
    }}>
      <span style={{ display: 'flex', alignItems: 'center', gap: 9, fontFamily: 'Manrope, sans-serif', fontWeight: 600,
        fontSize: 15.5, color: 'var(--kc-text)' }}>
        {label}{locked && <KCIcon name="lock" size={15} color="var(--kc-accent)" />}
      </span>
      {selected ? <KCIcon name="check" size={20} color="var(--kc-accent)" stroke={2.6} />
        : <span style={{ width: 20, height: 20, borderRadius: '50%', border: '2px solid var(--kc-border)' }} />}
    </button>
  );
}

// ── MATCHING ────────────────────────────────────────────────
function KCMatching({ ctx }) {
  const [idx, setIdx] = React.useState(0);
  React.useEffect(() => {
    const t = setInterval(() => setIdx(i => (i + 1) % KC_USERS.length), 420);
    return () => clearInterval(t);
  }, []);
  const f = ctx.filters;
  const genderLabel = { all: 'Herkes', k: 'Kadın', e: 'Erkek' }[f.gender];

  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      <KCVideoFeed user={KC_ME} self dim style={{ position: 'absolute', inset: 0 }} />
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(8,8,12,0.62)', backdropFilter: 'blur(4px)' }} />

      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center',
        justifyContent: 'center', padding: '0 30px', textAlign: 'center' }}>
        {/* radar */}
        <div style={{ position: 'relative', width: 200, height: 200, marginBottom: 34, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {[0,1,2].map(i => (
            <span key={i} style={{ position: 'absolute', inset: 0, borderRadius: '50%', border: '2px solid var(--kc-accent)',
              animation: `kcPulse 2.4s ease-out ${i*0.8}s infinite` }} />
          ))}
          <div style={{ width: 96, height: 96, borderRadius: '50%', overflow: 'hidden',
            boxShadow: '0 0 40px -4px var(--kc-accent-sh)', border: '2px solid rgba(255,255,255,0.15)' }}>
            <KCVideoFeed user={KC_USERS[idx]} />
          </div>
        </div>

        <h2 style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 24, color: '#fff', margin: '0 0 8px' }}>
          Eşleşme aranıyor…
        </h2>
        <p style={{ fontFamily: 'Manrope, sans-serif', fontSize: 14.5, color: 'rgba(255,255,255,0.65)', margin: '0 0 22px' }}>
          Sana uygun biri bulunuyor
        </p>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center', marginBottom: 40 }}>
          {[genderLabel, f.country === 'all' ? 'Tüm dünya' : f.country, `Çeviri: ${f.lang}`].map(c => (
            <span key={c} style={{ padding: '7px 13px', borderRadius: 999, background: 'rgba(255,255,255,0.1)',
              border: '1px solid rgba(255,255,255,0.16)', fontFamily: 'Manrope, sans-serif', fontWeight: 600,
              fontSize: 12.5, color: '#fff' }}>{c}</span>
          ))}
        </div>
      </div>

      <div style={{ position: 'absolute', left: 26, right: 26, bottom: 46 }}>
        <KCButton variant="glass" onClick={() => ctx.nav('home')}>Vazgeç</KCButton>
      </div>
    </div>
  );
}

Object.assign(window, { KCOnboarding, KCHome, KCMatching });
