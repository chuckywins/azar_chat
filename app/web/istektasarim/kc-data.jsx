// kc-data.jsx — kerochat design tokens, icons, atoms & mock data
// Exports to window: KC_PALETTES, KC_USERS, KC_CHATS, KC_GIFTS, KC_COINPACKS,
//   KCIcon, KCAvatar, KCVideoFeed, KCDiamond, KCFlag, kcNum

// ── Accent palettes (tweakable) ─────────────────────────────
const KC_PALETTES = {
  'Mercan → Mor': { a: '#FF5E8A', b: '#B15BFF' },
  'Okyanus':      { a: '#22D3EE', b: '#4F7DFF' },
  'Gün batımı':   { a: '#FF9F45', b: '#FF4D6D' },
  'Nane':         { a: '#2BE0A6', b: '#1FB6C9' },
};

// ── Mock people ─────────────────────────────────────────────
const KC_USERS = [
  { id: 'elif', name: 'Elif',  age: 23, city: 'İstanbul',  country: 'TR', g: 'k', c1: '#FF6B9D', c2: '#C44DFF', verified: true,  lang: 'Türkçe' },
  { id: 'mara', name: 'Mara',  age: 25, city: 'Madrid',    country: 'ES', g: 'k', c1: '#FF9F45', c2: '#FF4D6D', verified: true,  lang: 'İspanyolca' },
  { id: 'yuki', name: 'Yuki',  age: 22, city: 'Osaka',     country: 'JP', g: 'k', c1: '#5EC8FF', c2: '#7A5BFF', verified: false, lang: 'Japonca' },
  { id: 'leo',  name: 'Leo',   age: 27, city: 'São Paulo', country: 'BR', g: 'e', c1: '#2BE0A6', c2: '#1F9DC9', verified: true,  lang: 'Portekizce' },
  { id: 'nora', name: 'Nora',  age: 24, city: 'Berlin',    country: 'DE', g: 'k', c1: '#A78BFA', c2: '#5B8DEF', verified: false, lang: 'Almanca' },
  { id: 'aria', name: 'Aria',  age: 21, city: 'Milano',    country: 'IT', g: 'k', c1: '#FF7E5F', c2: '#FEB47B', verified: true,  lang: 'İtalyanca' },
  { id: 'kai',  name: 'Kai',   age: 26, city: 'Seoul',     country: 'KR', g: 'e', c1: '#36D1DC', c2: '#5B86E5', verified: false, lang: 'Korece' },
];

const KC_ME = { id: 'me', name: 'Deniz', age: 24, city: 'İzmir', country: 'TR', c1: '#FF5E8A', c2: '#B15BFF', verified: true };

// Translated subtitle scripts (partner line → shown in Turkish)
const KC_SUBS = {
  es: ['¡Hola! ¿Cómo estás?', 'Me encanta tu acento 😄', '¿De qué parte eres?'],
  jp: ['こんにちは！はじめまして', 'トルコに行ってみたいな', '今日はいい天気だね'],
  br: ['Oi! Tudo bem com você?', 'Adoro conhecer gente nova', 'Que horas são aí?'],
  de: ['Hallo! Wie geht es dir?', 'Schön, dich kennenzulernen', 'Was machst du gerade?'],
  it: ['Ciao! Come stai?', 'Mi piace il tuo sorriso', 'Cosa fai nella vita?'],
};
const KC_SUBS_TR = {
  es: ['Merhaba! Nasılsın?', 'Aksanına bayıldım 😄', 'Nerelisin?'],
  jp: ['Merhaba! Memnun oldum', 'Türkiye’yi görmek isterdim', 'Bugün hava çok güzel'],
  br: ['Selam! İyi misin?', 'Yeni insanlarla tanışmaya bayılırım', 'Orada saat kaç?'],
  de: ['Merhaba! Nasılsın?', 'Tanıştığımıza sevindim', 'Şu an ne yapıyorsun?'],
  it: ['Selam! Nasılsın?', 'Gülüşüne bayıldım', 'Ne iş yapıyorsun?'],
};
const KC_LANGMAP = { ES: 'es', JP: 'jp', BR: 'br', DE: 'de', IT: 'it', KR: 'jp', TR: 'es' };

