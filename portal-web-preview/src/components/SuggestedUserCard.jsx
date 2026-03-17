export default function SuggestedUserCard({ user }) {
  const { name, followerCount, initial, accentColor = 'var(--portal-primary)' } = user

  return (
    <div
      style={{
        width: 100,
        flexShrink: 0,
        padding: '16px 12px',
        background: 'var(--portal-card)',
        borderRadius: 'var(--portal-radius)',
        boxShadow: 'var(--portal-shadow-card-1), var(--portal-shadow-card-2)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 12,
      }}
    >
      <div
        style={{
          width: 48,
          height: 48,
          borderRadius: '50%',
          background: accentColor,
          color: 'var(--portal-primary-foreground)',
          fontFamily: 'var(--portal-font-display)',
          fontSize: 'var(--portal-display-22)',
          fontWeight: 600,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {initial}
      </div>
      <div
        style={{
          fontSize: 'var(--portal-label-size)',
          fontWeight: 500,
          color: 'var(--portal-foreground)',
          textAlign: 'center',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
          width: '100%',
        }}
      >
        {name}
      </div>
      <div
        style={{
          fontSize: 'var(--portal-metadata-size)',
          color: 'var(--portal-muted-foreground)',
        }}
      >
        {followerCount}
      </div>
    </div>
  )
}
