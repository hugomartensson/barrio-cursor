// Mock data for web preview — mirrors structure used in iOS DiscoverView

export const TIME_PILLS = [
  { id: 'tonight', label: 'Tonight', icon: '🌙' },
  { id: 'tomorrow', label: 'Tomorrow', icon: '☀️' },
  { id: 'thisWeekend', label: 'This Weekend', icon: '📅' },
  { id: 'saturday', label: 'Sat', icon: null },
  { id: 'sunday', label: 'Sun', icon: null },
  { id: 'pickDate', label: 'Pick a date', icon: '📅' },
]

export const CATEGORY_PILLS = [
  { id: 'food', label: 'Food', color: '#FF6B6B' },
  { id: 'drinks', label: 'Drinks', color: '#9B59B6' },
  { id: 'music', label: 'Music', color: '#3498DB' },
  { id: 'art', label: 'Art', color: '#E67E22' },
  { id: 'markets', label: 'Markets', color: '#27AE60' },
  { id: 'community', label: 'Community', color: '#F39C12' },
]

export const MOCK_EVENTS = [
  {
    id: '1',
    title: 'Community Mural Workshop',
    categoryLabel: 'COMMUNITY',
    startTime: new Date(Date.now() + 86400 * 2).toISOString(),
    address: 'Bushwick Collective · Bushwick',
    hostName: 'Weekend Atlas',
    hostInitial: 'W',
    isLive: false,
  },
  {
    id: '2',
    title: 'Jazz Night at Smalls',
    categoryLabel: 'MUSIC',
    startTime: new Date(Date.now() + 3600 * 3).toISOString(),
    address: 'Smalls Jazz Club · West Village',
    hostName: 'Mia Chen',
    hostInitial: 'M',
    isLive: true,
  },
  {
    id: '3',
    title: 'Sunday Farmers Market',
    categoryLabel: 'MARKETS',
    startTime: new Date(Date.now() + 86400 * 4).toISOString(),
    address: 'Union Square Greenmarket · Union Square',
    hostName: 'The Night Edit',
    hostInitial: 'NE',
    isLive: false,
  },
]

export const MOCK_SPOTS = [
  { id: '1', name: 'Lilia', neighborhood: 'Williamsburg', categoryLabel: 'Italian', ownerHandle: 'fredrik', ownerInitial: 'F' },
  { id: '2', name: 'Death & Co', neighborhood: 'East Village', categoryLabel: 'Cocktail Bar', ownerHandle: 'fredrik', ownerInitial: 'F' },
  { id: '3', name: 'Russ & Daughters', neighborhood: 'Lower East Side', categoryLabel: 'Cafe', ownerHandle: 'weekendatlas', ownerInitial: 'W' },
]

export const MOCK_USERS = [
  { id: '1', name: 'Mia Chen', followerCount: '48k', initial: 'M', accentColor: 'var(--portal-primary)' },
  { id: '2', name: 'The Night Edit', followerCount: '72k', initial: 'NE', accentColor: 'var(--portal-accent)' },
  { id: '3', name: 'Weekend Atlas', followerCount: '30k', initial: 'W', accentColor: 'var(--portal-live)' },
]