const KC_GIFTS = [
  { id: 'rose',   name: 'Gül',     glyph: '🌹', cost: 9 },
  { id: 'heart',  name: 'Kalp',    glyph: '💖', cost: 19 },
  { id: 'star',   name: 'Yıldız',  glyph: '⭐', cost: 29 },
  { id: 'crown',  name: 'Taç',     glyph: '👑', cost: 99 },
  { id: 'rocket', name: 'Roket',   glyph: '🚀', cost: 149 },
  { id: 'ring',   name: 'Yüzük',   glyph: '💍', cost: 299 },
];

const KC_COINPACKS = [
  { id: 'p1', coins: 100,   price: '₺29',   bonus: null },
  { id: 'p2', coins: 550,   price: '₺99',   bonus: '+50' },
  { id: 'p3', coins: 1200,  price: '₺199',  bonus: '+200', popular: true },
  { id: 'p4', coins: 3000,  price: '₺449',  bonus: '+750' },
];

const KC_CHATS = [
  { uid: 'elif', last: 'Yarın aynı saatte? 😄',       time: '14:32', unread: 2, online: true },
  { uid: 'mara', last: 'Te mando una foto de Madrid', time: '13:05', unread: 0, online: true },
  { uid: 'leo',  last: 'Sen: haha kesinlikle!',        time: 'Dün',   unread: 0, online: false },
  { uid: 'nora', last: 'Danke! Bis bald 👋',           time: 'Dün',   unread: 0, online: false },
  { uid: 'aria', last: 'Ci sentiamo presto',           time: 'Sal',   unread: 1, online: true },
];

// Country flag (emoji from ISO code)
function KCFlag({ code, size = 16 }) {
  const flag = code ? code.toUpperCase().replace(/./g, c =>
    String.fromCodePoint(127397 + c.charCodeAt(0))) : '';
  return <span style={{ fontSize: size, lineHeight: 1 }}>{flag}</span>;
}

const kcNum = (n) => n.toLocaleString('tr-TR');

