import { useState } from 'react'
import { DiscoverFiltersProvider } from './context/DiscoverFiltersContext'
import SearchBar from './components/SearchBar'
import TabBar from './components/TabBar'
import Discover from './screens/Discover'
import Profile from './screens/Profile'
import Map from './screens/Map'
import './index.css'

const TABS = { discover: 0, map: 1, profile: 2 }

export default function App() {
  const [selectedTab, setSelectedTab] = useState(TABS.discover)
  const showSearchBar = selectedTab === TABS.discover || selectedTab === TABS.map

  return (
    <DiscoverFiltersProvider>
      <div className="phone-frame">
        <div className="phone-frame-inner">
          <div className="app-content">
          <div
            className="screen"
            style={{
              paddingBottom: showSearchBar ? 120 : 80,
            }}
          >
            {selectedTab === TABS.discover && <Discover />}
            {selectedTab === TABS.map && <Map />}
            {selectedTab === TABS.profile && <Profile />}
          </div>

          <footer
            className="bottom-chrome"
            style={{
              background: 'rgba(242, 242, 240, 0.95)',
              backdropFilter: 'saturate(180%) blur(20px)',
              WebkitBackdropFilter: 'saturate(180%) blur(20px)',
            }}
          >
            {showSearchBar && (
              <div className="search-bar-wrap">
                <SearchBar />
              </div>
            )}
            <TabBar selectedTab={selectedTab} onSelectTab={setSelectedTab} />
          </footer>
        </div>
      </div>
    </div>
    </DiscoverFiltersProvider>
  )
}
