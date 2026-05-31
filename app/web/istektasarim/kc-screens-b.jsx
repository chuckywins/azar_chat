// kc-screens-b.jsx — VideoChat, Profile, Store, Chats, Thread
// Exports: KCVideoChat, KCProfile, KCStore, KCChats, KCThread

// ── LIVE VIDEO CHAT ─────────────────────────────────────────
function KCVideoChat({ ctx }) {
  const p = ctx.partner || KC_USERS[0];
  const langKey = KC_LANGMAP[p.country] || 'es';
  const lines = KC_SUBS[langKey], linesTr = KC_SUBS_TR[langKey];
  const [subIdx, setSubIdx] = React.useState(0);
  const [muted, setMuted] = React.useState(false);
  const [liked, setLiked] = React.useState(false);
  const [giftOpen, setGiftOpen] = React.useState(false);
  const [giftFx, setGiftFx] = React.useState(null);
  const [secs, setSecs] = React.useState(0);

  React.useEffect(() => {
    const s = setInterval(() => setSecs(x => x + 1), 1000);
    const t = setInterval(() => setSubIdx(i => (i + 1) % lines.length), 3800);
    return () => { clearInterval(s); clearInterval(t); };
  }, [lines.length]);

  const mmss = `${String(Math.floor(secs/60)).padStart(2,'0')}:${String(secs%60).padStart(2,'0')}`;

  const sendGift = (g) => {
    if (ctx.coins < g.cost) { setGiftOpen(false); ctx.toast('Yeterli coin yok'); setTimeout(() => ctx.nav('store'), 400); return; }
    ctx.addCoins(-g.cost);
    setGiftOpen(false);
    setGiftFx({ glyph: g.glyph, key: Date.now() });
    ctx.toast(`${g.name} gönderildi ${g.glyph}`);
    setTimeout(() => setGiftFx(null), 2200);
  };

  const like = () => {
    if (liked) { setLiked(false); return; }
    setLiked(true);
    ctx.toast(`${p.name} adlı kişiyi beğendin 💖`);
    setTimeout(() => { ctx.toast(`${p.name} de seni beğendi! Artık arkadaşsınız 🎉`); ctx.addFriend(p); }, 1400);
  };

  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', background: '#000' }}>
      <KCVideoFeed user={p} dim style={{ position: 'absolute', inset: 0 }} />

      {/* top bar */}
      <div style={{ position: 'absolute', top: 50, left: 14, right: 14, display: 'flex', alignItems: 'center', justifyContent: 'space-between', zIndex: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '6px 14px 6px 6px', borderRadius: 999,
          background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.12)' }}>
          <KCAvatar user={p} size={34} />
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 14.5, color: '#fff' }}>
              {p.name}, {p.age} <KCFlag code={p.country} size={13} />
              {p.verified && <KCIcon name="shield" size={13} color="#5EC8FF" />}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontFamily: 'Manrope, sans-serif', fontSize: 11, color: 'rgba(255,255,255,0.7)' }}>
              <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#2BE0A6' }} /> {mmss} · {p.city}
            </div>
          </div>
        </div>
        <button onClick={() => ctx.toast('Şikayet alındı, teşekkürler')} style={{ width: 40, height: 40, borderRadius: '50%',
          background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.12)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', WebkitTapHighlightColor: 'transparent' }}>
          <KCIcon name="flag" size={18} color="#fff" />
        </button>
      </div>

      {/* self PiP */}
      <div style={{ position: 'absolute', top: 104, right: 14, width: 96, height: 130, borderRadius: 18, overflow: 'hidden',
        border: '2px solid rgba(255,255,255,0.2)', boxShadow: '0 10px 24px rgba(0,0,0,0.45)', zIndex: 9 }}>
        <KCVideoFeed user={KC_ME} self label="sen" />
        {muted && <div style={{ position: 'absolute', top: 6, left: 6, width: 22, height: 22, borderRadius: '50%',
          background: '#FF454F', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><KCIcon name="micOff" size={13} color="#fff" /></div>}
      </div>

      {/* gift fx */}
      {giftFx && (
        <div key={giftFx.key} style={{ position: 'absolute', left: '50%', bottom: 220, fontSize: 70, zIndex: 30,
          transform: 'translateX(-50%)', animation: 'kcGiftFly 2.1s ease-out forwards', pointerEvents: 'none' }}>{giftFx.glyph}</div>
      )}

      {/* subtitle (live translation) */}
      <div style={{ position: 'absolute', left: 16, right: 16, bottom: 196, zIndex: 8 }}>
        <div key={subIdx} style={{ animation: 'kcFade .4s ease', background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(12px)',
          border: '1px solid rgba(255,255,255,0.12)', borderRadius: 18, padding: '12px 15px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 5 }}>
            <KCIcon name="globe" size={12} color="var(--kc-accent)" />
            <span style={{ fontFamily: 'Manrope, sans-serif', fontWeight: 700, fontSize: 10.5, letterSpacing: 0.3,
              color: 'var(--kc-accent)', textTransform: 'uppercase' }}>Anlık çeviri · {p.lang} → Türkçe</span>
          </div>
          <div style={{ fontFamily: 'Manrope, sans-serif', fontSize: 11.5, color: 'rgba(255,255,255,0.5)', marginBottom: 3, fontStyle: 'italic' }}>“{lines[subIdx]}”</div>
          <div style={{ fontFamily: 'Sora, sans-serif', fontWeight: 600, fontSize: 16, color: '#fff', lineHeight: 1.25 }}>{linesTr[subIdx]}</div>
        </div>
      </div>

      {/* control dock */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 30, zIndex: 12, padding: '0 18px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16, padding: '0 6px' }}>
          <KCIconBtn icon={muted ? 'micOff' : 'mic'} size={52} active={muted} onClick={() => setMuted(m => !m)} label="Mikrofon" />
          <KCIconBtn icon="flip" size={52} onClick={() => ctx.toast('Kamera çevrildi')} label="Kamera" />
          <KCIconBtn icon="heart" size={52} active={liked} onClick={like} label="Beğen" />
          <KCIconBtn icon="gift" size={52} accent onClick={() => setGiftOpen(true)} label="Hediye" />
          <KCIconBtn icon="chat" size={52} onClick={() => { ctx.openChat(p); }} label="Mesaj" />
        </div>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <KCButton icon="next" onClick={ctx.startMatch} style={{ flex: 1 }}>Sonraki</KCButton>
          <KCIconBtn icon="close" size={58} danger onClick={() => ctx.nav('home')} />
        </div>
      </div>

      {/* gift tray */}
      <KCSheet open={giftOpen} onClose={() => setGiftOpen(false)} title="Hediye gönder">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <span style={{ fontFamily: 'Manrope, sans-serif', fontSize: 13, color: 'var(--kc-muted)', fontWeight: 600 }}>Bakiyen</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}><KCDiamond size={16} />
            <b style={{ fontFamily: 'Sora, sans-serif', color: 'var(--kc-text)' }}>{kcNum(ctx.coins)}</b></span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10 }}>
          {KC_GIFTS.map(g => (
            <button key={g.id} onClick={() => sendGift(g)} style={{ background: 'var(--kc-surface2)', border: '1px solid var(--kc-border)',
              borderRadius: 16, padding: '14px 6px 10px', cursor: 'pointer', display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 6, WebkitTapHighlightColor: 'transparent' }}>
              <span style={{ fontSize: 34 }}>{g.glyph}</span>
              <span style={{ fontFamily: 'Manrope, sans-serif', fontWeight: 600, fontSize: 12, color: 'var(--kc-text)' }}>{g.name}</span>
              <span style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '3px 9px', borderRadius: 999,
                background: 'var(--kc-bg)', fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 12, color: 'var(--kc-text)' }}>
                <KCDiamond size={12} /> {g.cost}</span>
            </button>
          ))}
        </div>
      </KCSheet>
    </div>
  );
}