// ── Icon set (stroke-based, 24 grid) ────────────────────────
function KCIcon({ name, size = 24, color = 'currentColor', stroke = 2, style, fill = 'none' }) {
  const p = { fill: 'none', stroke: color, strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const paths = {
    video:    <><rect x="2.5" y="6" width="13" height="12" rx="3" {...p}/><path d="M15.5 10.5L21 7.5v9l-5.5-3" {...p}/></>,
    mic:      <><rect x="9" y="2.5" width="6" height="11" rx="3" {...p}/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M8.5 21h7" {...p}/></>,
    micOff:   <><path d="M9 5.2A3 3 0 0 1 15 6v4M15 13.5A3 3 0 0 1 9 12v-1.5" {...p}/><path d="M5.5 11a6.5 6.5 0 0 0 10.2 5.3M18.5 11M12 17.5V21M8.5 21h7M4 3l16 16" {...p}/></>,
    flip:     <><path d="M3 8a8 8 0 0 1 13-3l2 2M21 16a8 8 0 0 1-13 3l-2-2" {...p}/><path d="M18 3v4h-4M6 21v-4h4" {...p}/></>,
    gift:     <><rect x="3.5" y="9" width="17" height="11.5" rx="2" {...p}/><path d="M2.5 9h19M12 9v11.5M12 9c-1.5-3-5.5-3-5.5-.5C6.5 9 9 9 12 9zM12 9c1.5-3 5.5-3 5.5-.5C17.5 9 15 9 12 9z" {...p}/></>,
    heart:    <path d="M12 20s-7-4.5-9.3-9C1 7.5 3 4 6.3 4 9 4 12 6.5 12 6.5S15 4 17.7 4C21 4 23 7.5 21.3 11 19 15.5 12 20 12 20z" fill={fill} stroke={color} strokeWidth={stroke} strokeLinejoin="round"/>,
    chat:     <path d="M4 5h16a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 20 17H9l-4.5 4v-4H4A1.5 1.5 0 0 1 2.5 15.5v-9A1.5 1.5 0 0 1 4 5z" {...p}/>,
    close:    <path d="M5 5l14 14M19 5L5 19" {...p}/>,
    next:     <path d="M5 5l8 7-8 7M14 5l5 7-5 7" {...p}/>,
    user:     <><circle cx="12" cy="8" r="4" {...p}/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7" {...p}/></>,
    users:    <><circle cx="9" cy="8" r="3.3" {...p}/><path d="M3 20c0-3.6 2.7-6 6-6s6 2.4 6 6" {...p}/><path d="M16 6.2A3.3 3.3 0 0 1 18.5 12M16.5 14.4c2.6.5 4.5 2.6 4.5 5.6" {...p}/></>,
    compass:  <><circle cx="12" cy="12" r="9.5" {...p}/><path d="M15.5 8.5l-2 5-5 2 2-5 5-2z" {...p}/></>,
    diamond:  <path d="M5 4h14l3 5-10 12L2 9l3-5zM2 9h20M9 4l-2 5 5 12M15 4l2 5-5 12" {...p}/>,
    crown:    <path d="M3 8l4 4 5-7 5 7 4-4-2 12H5L3 8z" {...p}/>,
    shield:   <><path d="M12 3l8 3v5c0 5-3.4 8.6-8 10-4.6-1.4-8-5-8-10V6l8-3z" {...p}/><path d="M8.5 12l2.5 2.5 4.5-5" {...p}/></>,
    globe:    <><circle cx="12" cy="12" r="9.5" {...p}/><path d="M2.5 12h19M12 2.5c2.8 3 2.8 16 0 19M12 2.5c-2.8 3-2.8 16 0 19" {...p}/></>,
    chevron:  <path d="M9 5l7 7-7 7" {...p}/>,
    chevronUp:<path d="M5 15l7-7 7 7" {...p}/>,
    search:   <><circle cx="11" cy="11" r="7" {...p}/><path d="M16.5 16.5L21 21" {...p}/></>,
    settings: <><circle cx="12" cy="12" r="3.2" {...p}/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5 5l2.2 2.2M16.8 16.8L19 19M19 5l-2.2 2.2M7.2 16.8L5 19" {...p}/></>,
    plus:     <path d="M12 5v14M5 12h14" {...p}/>,
    sliders:  <><path d="M4 8h10M18 8h2M4 16h2M10 16h10" {...p}/><circle cx="16" cy="8" r="2.2" {...p}/><circle cx="8" cy="16" r="2.2" {...p}/></>,
    sparkle:  <path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3z" {...p}/>,
    check:    <path d="M5 12l5 5 9-10" {...p}/>,
    flag:     <path d="M5 21V4M5 4h11l-2 3.5 2 3.5H5" {...p}/>,
    bolt:     <path d="M13 2L4 14h7l-1 8 9-12h-7l1-8z" fill={fill} stroke={color} strokeWidth={stroke} strokeLinejoin="round"/>,
    bell:     <><path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6z" {...p}/><path d="M10.5 19a1.8 1.8 0 0 0 3 0" {...p}/></>,
    lock:     <><rect x="4.5" y="10" width="15" height="10" rx="2.5" {...p}/><path d="M8 10V7a4 4 0 0 1 8 0v3" {...p}/></>,
    logout:   <><path d="M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4" {...p}/><path d="M15 8l4 4-4 4M19 12H9" {...p}/></>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={style} aria-hidden="true">
      {paths[name] || null}
    </svg>
  );
}

// ── Diamond coin glyph ──────────────────────────────────────
function KCDiamond({ size = 16 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
      <defs>
        <linearGradient id="kcdia" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#7FE9FF"/><stop offset="1" stopColor="#4F7DFF"/>
        </linearGradient>
      </defs>
      <path d="M5 4h14l3 5-10 12L2 9l3-5z" fill="url(#kcdia)"/>
      <path d="M5 4l3 5h8l3-5M2 9h20M8 9l4 12M16 9l-4 12" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth="1" strokeLinejoin="round"/>
    </svg>
  );
}

// ── Avatar: gradient monogram disc ──────────────────────────
function KCAvatar({ user, size = 48, ring = false, online = false, style }) {
  const u = user || {};
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0, ...style }}>
      <div style={{
        width: size, height: size, borderRadius: '50%',
        background: `linear-gradient(140deg, ${u.c1 || '#888'}, ${u.c2 || '#555'})`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#fff', fontFamily: 'Sora, sans-serif', fontWeight: 600,
        fontSize: size * 0.4, letterSpacing: 0.3,
        boxShadow: ring ? `0 0 0 ${Math.max(2, size*0.05)}px rgba(255,255,255,0.12)` : 'none',
      }}>{(u.name || '?')[0]}</div>
      {online && (
        <span style={{
          position: 'absolute', right: size*0.02, bottom: size*0.02,
          width: size*0.26, height: size*0.26, borderRadius: '50%',
          background: '#2BE0A6', border: `${Math.max(2,size*0.05)}px solid var(--kc-bg)`,
        }}/>
      )}
    </div>
  );
}

