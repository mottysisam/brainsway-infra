import { Clock, GitCommit, User, ExternalLink, CheckCircle, XCircle, Loader } from 'lucide-react'
import { DeploymentReport } from '@/types'

interface ReportCardProps {
  report: DeploymentReport
  onClick?: () => void
}

export function ReportCard({ report, onClick }: ReportCardProps) {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'success': return 'text-green-600 bg-green-50'
      case 'failed': return 'text-red-600 bg-red-50'
      case 'running': return 'text-yellow-600 bg-yellow-50'
      default: return 'text-gray-600 bg-gray-50'
    }
  }

  const getEnvironmentColor = (env: string) => {
    switch (env) {
      case 'dev': return 'bg-dev-100 text-dev-800'
      case 'staging': return 'bg-staging-100 text-staging-800'
      case 'prod': return 'bg-prod-100 text-prod-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'success': return <CheckCircle className="w-4 h-4" />
      case 'failed': return <XCircle className="w-4 h-4" />
      case 'running': return <Loader className="w-4 h-4 animate-spin" />
      default: return null
    }
  }

  const formatDuration = (seconds?: number) => {
    if (!seconds) return 'N/A'
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}m ${secs}s`
  }

  const formatTimestamp = (timestamp: string) => {
    return new Date(timestamp).toLocaleString()
  }

  return (
    <div 
      className={`bg-white rounded-lg shadow-md p-6 border-l-4 border-${report.environment === 'dev' ? 'dev' : report.environment === 'staging' ? 'staging' : 'prod'}-500 transition-all hover:shadow-lg hover:scale-[1.02] cursor-pointer`}
      onClick={onClick}
    >
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className={`flex items-center space-x-2 px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(report.status)}`}>
            {getStatusIcon(report.status)}
            <span className="capitalize">{report.status}</span>
          </div>
          <span className={`px-2 py-1 text-xs font-semibold uppercase tracking-wide rounded-md ${getEnvironmentColor(report.environment)}`}>
            {report.environment}
          </span>
        </div>
        {report.url && (
          <ExternalLink className="w-4 h-4 text-gray-400 hover:text-blue-500" />
        )}
      </div>

      <div className="mb-3">
        <h3 className="text-lg font-semibold text-gray-900 mb-1 line-clamp-2">
          {report.message}
        </h3>
        <div className="flex items-center space-x-4 text-sm text-gray-600">
          <div className="flex items-center space-x-1">
            <GitCommit className="w-4 h-4" />
            <span className="font-mono">{report.commit}</span>
          </div>
          <div className="flex items-center space-x-1">
            <User className="w-4 h-4" />
            <span>{report.author}</span>
          </div>
          <div className="flex items-center space-x-1">
            <Clock className="w-4 h-4" />
            <span>{formatDuration(report.duration)}</span>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between text-sm">
        <span className="text-gray-500 font-mono bg-gray-100 px-2 py-1 rounded">
          {report.branch}
        </span>
        <span className="text-gray-500">
          {formatTimestamp(report.timestamp)}
        </span>
      </div>

      {report.changes.length > 0 && (
        <div className="mt-4 pt-3 border-t border-gray-100">
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600">Changes:</span>
            <div className="flex space-x-3">
              {['create', 'update', 'delete'].map(action => {
                const count = report.changes.filter(c => c.action === action).length
                if (count === 0) return null
                return (
                  <span key={action} className={`inline-flex items-center px-2 py-1 text-xs rounded ${
                    action === 'create' ? 'bg-green-100 text-green-800' :
                    action === 'update' ? 'bg-blue-100 text-blue-800' :
                    'bg-red-100 text-red-800'
                  }`}>
                    +{count} {action}
                  </span>
                )
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}