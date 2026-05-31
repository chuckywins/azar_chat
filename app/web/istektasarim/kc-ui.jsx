// kc-ui.jsx — shared kerochat UI atoms
// Exports: KCButton, KCChip, KCTabBar, KCSheet, KCIconBtn, KCToast

// Primary / ghost / danger button
function KCButton({ children, onClick, variant = 'primary', icon, full = true, size = 'lg', style }) {
  const base = {
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 9,
    fontFamily: 'Sora, sans-serif', fontWeight: 600, cursor: 'pointer',
    border: 'none', width: full ? '100%' : 'auto', boxSizing: 'border-box',
    borderRadius: 'var(--kc-radius)', transition: 'transform .12s ease, filter .15s ease',
    WebkitTapHighlightColor: 'transparent',
  };
  const sizes = {
    lg: { height: 58, fontSize: 18, padding: '0 24px' },
    md: { height: 48, fontSize: 16, padding: '0 20px' },
    sm: { height: 40, fontSize: 14, padding: '0 16px' },
  };
  const variants = {
    primary: { background: 'var(--kc-grad)', color: '#fff', boxShadow: '0 10px 30px -8px var(--kc-accent-sh)' },
    ghost:   { background: 'var(--kc-surface2)', color: 'var(--kc-text)', border: '1px solid var(--kc-border)' },
    danger:  { background: 'rgba(255,69,82,0.14)', color: '#FF5862', border: '1px solid rgba(255,69,82,0.3)' },
    glass:   { background: 'rgba(255,255,255,0.1)', color: '#fff', backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)', border: '1px solid rgba(255,255,255,0.18)' },
  };
  return (
    <button onClick={onClick} style={{ ...base, ...sizes[size], ...variants[variant], ...style }}
      onMouseDown={e => e.currentTarget.style.transform = 'scale(0.97)'}
      onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
      onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}>
      {icon && <KCIcon name={icon} size={size === 'lg' ? 22 : 18} stroke={2.2} />}
      {children}
    </button>
  );
}

// Filter / selection chip
function KCChip({ children, active, onClick, icon, style }) {
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, whiteSpace: 'nowrap',
      height: 38, padding: '0 14px', borderRadius: 999, cursor: 'pointer',
      fontFamily: 'Manrope, sans-serif', fontWeight: 600, fontSize: 13.5,
      border: active ? '1px solid transparent' : '1px solid var(--kc-border)',
      background: active ? 'var(--kc-grad)' : 'var(--kc-surface2)',
      color: active ? '#fff' : 'var(--kc-text)',
      boxShadow: active ? '0 6px 18px -8px var(--kc-accent-sh)' : 'none',
      WebkitTapHighlightColor: 'transparent', transition: 'all .15s ease', ...style,
    }}>
      {icon && <KCIcon name={icon} size={15} stroke={2.2} />}
      {children}
    </button>
  );
}

// Circular icon button (video controls)
function KCIconBtn({ icon, onClick, active, danger, accent, size = 56, label, glyph, badge }) {
  let bg = 'rgba(255,255,255,0.13)', col = '#fff', bd = '1px solid rgba(255,255,255,0.16)';
  if (active) { bg = 'rgba(255,255,255,0.92)'; col = '#16161d'; bd = '1px solid transparent'; }
  if (danger) { bg = '#FF454F'; col = '#fff'; bd = '1px solid transparent'; }
  if (accent) { bg = 'var(--kc-grad)'; col = '#fff'; bd = '1px solid transparent'; }
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
      <button onClick={onClick} style={{
        width: size, height: size, borderRadius: '50%', border: bd, background: bg, color: col,
        display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        backdropFilter: 'blur(14px)', WebkitBackdropFilter: 'blur(14px)', position: 'relative',
        boxShadow: accent ? '0 10px 26px -8px var(--kc-accent-sh)' : '0 6px 18px rgba(0,0,0,0.25)',
        WebkitTapHighlightColor: 'transparent', transition: 'transform .12s ease',
      }}
        onMouseDown={e => e.currentTarget.style.transform = 'scale(0.92)'}
        onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
        onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}>
        {glyph ? <span style={{ fontSize: size * 0.46 }}>{glyph}</span> : <KCIcon name={icon} size={size * 0.42} stroke={2.1} />}
        {badge != null && (
          <span style={{ position: 'absolute', top: -2, right: -2, minWidth: 18, height: 18, padding: '0 5px',
            borderRadius: 999, background: '#FF454F', color: '#fff', fontSize: 11, fontWeight: 700,
            fontFamily: 'Manrope, sans-serif', display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: '2px solid rgba(0,0,0,0.4)' }}>{badge}</span>
        )}
      </button>
      {label && <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.8)', fontFamily: 'Manrope, sans-serif', fontWeight: 500 }}>{label}</span>}
    </div>
  );
}