// ── shared dark list ────────────────────────────────────────
function KCRow({ icon, color, label, detail, onClick, danger, last }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 13, width: '100%',
      padding: '13px 16px', background: 'transparent', border: 'none', cursor: 'pointer',
      borderBottom: last ? 'none' : '1px solid var(--kc-border)', WebkitTapHighlightColor: 'transparent', textAlign: 'left' }}>
      <span style={{ width: 32, height: 32, borderRadius: 9, background: color || 'var(--kc-surface2)', flexShrink: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <KCIcon name={icon} size={18} color="#fff" stroke={2.2} /></span>
      <span style={{ flex: 1, fontFamily: 'Manrope, sans-serif', fontWeight: 600, fontSize: 15.5,
        color: danger ? '#FF5862' : 'var(--kc-text)' }}>{label}</span>
      {detail && <span style={{ fontFamily: 'Manrope, sans-serif', fontSize: 13.5, color: 'var(--kc-muted)' }}>{detail}</span>}
      {!danger && <KCIcon name="chevron" size={16} color="var(--kc-muted)" />}
    </button>
  );
}

// ── PROFILE ─────────────────────────────────────────────────
function KCProfile({ ctx }) {
  return (
    <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', paddingTop: 54, paddingBottom: 120, background: 'var(--kc-bg)' }}>
      <div style={{ padding: '0 18px' }}>
        {/* header card */}
        <div style={{ position: 'relative', borderRadius: 'var(--kc-radius-lg)', overflow: 'hidden', padding: '26px 20px 22px',
          background: 'var(--kc-surface)', border: '1px solid var(--kc-border)', textAlign: 'center', marginBottom: 16 }}>
          <div style={{ position: 'absolute', top: -60, left: '50%', transform: 'translateX(-50%)', width: 220, height: 160,
            background: 'var(--kc-grad)', filter: 'blur(70px)', opacity: 0.4 }} />
          <div style={{ position: 'relative' }}>
            <KCAvatar user={KC_ME} size={88} ring style={{ margin: '0 auto 12px' }} />
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7 }}>
              <h2 style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 22, color: 'var(--kc-text)', margin: 0 }}>{KC_ME.name}, {KC_ME.age}</h2>
              <span style={{ display: 'flex', alignItems: 'center', gap: 3, padding: '3px 8px', borderRadius: 999,
                background: 'rgba(94,200,255,0.15)', border: '1px solid rgba(94,200,255,0.3)' }}>
                <KCIcon name="shield" size={13} color="#5EC8FF" />
                <span style={{ fontFamily: 'Manrope, sans-serif', fontWeight: 700, fontSize: 11, color: '#5EC8FF' }}>Onaylı</span></span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5, marginTop: 6,
              fontFamily: 'Manrope, sans-serif', fontSize: 13.5, color: 'var(--kc-muted)' }}>
              <KCFlag code={KC_ME.country} size={14} /> {KC_ME.city}, Türkiye</div>
            <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
              <KCButton variant="ghost" size="md" onClick={() => ctx.toast('Profil düzenleme yakında')}>Profili düzenle</KCButton>
              <KCButton size="md" onClick={() => ctx.nav('store')} icon="diamond">Coin al</KCButton>
            </div>
          </div>
        </div>

        {/* stats */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10, marginBottom: 16 }}>
          {[['1.246','Eşleşme'],['86','Arkadaş'],['4.3K','Beğeni']].map(([n, l]) => (
            <div key={l} style={{ background: 'var(--kc-surface)', border: '1px solid var(--kc-border)', borderRadius: 18,
              padding: '15px 6px', textAlign: 'center' }}>
              <div style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 21, color: 'var(--kc-text)' }}>{n}</div>
              <div style={{ fontFamily: 'Manrope, sans-serif', fontSize: 12, color: 'var(--kc-muted)', fontWeight: 600 }}>{l}</div>
            </div>
          ))}
        </div>

        {/* VIP banner */}
        <button onClick={() => ctx.nav('store')} style={{ position: 'relative', width: '100%', textAlign: 'left',
          border: 'none', cursor: 'pointer', borderRadius: 'var(--kc-radius-lg)', overflow: 'hidden', padding: '18px 18px',
          background: 'var(--kc-grad)', marginBottom: 16, WebkitTapHighlightColor: 'transparent',
          display: 'flex', alignItems: 'center', gap: 14 }}>
          <span style={{ width: 46, height: 46, borderRadius: 14, background: 'rgba(255,255,255,0.2)', display: 'flex',
            alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><KCIcon name="crown" size={26} color="#fff" /></span>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 16.5, color: '#fff' }}>kerochat VIP ol</div>
            <div style={{ fontFamily: 'Manrope, sans-serif', fontSize: 12.5, color: 'rgba(255,255,255,0.85)' }}>Cinsiyet filtresi, sınırsız geçiş, reklamsız</div>
          </div>
          <KCIcon name="chevron" size={20} color="#fff" />
        </button>

        {/* settings */}
        <div style={{ background: 'var(--kc-surface)', border: '1px solid var(--kc-border)', borderRadius: 'var(--kc-radius-lg)', overflow: 'hidden', marginBottom: 14 }}>
          <KCRow icon="sliders" color="#FF5E8A" label="Filtre tercihleri" detail="Herkes" onClick={() => ctx.nav('home')} />
          <KCRow icon="globe" color="#4F7DFF" label="Çeviri dili" detail="Türkçe" onClick={() => ctx.toast('Ayarlar')} />
          <KCRow icon="shield" color="#2BE0A6" label="Doğrulama" detail="Onaylı" onClick={() => ctx.toast('Hesabın onaylı')} />
          <KCRow icon="lock" color="#A78BFA" label="Gizlilik & güvenlik" onClick={() => ctx.toast('Ayarlar')} last />
        </div>
        <div style={{ background: 'var(--kc-surface)', border: '1px solid var(--kc-border)', borderRadius: 'var(--kc-radius-lg)', overflow: 'hidden', marginBottom: 14 }}>
          <KCRow icon="bell" color="#FF9F45" label="Bildirimler" onClick={() => ctx.toast('Ayarlar')} />
          <KCRow icon="user" color="#5EC8FF" label="Engellenenler" onClick={() => ctx.toast('Liste boş')} last />
        </div>
        <div style={{ background: 'var(--kc-surface)', border: '1px solid var(--kc-border)', borderRadius: 'var(--kc-radius-lg)', overflow: 'hidden' }}>
          <KCRow icon="logout" label="Çıkış yap" danger onClick={() => ctx.nav('onboarding')} last />
        </div>
      </div>
    </div>
  );
}

