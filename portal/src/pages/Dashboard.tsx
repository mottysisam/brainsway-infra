import { useState, useEffect } from 'react'
import { ReportCard } from '@/components/ReportCard'
import { FilterBar } from '@/components/FilterBar'
import { StatsCards } from '@/components/StatsCards'
import { DeploymentReport, FilterOptions, EnvironmentStats } from '@/types'
import { ApiService } from '@/services/api'
import { RefreshCw, AlertCircle } from 'lucide-react'

export function Dashboard() {
  const [reports, setReports] = useState<DeploymentReport[]>([])
  const [filteredReports, setFilteredReports] = useState<DeploymentReport[]>([])
  const [filters, setFilters] = useState<FilterOptions>({})
  const [stats, setStats] = useState<EnvironmentStats[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedReport, setSelectedReport] = useState<DeploymentReport | null>(null)

  const loadReports = async () => {
    try {
      setLoading(true)
      setError(null)
      const data = await ApiService.getReports()
      setReports(data)
      calculateStats(data)
    } catch (err) {
      setError('Failed to load deployment reports')
      console.error('Error loading reports:', err)
    } finally {
      setLoading(false)
    }
  }

  const calculateStats = (reportData: DeploymentReport[]) => {
    const environments: ('dev' | 'staging' | 'prod')[] = ['dev', 'staging', 'prod']
    const environmentStats: EnvironmentStats[] = environments.map(env => {
      const envReports = reportData.filter(r => r.environment === env)
      const successful = envReports.filter(r => r.status === 'success').length
      const totalDuration = envReports.reduce((sum, r) => sum + (r.duration || 0), 0)
      const lastDeployment = envReports.length > 0 
        ? envReports.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())[0].timestamp
        : undefined

      return {
        environment: env,
        totalDeployments: envReports.length,
        successRate: envReports.length > 0 ? successful / envReports.length : 0,
        averageDuration: envReports.length > 0 ? totalDuration / envReports.length : 0,
        lastDeployment
      }
    })

    setStats(environmentStats)
  }

  const applyFilters = async () => {
    try {
      const filtered = await ApiService.getReports(filters)
      setFilteredReports(filtered)
    } catch (err) {
      console.error('Error applying filters:', err)
      setFilteredReports(reports)
    }
  }

  const handleFilterChange = (newFilters: FilterOptions) => {
    setFilters(newFilters)
  }

  const handleClearFilters = () => {
    setFilters({})
  }

  const handleReportClick = (report: DeploymentReport) => {
    setSelectedReport(report)
  }

  const handleCloseReportDetail = () => {
    setSelectedReport(null)
  }

  useEffect(() => {
    loadReports()
  }, [])

  useEffect(() => {
    applyFilters()
  }, [filters, reports])

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <RefreshCw className="w-8 h-8 animate-spin text-blue-500 mx-auto mb-4" />
          <p className="text-gray-600">Loading deployment reports...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <AlertCircle className="w-8 h-8 text-red-500 mx-auto mb-4" />
          <p className="text-red-600 mb-4">{error}</p>
          <button
            onClick={loadReports}
            className="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors"
          >
            Try Again
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">
                Brainsway Infrastructure Portal
              </h1>
              <p className="mt-2 text-gray-600">
                Interactive deployment report dashboard for AWS infrastructure
              </p>
            </div>
            <button
              onClick={loadReports}
              className="flex items-center space-x-2 px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors"
            >
              <RefreshCw className="w-4 h-4" />
              <span>Refresh</span>
            </button>
          </div>
        </div>

        {/* Statistics Cards */}
        <StatsCards stats={stats} />

        {/* Filters */}
        <FilterBar
          filters={filters}
          onFilterChange={handleFilterChange}
          onClearFilters={handleClearFilters}
        />

        {/* Reports Grid */}
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900">
            Deployment Reports
            <span className="ml-2 text-sm font-normal text-gray-500">
              ({filteredReports.length} {filteredReports.length === 1 ? 'result' : 'results'})
            </span>
          </h2>
        </div>

        {filteredReports.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-gray-400 mb-4">
              <AlertCircle className="w-12 h-12 mx-auto" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No reports found</h3>
            <p className="text-gray-600">
              {Object.values(filters).some(v => v) 
                ? 'Try adjusting your filters to see more results.'
                : 'No deployment reports are available yet.'
              }
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {filteredReports.map(report => (
              <ReportCard
                key={report.id}
                report={report}
                onClick={() => handleReportClick(report)}
              />
            ))}
          </div>
        )}

        {/* Report Detail Modal */}
        {selectedReport && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
              <div className="p-6">
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-2xl font-bold text-gray-900">
                    Deployment Details
                  </h3>
                  <button
                    onClick={handleCloseReportDetail}
                    className="text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    <span className="sr-only">Close</span>
                    <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
                
                <div className="space-y-6">
                  <ReportCard report={selectedReport} />
                  
                  {selectedReport.changes.length > 0 && (
                    <div>
                      <h4 className="text-lg font-semibold text-gray-900 mb-3">Resource Changes</h4>
                      <div className="space-y-2">
                        {selectedReport.changes.map((change, index) => (
                          <div 
                            key={index}
                            className={`flex items-center space-x-3 p-3 rounded-lg ${
                              change.action === 'create' ? 'bg-green-50' :
                              change.action === 'update' ? 'bg-blue-50' :
                              change.action === 'delete' ? 'bg-red-50' :
                              'bg-gray-50'
                            }`}
                          >
                            <span className={`inline-flex items-center px-2 py-1 text-xs font-medium rounded ${
                              change.action === 'create' ? 'bg-green-100 text-green-800' :
                              change.action === 'update' ? 'bg-blue-100 text-blue-800' :
                              change.action === 'delete' ? 'bg-red-100 text-red-800' :
                              'bg-gray-100 text-gray-800'
                            }`}>
                              {change.action.toUpperCase()}
                            </span>
                            <div>
                              <div className="font-medium text-gray-900">{change.resource}</div>
                              <div className="text-sm text-gray-500">{change.resourceType}</div>
                              {change.details && (
                                <div className="text-xs text-gray-400 mt-1">{change.details}</div>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {selectedReport.terragruntOutput && (
                    <div>
                      <h4 className="text-lg font-semibold text-gray-900 mb-3">Terragrunt Output</h4>
                      <pre className="bg-gray-900 text-green-400 p-4 rounded-lg text-sm overflow-x-auto">
                        {selectedReport.terragruntOutput}
                      </pre>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}