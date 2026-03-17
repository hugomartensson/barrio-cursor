import { createContext, useContext, useState, useCallback } from 'react'

const DiscoverFiltersContext = createContext(null)

export function DiscoverFiltersProvider({ children }) {
  const [timeFilter, setTimeFilter] = useState(null)
  const [categories, setCategories] = useState(new Set())
  const [locationLabel, setLocationLabel] = useState('New York City')

  const toggleCategory = useCallback((id) => {
    setCategories((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }, [])

  const value = {
    timeFilter,
    setTimeFilter,
    categories,
    setCategories,
    toggleCategory,
    locationLabel,
    setLocationLabel,
  }

  return (
    <DiscoverFiltersContext.Provider value={value}>
      {children}
    </DiscoverFiltersContext.Provider>
  )
}

export function useDiscoverFilters() {
  const ctx = useContext(DiscoverFiltersContext)
  if (!ctx) {
    throw new Error('useDiscoverFilters must be used within DiscoverFiltersProvider')
  }
  return ctx
}
