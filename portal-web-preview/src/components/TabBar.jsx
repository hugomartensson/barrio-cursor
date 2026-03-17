const TABS = [
  { id: 0, label: 'Discover', icon: '📍' },
  { id: 1, label: 'Map', icon: '🗺️' },
  { id: 2, label: 'Profile', icon: '👤' },
]

export default function TabBar({ selectedTab, onSelectTab }) {
  return (
    <nav
      className="tab-bar"
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-around',
        paddingTop: 12,
        paddingBottom: 24,
        paddingLeft: 24,
        paddingRight: 24,
        height: 'var(--portal-bottom-nav-height)',
        width: '100%',
      }}
    >
      {TABS.map((tab) => {
        const isActive = selectedTab === tab.id
        return (
          <button
            key={tab.id}
            type="button"
            onClick={() => onSelectTab(tab.id)}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 4,
              flex: 1,
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              color: isActive ? 'var(--portal-primary)' : 'var(--portal-muted-foreground)',
            }}
            aria-current={isActive ? 'page' : undefined}
          >
            <span
              style={{
                fontSize: 22,
                transform: isActive ? 'scale(1.1)' : 'scale(1)',
                transition: 'transform 0.2s',
              }}
            >
              {tab.icon}
            </span>
            <span
              style={{
                fontSize: 'var(--portal-metadata-size)',
                fontWeight: 400,
              }}
            >
              {tab.label}
            </span>
            {isActive && (
              <span
                style={{
                  width: 4,
                  height: 4,
                  borderRadius: '50%',
                  background: 'var(--portal-primary)',
                }}
              />
            )}
            {!isActive && (
              <span
                style={{
                  width: 4,
                  height: 4,
                  borderRadius: '50%',
                  background: 'transparent',
                }}
              />
            )}
          </button>
        )
      })}
    </nav>
  )
}
