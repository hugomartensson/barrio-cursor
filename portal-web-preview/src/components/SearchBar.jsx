export default function SearchBar() {
  return (
    <div
      className="search-bar"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: '12px 16px',
        background: 'var(--portal-secondary)',
        borderRadius: 12,
        border: '1px solid var(--portal-border)',
        margin: '0 var(--portal-page-padding)',
        marginBottom: 8,
      }}
    >
      <span aria-hidden style={{ color: 'var(--portal-muted-foreground)', fontSize: 16 }}>
        🔍
      </span>
      <span
        style={{
          fontSize: 'var(--portal-metadata-size)',
          color: 'var(--portal-muted-foreground)',
        }}
      >
        Search spots, events, people...
      </span>
    </div>
  )
}
