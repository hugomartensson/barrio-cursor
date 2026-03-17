import FilterPill from '../components/FilterPill'
import { useDiscoverFilters } from '../context/DiscoverFiltersContext'
import { TIME_PILLS, CATEGORY_PILLS } from '../data/mock'

export default function Map() {
  const { timeFilter, setTimeFilter, categories, toggleCategory, locationLabel } = useDiscoverFilters()

  return (
    <div
      style={{
        flex: 1,
        background: 'var(--portal-muted)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: 400,
        position: 'relative',
      }}
    >
      {/* Overlay: location pill + Filter/Recenter + time/category pills (same as Discover) */}
      <div
        style={{
          position: 'absolute',
          top: 12,
          left: 'var(--portal-page-padding)',
          right: 'var(--portal-page-padding)',
          display: 'flex',
          flexDirection: 'column',
          gap: 0,
          background: 'rgba(255,255,255,0.6)',
          backdropFilter: 'blur(12px)',
          borderRadius: 12,
          padding: 12,
          paddingBottom: 8,
        }}
      >
        {/* Top row: location pill (left) + Filter + recenter (right) */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 'var(--portal-card-gap)',
            marginBottom: 8,
          }}
        >
          <button
            type="button"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              padding: '10px 14px',
              background: 'var(--portal-card)',
              border: '1px solid var(--portal-border)',
              borderRadius: 9999,
              fontSize: 'var(--portal-metadata-size)',
              color: 'var(--portal-muted-foreground)',
            }}
          >
            📍 {locationLabel} ▾
          </button>
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--portal-card-gap)' }}>
            <button
              type="button"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 8,
                padding: '10px 16px',
                background: 'rgba(255,255,255,0.95)',
                border: 'none',
                borderRadius: 9999,
                fontSize: 'var(--portal-metadata-size)',
                color: 'var(--portal-foreground)',
                cursor: 'pointer',
              }}
            >
              ⋮ Filter
            </button>
            <button
              type="button"
              style={{
                width: 44,
                height: 44,
                borderRadius: '50%',
                background: 'rgba(255,255,255,0.95)',
                border: 'none',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 18,
              }}
            >
              📍
            </button>
          </div>
        </div>

        {/* Time pills — same styling as Discover */}
        <div
          style={{
            overflowX: 'auto',
            overflowY: 'hidden',
            paddingTop: 4,
            marginTop: 0,
            display: 'flex',
            gap: 'var(--portal-card-gap)',
            paddingBottom: 2,
          }}
        >
          {TIME_PILLS.map((p) => (
            <FilterPill
              key={p.id}
              title={p.label}
              icon={p.icon}
              isActive={timeFilter === p.id}
              onClick={() => setTimeFilter(timeFilter === p.id ? null : p.id)}
            />
          ))}
        </div>

        {/* Category pills — same styling as Discover */}
        <div
          style={{
            overflowX: 'auto',
            overflowY: 'hidden',
            paddingTop: 2,
            display: 'flex',
            gap: 'var(--portal-card-gap)',
          }}
        >
          {CATEGORY_PILLS.map((p) => (
            <FilterPill
              key={p.id}
              title={p.label}
              isActive={categories.has(p.id)}
              categoryColor={p.color}
              onClick={() => toggleCategory(p.id)}
            />
          ))}
        </div>
      </div>

      <div
        style={{
          color: 'var(--portal-muted-foreground)',
          fontSize: 'var(--portal-metadata-size)',
          textAlign: 'center',
          padding: 24,
        }}
      >
        Map placeholder
        <br />
        <span style={{ fontSize: 12 }}>Same chrome as app — use Cursor Browser to edit styles.</span>
      </div>
    </div>
  )
}
