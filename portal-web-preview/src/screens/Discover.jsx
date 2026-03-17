import PortalWordmark from '../components/PortalWordmark'
import FilterPill from '../components/FilterPill'
import SectionHeader from '../components/SectionHeader'
import PortalEventCard from '../components/PortalEventCard'
import PortalSpotCard from '../components/PortalSpotCard'
import SuggestedUserCard from '../components/SuggestedUserCard'
import { useDiscoverFilters } from '../context/DiscoverFiltersContext'
import {
  TIME_PILLS,
  CATEGORY_PILLS,
  MOCK_EVENTS,
  MOCK_SPOTS,
  MOCK_USERS,
} from '../data/mock'

export default function Discover() {
  const { timeFilter, setTimeFilter, categories, toggleCategory, locationLabel } = useDiscoverFilters()

  return (
    <div
      style={{
        background: 'var(--portal-background)',
        paddingTop: 12,
        paddingBottom: 24,
      }}
    >
      {/* Header: location pill + wordmark + pills */}
      <header
        style={{
          paddingLeft: 'var(--portal-page-padding)',
          paddingRight: 'var(--portal-page-padding)',
          paddingBottom: 8,
          background: 'rgba(255,255,255,0.6)',
          backdropFilter: 'blur(12px)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--portal-card-gap)', marginBottom: 'var(--portal-section-spacing)' }}>
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
        </div>

        <PortalWordmark />

        {/* Time pills */}
        <div
          style={{
            overflowX: 'auto',
            overflowY: 'hidden',
            paddingTop: 4,
            marginTop: 4,
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

        {/* Category pills */}
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
      </header>

      {/* Main content */}
      <div
        style={{
          paddingLeft: 'var(--portal-page-padding)',
          paddingRight: 'var(--portal-page-padding)',
          paddingTop: 'var(--portal-section-spacing)',
        }}
      >
        {/* EVENTS */}
        <SectionHeader label="EVENTS" title={MOCK_EVENTS.some((e) => e.isLive) ? 'Happening Now' : 'This Weekend'} />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--portal-section-spacing)', marginBottom: 'var(--portal-section-spacing)' }}>
          {MOCK_EVENTS.map((event) => (
            <PortalEventCard key={event.id} event={event} />
          ))}
        </div>

        {/* SPOTS */}
        <SectionHeader label="SPOTS" title="Near you" />
        <div
          style={{
            overflowX: 'auto',
            overflowY: 'hidden',
            display: 'flex',
            gap: 'var(--portal-card-gap)',
            paddingVertical: 4,
            marginBottom: 'var(--portal-section-spacing)',
          }}
        >
          {MOCK_SPOTS.map((spot) => (
            <PortalSpotCard key={spot.id} spot={spot} />
          ))}
        </div>

        {/* PEOPLE */}
        <SectionHeader label="PEOPLE" title="People to follow" />
        <div
          style={{
            overflowX: 'auto',
            overflowY: 'hidden',
            display: 'flex',
            gap: 'var(--portal-card-gap)',
            paddingVertical: 4,
          }}
        >
          {MOCK_USERS.map((user) => (
            <SuggestedUserCard key={user.id} user={user} />
          ))}
        </div>
      </div>
    </div>
  )
}
