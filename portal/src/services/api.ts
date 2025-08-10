import { DeploymentReport, FilterOptions } from '@/types'

// Mock data for development - will be replaced with GitHub API integration
const mockReports: DeploymentReport[] = [
  {
    id: '1',
    timestamp: '2025-01-10T14:30:00Z',
    environment: 'dev',
    branch: 'feat/portal-improvements',
    commit: '5e0ee8b',
    status: 'success',
    duration: 180,
    author: 'motty',
    message: 'Add React portal for deployment visualization',
    changes: [
      { action: 'create', resource: 'portal/', resourceType: 'directory' },
      { action: 'create', resource: 'portal/package.json', resourceType: 'file' },
      { action: 'update', resource: '.github/workflows/deploy-portal.yml', resourceType: 'workflow' }
    ]
  },
  {
    id: '2',
    timestamp: '2025-01-10T12:15:00Z',
    environment: 'staging',
    branch: 'feat/aurora-instances',
    commit: 'aded054',
    status: 'success',
    duration: 320,
    author: 'motty',
    message: 'Implement Aurora Serverless v2 with proper writer instances',
    changes: [
      { action: 'create', resource: 'db-aurora-1-staging-instance-1', resourceType: 'aurora_cluster_instance' },
      { action: 'update', resource: 'db-aurora-1-staging', resourceType: 'aurora_cluster' },
      { action: 'update', resource: 'insight-production-db-staging', resourceType: 'aurora_cluster' }
    ]
  },
  {
    id: '3',
    timestamp: '2025-01-10T10:45:00Z',
    environment: 'prod',
    branch: 'main',
    commit: 'fbd6eb2',
    status: 'success',
    duration: 45,
    author: 'motty',
    message: 'Production import verification - no changes',
    changes: [
      { action: 'no-change', resource: 'db-aurora-1', resourceType: 'aurora_cluster' },
      { action: 'no-change', resource: 'db-rds-1', resourceType: 'db_instance' }
    ]
  }
]

export class ApiService {
  private static baseUrl = import.meta.env.DEV
    ? 'http://localhost:3000'
    : 'https://mottysisam.github.io/brainsway-infra'

  static async getReports(filters?: FilterOptions): Promise<DeploymentReport[]> {
    // In development, return mock data
    if (import.meta.env.DEV) {
      let filteredReports = [...mockReports]
      
      if (filters) {
        if (filters.environment) {
          filteredReports = filteredReports.filter(r => r.environment === filters.environment)
        }
        if (filters.status) {
          filteredReports = filteredReports.filter(r => r.status === filters.status)
        }
        if (filters.author) {
          filteredReports = filteredReports.filter(r => 
            r.author.toLowerCase().includes(filters.author!.toLowerCase())
          )
        }
        if (filters.branch) {
          filteredReports = filteredReports.filter(r => 
            r.branch.toLowerCase().includes(filters.branch!.toLowerCase())
          )
        }
      }
      
      return filteredReports.sort((a, b) => 
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      )
    }

    // Production: fetch from GitHub Pages manifest
    try {
      const response = await fetch(`${this.baseUrl}/reports/manifest.json`)
      const manifest = await response.json()
      return manifest.reports || []
    } catch (error) {
      console.error('Failed to fetch reports:', error)
      return []
    }
  }

  static async getReport(id: string): Promise<DeploymentReport | null> {
    if (import.meta.env.DEV) {
      return mockReports.find(r => r.id === id) || null
    }

    try {
      const response = await fetch(`${this.baseUrl}/reports/${id}.json`)
      return await response.json()
    } catch (error) {
      console.error(`Failed to fetch report ${id}:`, error)
      return null
    }
  }
}