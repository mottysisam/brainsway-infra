export interface DeploymentReport {
  id: string
  timestamp: string
  environment: 'dev' | 'staging' | 'prod'
  branch: string
  commit: string
  status: 'success' | 'failed' | 'running'
  duration?: number
  changes: ReportChange[]
  author: string
  message: string
  url?: string
  terragruntOutput?: string
  diggerComment?: string
}

export interface ReportChange {
  action: 'create' | 'update' | 'delete' | 'no-change'
  resource: string
  resourceType: string
  details?: string
}

export interface FilterOptions {
  environment?: 'dev' | 'staging' | 'prod'
  status?: 'success' | 'failed' | 'running'
  author?: string
  dateRange?: {
    start: string
    end: string
  }
  branch?: string
}

export interface EnvironmentStats {
  environment: 'dev' | 'staging' | 'prod'
  totalDeployments: number
  successRate: number
  averageDuration: number
  lastDeployment?: string
}