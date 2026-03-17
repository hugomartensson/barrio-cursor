export default function PortalSpotCard({ spot }) {
  const { name, neighborhood, priceRange, categoryLabel, ownerHandle, ownerInitial } = spot

  return (
    <article
      style={{
        width: 180,
        flexShrink: 0,
        borderRadius: 'var(--portal-radius)',
        overflow: 'hidden',
        border: '1px solid var(--portal-border)',
        boxShadow: 'var(--portal-shadow-card-1), var(--portal-shadow-card-2)',
        background: 'var(--portal-card)',
      }}
    >
      {/* Image area 3:2 */}
      <div
        style={{
          aspectRatio: '3/2',
          background: 'var(--portal-muted)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'var(--portal-muted-foreground)',
          fontSize: 24,
        }}
      >
        🍽️
      </div>

      {/* Metadata block */}
      <div style={{ padding: 10 }}>
        <div
          style={{
            fontSize: 14,
            fontWeight: 600,
            color: 'var(--portal-foreground)',
            marginBottom: 6,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {name}
        </div>
        <div
          style={{
            fontSize: 10,
            color: 'var(--portal-muted-foreground)',
            marginBottom: 6,
            display: 'flex',
            alignItems: 'center',
            gap: 4,
          }}
        >
          📍 {neighborhood} · <span style={{ color: 'var(--portal-primary)', fontWeight: 500 }}>{priceRange}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span
            style={{
              width: 24,
              height: 24,
              borderRadius: '50%',
              background: 'var(--portal-primary)',
              color: 'var(--portal-primary-foreground)',
              fontSize: 10,
              fontWeight: 700,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {ownerInitial}
          </span>
          <span style={{ fontSize: 'var(--portal-metadata-size)', color: 'var(--portal-accent)' }}>
            @{ownerHandle}
          </span>
        </div>
      </div>
    </article>
  )
}
