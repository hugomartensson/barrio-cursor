function formatDay(d) {
  return d.getDate()
}
function formatMonth(d) {
  return d.toLocaleDateString('en-US', { month: 'short' })
}
function formatWeekday(d) {
  return d.toLocaleDateString('en-US', { weekday: 'short' })
}

export default function PortalEventCard({ event }) {
  const { title, categoryLabel, startTime, address, hostName, hostInitial, isLive } = event
  const d = new Date(startTime)

  return (
    <article
      style={{
        display: 'flex',
        alignItems: 'stretch',
        borderRadius: 'var(--portal-radius)',
        overflow: 'hidden',
        border: `1px solid ${isLive ? 'rgba(37, 99, 235, 0.4)' : 'var(--portal-border)'}`,
        boxShadow: 'var(--portal-shadow-card-1), var(--portal-shadow-card-2)',
        background: 'var(--portal-card)',
      }}
    >
      {/* Date sidebar */}
      <div
        style={{
          width: 'var(--portal-date-sidebar-width)',
          background: 'var(--portal-primary)',
          padding: '12px 8px 12px 8px',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 4,
          flexShrink: 0,
        }}
      >
        <span
          style={{
            fontSize: 'var(--portal-section-label-size)',
            fontWeight: 600,
            color: 'rgba(255,255,255,0.9)',
          }}
        >
          {formatWeekday(d)}
        </span>
        <span
          style={{
            fontFamily: 'var(--portal-font-display)',
            fontSize: 'var(--portal-display-28)',
            fontWeight: 600,
            color: 'var(--portal-primary-foreground)',
            lineHeight: 1.1,
          }}
        >
          {formatDay(d)}
        </span>
        <span
          style={{
            fontSize: 'var(--portal-section-label-size)',
            fontWeight: 600,
            color: 'rgba(255,255,255,0.9)',
          }}
        >
          {formatMonth(d)}
        </span>
      </div>

      {/* Card body */}
      <div
        style={{
          flex: 1,
          padding: 12,
          minWidth: 0,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            marginBottom: 8,
          }}
        >
          <span
            className="portal-section-label"
            style={{
              fontSize: 'var(--portal-section-label-size)',
              letterSpacing: '0.18em',
              color: 'var(--portal-muted-foreground)',
            }}
          >
            {categoryLabel}
          </span>
          {isLive && (
            <span
              style={{
                fontSize: 'var(--portal-label-semibold-size)',
                fontWeight: 600,
                color: 'var(--portal-primary-foreground)',
                background: 'var(--portal-live)',
                padding: '4px 8px',
                borderRadius: 9999,
              }}
            >
              NOW
            </span>
          )}
          <span style={{ marginLeft: 'auto' }}>♡</span>
        </div>

        <h3
          style={{
            fontFamily: 'var(--portal-font-display)',
            fontSize: 'var(--portal-display-28)',
            fontWeight: 600,
            color: 'var(--portal-foreground)',
            margin: '0 0 8px 0',
            lineHeight: 1.2,
          }}
        >
          {title}
        </h3>

        <div
          style={{
            fontSize: 'var(--portal-metadata-size)',
            color: 'var(--portal-muted-foreground)',
            marginBottom: 4,
          }}
        >
          {d.toLocaleDateString()} · {d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
        </div>
        <div
          style={{
            fontSize: 'var(--portal-metadata-size)',
            color: 'var(--portal-muted-foreground)',
            marginBottom: 8,
            display: 'flex',
            alignItems: 'center',
            gap: 4,
          }}
        >
          📍 {address}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
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
            {hostInitial}
          </span>
          <span style={{ fontSize: 'var(--portal-metadata-size)', color: 'var(--portal-accent)' }}>
            @{hostName?.replace(/\s/g, '').toLowerCase() ?? 'host'}
          </span>
        </div>
      </div>
    </article>
  )
}
