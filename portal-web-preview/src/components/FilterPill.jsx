export default function FilterPill({ title, icon, isActive, categoryColor, onClick }) {
  const isCategory = categoryColor != null
  const bg = isCategory
    ? isActive
      ? categoryColor
      : `color-mix(in srgb, ${categoryColor} 10%, transparent)`
    : isActive
      ? `linear-gradient(135deg, var(--portal-gradient-primary-start), var(--portal-gradient-primary-end))`
      : 'var(--portal-card)'
  const fg = isCategory
    ? isActive ? '#fff' : 'var(--portal-foreground)'
    : isActive ? 'var(--portal-primary-foreground)' : 'var(--portal-foreground)'

  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '10px 14px',
        background: bg,
        color: fg,
        border: isCategory && isActive ? 'none' : '1px solid var(--portal-border)',
        borderRadius: 9999,
        fontSize: 'var(--portal-label-semibold-size)',
        fontWeight: 600,
        cursor: 'pointer',
        whiteSpace: 'nowrap',
      }}
    >
      {icon && <span style={{ fontSize: 12 }}>{icon}</span>}
      {title}
    </button>
  )
}