// ── STORE ───────────────────────────────────────────────────
function KCStore({ ctx }) {
  const [sel, setSel] = React.useState('p3');
  const pack = KC_COINPACKS.find(p => p.id === sel);
  const benefits = ['Cinsiyet filtresi', 'Sınırsız geçiş', 'Reklamsız deneyim', 'Profilin öne çıksın', 'Kim beğendi gör'];
  return (
    <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', background: 'var(--kc-bg)' }}>
      <div style={{ position: 'sticky', top: 0, zIndex: 5, paddingTop: 50, paddingBottom: 10, background: 'linear-gradient(180deg, var(--kc-bg) 70%, transparent)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '0 16px' }}>
          <button onClick={() => ctx.nav(ctx.lastTab)} style={{ width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
            background: 'var(--kc-surface2)', border: '1px solid var(--kc-border)', display: 'flex', alignItems: 'center',
            justifyContent: 'center', cursor: 'pointer', WebkitTapHighlightColor: 'transparent' }}>
            <KCIcon name="chevron" size={18} color="var(--kc-text)" style={{ transform: 'scaleX(-1)' }} /></button>
          <h1 style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 24, color: 'var(--kc-text)', margin: 0 }}>Mağaza</h1>
          <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 6, padding: '7px 13px', borderRadius: 999,
            background: 'var(--kc-surface2)', border: '1px solid var(--kc-border)' }}>
            <KCDiamond size={16} /><b style={{ fontFamily: 'Sora, sans-serif', fontSize: 14, color: 'var(--kc-text)' }}>{kcNum(ctx.coins)}</b></div>
        </div>
      </div>

      <div style={{ padding: '6px 18px 40px' }}>
        {/* VIP card */}
        <div style={{ position: 'relative', borderRadius: 'var(--kc-radius-lg)', overflow: 'hidden', padding: '22px 20px',
          background: 'var(--kc-grad)', marginBottom: 24 }}>
          <div style={{ position: 'absolute', top: -40, right: -30, width: 160, height: 160, borderRadius: '50%', background: 'rgba(255,255,255,0.18)', filter: 'blur(30px)' }} />
          <div style={{ position: 'relative' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 14 }}>
              <KCIcon name="crown" size={26} color="#fff" />
              <span style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 21, color: '#fff' }}>kerochat VIP</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '9px 12px', marginBottom: 18 }}>
              {benefits.map(b => (
                <div key={b} style={{ display: 'flex', alignItems: 'center', gap: 7, fontFamily: 'Manrope, sans-serif',
                  fontWeight: 600, fontSize: 13, color: '#fff' }}>
                  <KCIcon name="check" size={15} color="#fff" stroke={2.8} /> {b}</div>
              ))}
            </div>
            <KCButton variant="glass" onClick={() => ctx.toast('VIP ‘ye hoş geldin 👑')}>
              <span>VIP Ol · <b>₺149</b><span style={{ opacity: 0.8, fontWeight: 500 }}>/ay</span></span>
            </KCButton>
          </div>
        </div>

        {/* coin packs */}
        <h3 style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 17, color: 'var(--kc-text)', margin: '0 0 13px' }}>Coin paketleri</h3>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 11, marginBottom: 22 }}>
          {KC_COINPACKS.map(p => {
            const on = sel === p.id;
            return (
              <button key={p.id} onClick={() => setSel(p.id)} style={{ position: 'relative', textAlign: 'center', cursor: 'pointer',
                background: on ? 'var(--kc-accent-soft)' : 'var(--kc-surface)', borderRadius: 18, padding: '20px 10px 16px',
                border: on ? '1.5px solid var(--kc-accent)' : '1px solid var(--kc-border)', WebkitTapHighlightColor: 'transparent' }}>
                {p.popular && <span style={{ position: 'absolute', top: -9, left: '50%', transform: 'translateX(-50%)',
                  padding: '3px 11px', borderRadius: 999, background: 'var(--kc-grad)', color: '#fff',
                  fontFamily: 'Manrope, sans-serif', fontWeight: 700, fontSize: 10, whiteSpace: 'nowrap' }}>EN POPÜLER</span>}
                <KCDiamond size={34} />
                <div style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 22, color: 'var(--kc-text)', marginTop: 6 }}>{kcNum(p.coins)}</div>
                {p.bonus && <div style={{ fontFamily: 'Manrope, sans-serif', fontWeight: 700, fontSize: 12, color: 'var(--kc-accent)' }}>{p.bonus} bonus</div>}
                <div style={{ marginTop: 10, padding: '6px 0', borderRadius: 10, background: 'var(--kc-surface2)',
                  fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 14.5, color: 'var(--kc-text)' }}>{p.price}</div>
              </button>
            );
          })}
        </div>

        {/* earn free */}
        <h3 style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 17, color: 'var(--kc-text)', margin: '0 0 13px' }}>Ücretsiz coin kazan</h3>
        <div style={{ background: 'var(--kc-surface)', border: '1px solid var(--kc-border)', borderRadius: 'var(--kc-radius-lg)', overflow: 'hidden' }}>
          <KCRow icon="users" color="#2BE0A6" label="Arkadaşını davet et" detail="+50" onClick={() => { ctx.addCoins(50); ctx.toast('+50 coin! 🎉'); }} />
          <KCRow icon="bolt" color="#FF9F45" label="Reklam izle" detail="+10" onClick={() => { ctx.addCoins(10); ctx.toast('+10 coin'); }} last />
        </div>
      </div>

      {/* sticky buy */}
      <div style={{ position: 'sticky', bottom: 0, padding: '14px 18px 30px', background: 'linear-gradient(180deg, transparent, var(--kc-bg) 38%)' }}>
        <KCButton icon="diamond" onClick={() => { ctx.addCoins(pack.coins + (pack.bonus ? parseInt(pack.bonus) : 0)); ctx.toast(`${kcNum(pack.coins)} coin yüklendi 💎`); }}>
          {pack.price} · {kcNum(pack.coins)} coin satın al
        </KCButton>
      </div>
    </div>
  );
}

