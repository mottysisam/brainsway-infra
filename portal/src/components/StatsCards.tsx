import { BarChart3, Clock, CheckCircle, XCircle } from 'lucide-react'
import { EnvironmentStats } from '@/types'

interface StatsCardsProps {
  stats: EnvironmentStats[]
}

export function StatsCards({ stats }: StatsCardsProps) {
  const totalDeployments = stats.reduce((sum, env) => sum + env.totalDeployments, 0)
  const overallSuccessRate = stats.length > 0 
    ? stats.reduce((sum, env) => sum + env.successRate * env.totalDeployments, 0) / totalDeployments
    : 0
  const averageDuration = stats.length > 0
    ? stats.reduce((sum, env) => sum + env.averageDuration * env.totalDeployments, 0) / totalDeployments
    : 0

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = Math.round(seconds % 60)
    return `${mins}m ${secs}s`
  }

  const formatPercentage = (value: number) => {
    return `${Math.round(value * 100)}%`
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      {/* Total Deployments */}
      <div className="bg-white rounded-lg shadow-sm border p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Total Deployments</p>
            <p className="text-3xl font-bold text-gray-900">{totalDeployments}</p>
          </div>
          <div className="p-3 bg-blue-100 rounded-full">
            <BarChart3 className="w-6 h-6 text-blue-600" />
          </div>
        </div>
        <div className="mt-4">
          <div className="text-sm text-gray-500">
            Across all environments
          </div>
        </div>
      </div>

      {/* Success Rate */}
      <div className="bg-white rounded-lg shadow-sm border p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Success Rate</p>
            <p className="text-3xl font-bold text-green-600">
              {formatPercentage(overallSuccessRate)}
            </p>
          </div>
          <div className="p-3 bg-green-100 rounded-full">
            <CheckCircle className="w-6 h-6 text-green-600" />
          </div>
        </div>
        <div className="mt-4">
          <div className="text-sm text-gray-500">
            Overall success rate
          </div>
        </div>
      </div>

      {/* Average Duration */}
      <div className="bg-white rounded-lg shadow-sm border p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Avg Duration</p>
            <p className="text-3xl font-bold text-blue-600">
              {formatDuration(averageDuration)}
            </p>
          </div>
          <div className="p-3 bg-blue-100 rounded-full">
            <Clock className="w-6 h-6 text-blue-600" />
          </div>
        </div>
        <div className="mt-4">
          <div className="text-sm text-gray-500">
            Average deployment time
          </div>
        </div>
      </div>

      {/* Failed Deployments */}
      <div className="bg-white rounded-lg shadow-sm border p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-gray-600">Failed</p>
            <p className="text-3xl font-bold text-red-600">
              {totalDeployments - Math.round(overallSuccessRate * totalDeployments)}
            </p>
          </div>
          <div className="p-3 bg-red-100 rounded-full">
            <XCircle className="w-6 h-6 text-red-600" />
          </div>
        </div>
        <div className="mt-4">
          <div className="text-sm text-gray-500">
            {formatPercentage(1 - overallSuccessRate)} failure rate
          </div>
        </div>
      </div>

      {/* Environment Breakdown */}
      <div className="md:col-span-2 lg:col-span-4 bg-white rounded-lg shadow-sm border p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Environment Breakdown</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {stats.map(env => (
            <div key={env.environment} className="text-center p-4 rounded-lg bg-gray-50">
              <div className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium mb-2 ${
                env.environment === 'dev' ? 'bg-dev-100 text-dev-800' :
                env.environment === 'staging' ? 'bg-staging-100 text-staging-800' :
                'bg-prod-100 text-prod-800'
              }`}>
                {env.environment.toUpperCase()}
              </div>
              <div className="space-y-2">
                <div>
                  <div className="text-2xl font-bold text-gray-900">{env.totalDeployments}</div>
                  <div className="text-xs text-gray-500">deployments</div>
                </div>
                <div>
                  <div className="text-lg font-semibold text-green-600">
                    {formatPercentage(env.successRate)}
                  </div>
                  <div className="text-xs text-gray-500">success rate</div>
                </div>
                <div>
                  <div className="text-sm font-medium text-blue-600">
                    {formatDuration(env.averageDuration)}
                  </div>
                  <div className="text-xs text-gray-500">avg duration</div>
                </div>
                {env.lastDeployment && (
                  <div>
                    <div className="text-xs text-gray-500">
                      Last: {new Date(env.lastDeployment).toLocaleDateString()}
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}