import { Filter, X, Search } from 'lucide-react'
import { FilterOptions } from '@/types'
import { useState } from 'react'

interface FilterBarProps {
  filters: FilterOptions
  onFilterChange: (filters: FilterOptions) => void
  onClearFilters: () => void
}

export function FilterBar({ filters, onFilterChange, onClearFilters }: FilterBarProps) {
  const [searchTerm, setSearchTerm] = useState('')

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onFilterChange({ ...filters, branch: searchTerm })
  }

  const hasActiveFilters = Object.values(filters).some(value => 
    value !== undefined && value !== ''
  )

  return (
    <div className="bg-white rounded-lg shadow-sm border p-4 mb-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-2">
          <Filter className="w-5 h-5 text-gray-500" />
          <h3 className="text-lg font-semibold text-gray-900">Filters</h3>
        </div>
        {hasActiveFilters && (
          <button
            onClick={onClearFilters}
            className="flex items-center space-x-1 text-sm text-gray-600 hover:text-gray-900 transition-colors"
          >
            <X className="w-4 h-4" />
            <span>Clear All</span>
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Search Bar */}
        <form onSubmit={handleSearchSubmit} className="relative">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <Search className="h-4 w-4 text-gray-400" />
          </div>
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search branches..."
            className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
          />
        </form>

        {/* Environment Filter */}
        <select
          value={filters.environment || ''}
          onChange={(e) => onFilterChange({ 
            ...filters, 
            environment: e.target.value as 'dev' | 'staging' | 'prod' | undefined
          })}
          className="block w-full px-3 py-2 border border-gray-300 rounded-md leading-5 bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
        >
          <option value="">All Environments</option>
          <option value="dev">Development</option>
          <option value="staging">Staging</option>
          <option value="prod">Production</option>
        </select>

        {/* Status Filter */}
        <select
          value={filters.status || ''}
          onChange={(e) => onFilterChange({ 
            ...filters, 
            status: e.target.value as 'success' | 'failed' | 'running' | undefined
          })}
          className="block w-full px-3 py-2 border border-gray-300 rounded-md leading-5 bg-white focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
        >
          <option value="">All Statuses</option>
          <option value="success">Success</option>
          <option value="failed">Failed</option>
          <option value="running">Running</option>
        </select>

        {/* Author Filter */}
        <input
          type="text"
          value={filters.author || ''}
          onChange={(e) => onFilterChange({ ...filters, author: e.target.value })}
          placeholder="Filter by author..."
          className="block w-full px-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
        />
      </div>

      {/* Active Filter Tags */}
      {hasActiveFilters && (
        <div className="mt-4 pt-4 border-t border-gray-100">
          <div className="flex flex-wrap gap-2">
            {filters.environment && (
              <span className="inline-flex items-center space-x-1 px-3 py-1 text-sm bg-blue-100 text-blue-800 rounded-full">
                <span>Environment: {filters.environment}</span>
                <button
                  onClick={() => onFilterChange({ ...filters, environment: undefined })}
                  className="hover:text-blue-900"
                >
                  <X className="w-3 h-3" />
                </button>
              </span>
            )}
            {filters.status && (
              <span className="inline-flex items-center space-x-1 px-3 py-1 text-sm bg-green-100 text-green-800 rounded-full">
                <span>Status: {filters.status}</span>
                <button
                  onClick={() => onFilterChange({ ...filters, status: undefined })}
                  className="hover:text-green-900"
                >
                  <X className="w-3 h-3" />
                </button>
              </span>
            )}
            {filters.author && (
              <span className="inline-flex items-center space-x-1 px-3 py-1 text-sm bg-purple-100 text-purple-800 rounded-full">
                <span>Author: {filters.author}</span>
                <button
                  onClick={() => onFilterChange({ ...filters, author: undefined })}
                  className="hover:text-purple-900"
                >
                  <X className="w-3 h-3" />
                </button>
              </span>
            )}
            {filters.branch && (
              <span className="inline-flex items-center space-x-1 px-3 py-1 text-sm bg-orange-100 text-orange-800 rounded-full">
                <span>Branch: {filters.branch}</span>
                <button
                  onClick={() => onFilterChange({ ...filters, branch: undefined })}
                  className="hover:text-orange-900"
                >
                  <X className="w-3 h-3" />
                </button>
              </span>
            )}
          </div>
        </div>
      )}
    </div>
  )
}