// ── CHATS ───────────────────────────────────────────────────
function KCChats({ ctx }) {
  const [tab, setTab] = React.useState('msg');
  return (
    <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', paddingTop: 54, paddingBottom: 120, background: 'var(--kc-bg)' }}>
      <div style={{ padding: '0 18px' }}>
        <h1 style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 30, color: 'var(--kc-text)', margin: '6px 0 14px', letterSpacing: -0.5 }}>Sohbetler</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9, height: 44, padding: '0 14px', borderRadius: 14,
          background: 'var(--kc-surface2)', border: '1px solid var(--kc-border)', marginBottom: 14 }}>
          <KCIcon name="search" size={18} color="var(--kc-muted)" />
          <input placeholder="Arkadaş ara" style={{ flex: 1, border: 'none', background: 'transparent', outline: 'none',
            fontFamily: 'Manrope, sans-serif', fontSize: 15, color: 'var(--kc-text)' }} />
        </div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
          {[['msg','Mesajlar'],['friends','Arkadaşlar']].map(([v, l]) => (
            <KCChip key={v} active={tab === v} onClick={() => setTab(v)}>{l}</KCChip>
          ))}
        </div>
      </div>

      <div style={{ padding: '4px 10px' }}>
        {KC_CHATS.map(ch => {
          const u = KC_USERS.find(x => x.id === ch.uid);
          return (
            <button key={ch.uid} onClick={() => ctx.openChat(u)} style={{ display: 'flex', alignItems: 'center', gap: 13,
              width: '100%', padding: '11px 12px', background: 'transparent', border: 'none', cursor: 'pointer',
              borderRadius: 16, WebkitTapHighlightColor: 'transparent', textAlign: 'left' }}>
              <KCAvatar user={u} size={54} online={ch.online} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                  <span style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 15.5, color: 'var(--kc-text)' }}>{u.name}</span>
                  <KCFlag code={u.country} size={12} />
                  {u.verified && <KCIcon name="shield" size={12} color="#5EC8FF" />}
                </div>
                <div style={{ fontFamily: 'Manrope, sans-serif', fontSize: 13.5, color: 'var(--kc-muted)', overflow: 'hidden',
                  textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: 2 }}>{ch.last}</div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
                <span style={{ fontFamily: 'Manrope, sans-serif', fontSize: 11.5, color: 'var(--kc-muted)' }}>{ch.time}</span>
                {ch.unread > 0 && <span style={{ minWidth: 20, height: 20, padding: '0 6px', borderRadius: 999, background: 'var(--kc-grad)',
                  color: '#fff', fontFamily: 'Manrope, sans-serif', fontWeight: 700, fontSize: 11.5, display: 'flex',
                  alignItems: 'center', justifyContent: 'center' }}>{ch.unread}</span>}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ── THREAD ──────────────────────────────────────────────────
function KCThread({ ctx }) {
  const p = ctx.chatUser || KC_USERS[0];
  const [msgs, setMsgs] = React.useState([
    { me: false, t: 'Selam! Görüntülü sohbet çok eğlenceliydi 😄' },
    { me: true, t: 'Bence de! Aksanın çok tatlı' },
    { me: false, t: 'Yarın aynı saatte tekrar bağlanalım mı?' },
  ]);
  const [val, setVal] = React.useState('');
  const scroller = React.useRef(null);
  React.useEffect(() => { if (scroller.current) scroller.current.scrollTop = scroller.current.scrollHeight; }, [msgs]);
  const send = () => { if (!val.trim()) return; setMsgs(m => [...m, { me: true, t: val.trim() }]); setVal(''); };

  return (
    <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', background: 'var(--kc-bg)' }}>
      {/* header */}
      <div style={{ paddingTop: 50, paddingBottom: 12, display: 'flex', alignItems: 'center', gap: 11, padding: '50px 14px 12px',
        borderBottom: '1px solid var(--kc-border)', background: 'var(--kc-surface)' }}>
        <button onClick={() => ctx.nav('chats')} style={{ width: 38, height: 38, borderRadius: '50%', flexShrink: 0,
          background: 'transparent', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', WebkitTapHighlightColor: 'transparent' }}>
          <KCIcon name="chevron" size={22} color="var(--kc-text)" style={{ transform: 'scaleX(-1)' }} /></button>
        <KCAvatar user={p} size={40} online />
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 16, color: 'var(--kc-text)' }}>
            {p.name} <KCFlag code={p.country} size={13} /></div>
          <div style={{ fontFamily: 'Manrope, sans-serif', fontSize: 12, color: '#2BE0A6', fontWeight: 600 }}>çevrimiçi</div>
        </div>
        <button onClick={() => { ctx.setPartner(p); ctx.nav('video'); }} style={{ width: 40, height: 40, borderRadius: '50%',
          background: 'var(--kc-grad)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', WebkitTapHighlightColor: 'transparent' }}><KCIcon name="video" size={20} color="#fff" /></button>
      </div>

      {/* messages */}
      <div ref={scroller} style={{ flex: 1, overflowY: 'auto', padding: '18px 16px', display: 'flex', flexDirection: 'column', gap: 9 }}>
        {msgs.map((m, i) => (
          <div key={i} style={{ alignSelf: m.me ? 'flex-end' : 'flex-start', maxWidth: '78%',
            background: m.me ? 'var(--kc-grad)' : 'var(--kc-surface2)', color: m.me ? '#fff' : 'var(--kc-text)',
            padding: '10px 14px', borderRadius: 20, borderBottomRightRadius: m.me ? 6 : 20, borderBottomLeftRadius: m.me ? 20 : 6,
            fontFamily: 'Manrope, sans-serif', fontSize: 14.5, lineHeight: 1.35, border: m.me ? 'none' : '1px solid var(--kc-border)' }}>{m.t}</div>
        ))}
      </div>

      {/* input */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px 30px', borderTop: '1px solid var(--kc-border)', background: 'var(--kc-surface)' }}>
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', height: 46, padding: '0 16px', borderRadius: 999,
          background: 'var(--kc-surface2)', border: '1px solid var(--kc-border)' }}>
          <input value={val} onChange={e => setVal(e.target.value)} onKeyDown={e => e.key === 'Enter' && send()}
            placeholder="Mesaj yaz…" style={{ flex: 1, border: 'none', background: 'transparent', outline: 'none',
            fontFamily: 'Manrope, sans-serif', fontSize: 15, color: 'var(--kc-text)' }} />
        </div>
        <button onClick={send} style={{ width: 46, height: 46, borderRadius: '50%', background: 'var(--kc-grad)', border: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', WebkitTapHighlightColor: 'transparent', flexShrink: 0 }}>
          <KCIcon name="next" size={20} color="#fff" /></button>
      </div>
    </div>
  );
}

Object.assign(window, { KCVideoChat, KCProfile, KCStore, KCChats, KCThread });