// Bottom sheet modal
function KCSheet({ open, onClose, title, children, accent }) {
  const [mounted, setMounted] = React.useState(open);
  React.useEffect(() => { if (open) setMounted(true); }, [open]);
  if (!mounted) return null;
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 200, display: 'flex', alignItems: 'flex-end' }}>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)',
        backdropFilter: 'blur(2px)', opacity: open ? 1 : 0, transition: 'opacity .25s ease',
      }} onTransitionEnd={() => { if (!open) setMounted(false); }} />
      <div style={{
        position: 'relative', width: '100%', background: 'var(--kc-surface)',
        borderTopLeftRadius: 28, borderTopRightRadius: 28, padding: '12px 20px 34px',
        boxShadow: '0 -20px 60px rgba(0,0,0,0.5)', border: '1px solid var(--kc-border)', borderBottom: 'none',
        transform: open ? 'translateY(0)' : 'translateY(100%)', transition: 'transform .3s cubic-bezier(.32,.72,0,1)',
        maxHeight: '78%', overflowY: 'auto',
      }}>
        <div style={{ width: 40, height: 5, borderRadius: 999, background: 'var(--kc-border)', margin: '0 auto 16px' }} />
        {title && <div style={{ fontFamily: 'Sora, sans-serif', fontWeight: 700, fontSize: 19, color: 'var(--kc-text)', marginBottom: 16 }}>{title}</div>}
        {children}
      </div>
    </div>
  );
}

// Bottom tab bar (glass)
function KCTabBar({ active, onNav }) {
  const tabs = [
    { id: 'home',    icon: 'compass', label: 'Keşfet' },
    { id: 'chats',   icon: 'chat',    label: 'Sohbetler' },
    { id: 'profile', icon: 'user',    label: 'Profil' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 90,
      paddingBottom: 24, paddingTop: 10,
      display: 'flex', justifyContent: 'space-around', alignItems: 'center',
      background: 'linear-gradient(180deg, transparent, var(--kc-bg) 42%)',
    }}>
      <div style={{
        display: 'flex', justifyContent: 'space-around', alignItems: 'center', gap: 4,
        width: 'calc(100% - 32px)', maxWidth: 360, height: 64, padding: '0 12px',
        borderRadius: 999, background: 'var(--kc-tab)', border: '1px solid var(--kc-border)',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        boxShadow: '0 12px 36px rgba(0,0,0,0.4)',
      }}>
        {tabs.map(t => {
          const on = active === t.id;
          return (
            <button key={t.id} onClick={() => onNav(t.id)} style={{
              flex: 1, height: 52, border: 'none', background: 'transparent', cursor: 'pointer',
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 3,
              color: on ? 'var(--kc-text)' : 'var(--kc-muted)', WebkitTapHighlightColor: 'transparent',
            }}>
              <div style={{ position: 'relative' }}>
                {on && <div style={{ position: 'absolute', inset: -8, borderRadius: 999, background: 'var(--kc-accent-soft)' }} />}
                <KCIcon name={t.icon} size={23} stroke={on ? 2.4 : 2} style={{ position: 'relative' }} />
              </div>
              <span style={{ fontFamily: 'Manrope, sans-serif', fontWeight: on ? 700 : 600, fontSize: 10.5, letterSpacing: 0.1 }}>{t.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// Transient toast
function KCToast({ msg }) {
  if (!msg) return null;
  return (
    <div style={{
      position: 'absolute', left: '50%', top: 78, transform: 'translateX(-50%)', zIndex: 300,
      background: 'rgba(20,20,26,0.92)', color: '#fff', padding: '11px 18px', borderRadius: 999,
      fontFamily: 'Manrope, sans-serif', fontWeight: 600, fontSize: 13.5, whiteSpace: 'nowrap',
      border: '1px solid var(--kc-border)', backdropFilter: 'blur(12px)',
      boxShadow: '0 12px 30px rgba(0,0,0,0.4)', animation: 'kcToast .3s ease',
    }}>{msg}</div>
  );
}

Object.assign(window, { KCButton, KCChip, KCTabBar, KCSheet, KCIconBtn, KCToast });
