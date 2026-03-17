export default function SectionHeader({ label, title }) {
  return (
    <div style={{ marginBottom: 4 }}>
      <div
        className="portal-section-label"
        style={{
          fontSize: 'var(--portal-section-label-size)',
          fontWeight: 600,
          letterSpacing: '0.18em',
          color: 'var(--portal-muted-foreground)',
          marginBottom: 4,
        }}
      >
        {label}
      </div>
      <div
        className="portal-display-22"
        style={{
          fontFamily: 'var(--portal-font-display)',
          fontSize: 'var(--portal-display-22)',
          fontWeight: 600,
          color: 'var(--portal-foreground)',
        }}
      >
        {title}
      </div>
    </div>
  )
}
