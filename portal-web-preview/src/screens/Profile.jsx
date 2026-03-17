import { useState } from 'react'

const TABS = [
  { id: 'collections', label: 'Collections' },
  { id: 'spots', label: 'Spots' },
  { id: 'events', label: 'Events' },
]

export default function Profile() {
  const [selectedTab, setSelectedTab] = useState('collections')

  return (
    <div
      style={{
        background: 'var(--portal-background)',
        minHeight: '100%',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Header: X + user name + settings gear */}
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          padding: '12px var(--portal-page-padding)',
          background: 'rgba(255,255,255,0.7)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          borderBottom: '1px solid var(--portal-border)',
        }}
      >
        <button
          type="button"
          aria-label="Close"
          style={{
            width: 36,
            height: 36,
            borderRadius: '50%',
            border: '1px solid rgba(224,224,222,0.5)',
            background: 'rgba(255,255,255,0.8)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            fontSize: 14,
            fontWeight: 600,
            color: 'var(--portal-foreground)',
          }}
        >
          ✕
        </button>
        <h1
          style={{
            flex: 1,
            margin: 0,
            fontFamily: 'var(--portal-font-display)',
            fontSize: 'var(--portal-display-22)',
            fontWeight: 600,
            color: 'var(--portal-foreground)',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          Alex Rivera
        </h1>
        <button
          type="button"
          aria-label="Settings"
          style={{
            width: 36,
            height: 36,
            border: 'none',
            background: 'none',
            cursor: 'pointer',
            fontSize: 18,
            color: 'var(--portal-foreground)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          ⚙
        </button>
      </header>

      {/* Hero: avatar + handle + city + bio */}
      <section
        style={{
          display: 'flex',
          alignItems: 'flex-start',
          gap: 'var(--portal-page-padding)',
          padding: 'var(--portal-page-padding)',
        }}
      >
        <div
          style={{
            width: 64,
            height: 64,
            borderRadius: '50%',
            background: 'var(--portal-primary)',
            color: 'var(--portal-primary-foreground)',
            fontFamily: 'var(--portal-font-display)',
            fontSize: 'var(--portal-display-22)',
            fontWeight: 600,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          A
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              fontSize: 'var(--portal-metadata-size)',
              color: 'var(--portal-muted-foreground)',
              marginBottom: 4,
            }}
          >
            @alexrivera
          </div>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              fontSize: 'var(--portal-metadata-size)',
              color: 'var(--portal-muted-foreground)',
              marginBottom: 6,
            }}
          >
            <span>📍</span>
            <span>Stockholm</span>
          </div>
          <div
            style={{
              fontSize: 'var(--portal-metadata-size)',
              color: 'var(--portal-foreground)',
              opacity: 0.85,
              lineHeight: 1.4,
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}
          >
            Food & drinks curator. Always hunting for the best natural wine bars.
          </div>
        </div>
      </section>

      {/* Create actions: 3 cards with plus */}
      <section
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr 1fr',
          gap: 'var(--portal-card-gap)',
          padding: '0 var(--portal-page-padding) 16px',
        }}
      >
        {[
          { icon: '📁', label: 'COLLECTION' },
          { icon: '📍', label: 'SPOT' },
          { icon: '📅', label: 'EVENT' },
        ].map((item) => (
          <button
            key={item.label}
            type="button"
            style={{
              padding: '16px 8px',
              background: 'var(--portal-card)',
              borderRadius: 'var(--portal-radius)',
              boxShadow: 'var(--portal-shadow-card-1), var(--portal-shadow-card-2)',
              border: 'none',
              cursor: 'pointer',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 8,
            }}
          >
            <div style={{ position: 'relative', height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span style={{ fontSize: 24 }}>{item.icon}</span>
              <span
                style={{
                  position: 'absolute',
                  right: -4,
                  bottom: -4,
                  width: 18,
                  height: 18,
                  borderRadius: '50%',
                  background: 'var(--portal-primary)',
                  color: 'var(--portal-primary-foreground)',
                  fontSize: 10,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: 700,
                }}
              >
                +
              </span>
            </div>
            <span
              style={{
                fontSize: 'var(--portal-section-label-size)',
                fontWeight: 'var(--portal-section-label-weight)',
                letterSpacing: '0.18em',
                color: 'var(--portal-muted-foreground)',
              }}
            >
              {item.label}
            </span>
          </button>
        ))}
      </section>

      {/* Tab bar */}
      <div
        style={{
          display: 'flex',
          borderBottom: '1px solid var(--portal-border)',
          padding: '0 var(--portal-page-padding)',
        }}
      >
        {TABS.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => setSelectedTab(tab.id)}
            style={{
              flex: 1,
              padding: '12px 0 8px',
              border: 'none',
              background: 'none',
              cursor: 'pointer',
              fontSize: 'var(--portal-label-semibold-size)',
              fontWeight: 600,
              color: selectedTab === tab.id ? 'var(--portal-foreground)' : 'var(--portal-muted-foreground)',
              position: 'relative',
            }}
          >
            {tab.label}
            {selectedTab === tab.id && (
              <div
                style={{
                  position: 'absolute',
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  background: 'var(--portal-primary)',
                }}
              />
            )}
          </button>
        ))}
      </div>

      {/* Tab content: empty state */}
      <div
        style={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: 32,
          textAlign: 'center',
        }}
      >
        <div
          style={{
            width: 48,
            height: 48,
            marginBottom: 24,
            color: 'var(--portal-muted-foreground)',
            fontSize: 48,
            lineHeight: 1,
          }}
        >
          {selectedTab === 'collections' && '🔖'}
          {selectedTab === 'spots' && '📍'}
          {selectedTab === 'events' && '📅'}
        </div>
        <div
          style={{
            fontFamily: 'var(--portal-font-display)',
            fontSize: 'var(--portal-display-22)',
            fontWeight: 600,
            color: 'var(--portal-foreground)',
            marginBottom: 8,
          }}
        >
          {selectedTab === 'collections' && 'No collections yet'}
          {selectedTab === 'spots' && 'No saved spots yet'}
          {selectedTab === 'events' && 'No events yet'}
        </div>
        <div
          style={{
            fontSize: 'var(--portal-metadata-size)',
            color: 'var(--portal-muted-foreground)',
            maxWidth: 260,
          }}
        >
          {selectedTab === 'collections' && 'Save or create collections to see them here.'}
          {selectedTab === 'spots' && 'Save spots from Discover to see them here.'}
          {selectedTab === 'events' && 'Save or create events to see them here.'}
        </div>
      </div>
    </div>
  )
}
