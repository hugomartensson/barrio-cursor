export default function PortalWordmark() {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'baseline',
        gap: 2,
        fontFamily: 'var(--portal-font-display)',
        fontSize: 'var(--portal-wordmark-size)',
        fontWeight: 600,
      }}
    >
      <span style={{ color: 'var(--portal-foreground)' }}>portal</span>
      <span style={{ color: 'var(--portal-primary)' }}>·</span>
    </div>
  )
}