// ── Video feed: simulated live tile ─────────────────────────
function KCVideoFeed({ user, label, self = false, style, children, dim = false }) {
  const u = user || {};
  const c1 = self ? '#3a3a48' : (u.c1 || '#444');
  const c2 = self ? '#16161d' : (u.c2 || '#222');
  return (
    <div style={{
      position: 'relative', overflow: 'hidden', width: '100%', height: '100%',
      background: `radial-gradient(120% 90% at 30% 20%, ${c1}, ${c2} 75%)`,
      ...style,
    }}>
      {/* soft figure */}
      <div style={{
        position: 'absolute', left: '50%', top: '42%', transform: 'translate(-50%,-50%)',
        width: '54%', aspectRatio: '1', borderRadius: '50%',
        background: 'radial-gradient(circle at 40% 35%, rgba(255,255,255,0.22), rgba(255,255,255,0) 62%)',
        filter: 'blur(2px)',
      }}/>
      <div style={{
        position: 'absolute', left: '50%', top: '40%', transform: 'translate(-50%,-50%)',
        fontFamily: 'Sora, sans-serif', fontWeight: 700, color: 'rgba(255,255,255,0.92)',
        fontSize: self ? 22 : 84, textShadow: '0 4px 24px rgba(0,0,0,0.35)',
      }}>{(u.name || '?')[0]}</div>
      {/* scanline texture */}
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.06, mixBlendMode: 'overlay',
        backgroundImage: 'repeating-linear-gradient(0deg, #fff 0 1px, transparent 1px 3px)',
      }}/>
      {dim && <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,0,0,0.35) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0) 55%, rgba(0,0,0,0.55) 100%)' }}/>}
      {label && (
        <div style={{
          position: 'absolute', left: 8, bottom: 8, fontFamily: 'ui-monospace, Menlo, monospace',
          fontSize: 10, letterSpacing: 0.4, color: 'rgba(255,255,255,0.85)',
          background: 'rgba(0,0,0,0.35)', padding: '3px 7px', borderRadius: 6,
          backdropFilter: 'blur(4px)',
        }}>{label}</div>
      )}
      {children}
    </div>
  );
}

Object.assign(window, {
  KC_PALETTES, KC_USERS, KC_ME, KC_SUBS, KC_SUBS_TR, KC_LANGMAP, KC_GIFTS, KC_COINPACKS, KC_CHATS,
  KCIcon, KCAvatar, KCVideoFeed, KCDiamond, KCFlag, kcNum,
});
