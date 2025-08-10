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
    let reports: DeploymentReport[] = []
    
    console.log('🚀 ApiService.getReports called - Environment:', {
      isDev: import.meta.env.DEV,
      mode: import.meta.env.MODE,
      baseUrl: this.baseUrl,
      mockReportsLength: mockReports.length
    })
    
    // In production, try to fetch real reports first
    if (!import.meta.env.DEV) {
      try {
        const manifestUrl = `${this.baseUrl}/reports/manifest.json`
        console.log('🔍 Production mode: Fetching reports from:', manifestUrl)
        const response = await fetch(manifestUrl)
        
        console.log('📡 Fetch response:', {
          status: response.status,
          statusText: response.statusText,
          ok: response.ok,
          url: response.url
        })
        
        if (response.ok) {
          const manifest = await response.json()
          reports = manifest.reports || []
          console.log('✅ Fetched real reports from manifest:', reports.length)
        } else {
          console.log('⚠️ Manifest not found (status:', response.status, '), falling back to mock data')
          reports = [...mockReports]
          console.log('📋 Using mock data:', reports.length, 'reports')
        }
      } catch (error) {
        console.error('❌ Failed to fetch reports, using mock data:', error)
        reports = [...mockReports]
        console.log('📋 Fallback mock data loaded:', reports.length, 'reports')
      }
    } else {
      // Development: always use mock data
      console.log('🛠️ Development mode: using mock data')
      reports = [...mockReports]
    }
    
    console.log('📊 Final reports before filtering:', reports.length, reports.map(r => ({ id: r.id, env: r.environment, status: r.status })))
    
    // Apply filters if provided
    if (filters) {
      if (filters.environment) {
        reports = reports.filter(r => r.environment === filters.environment)
      }
      if (filters.status) {
        reports = reports.filter(r => r.status === filters.status)
      }
      if (filters.author) {
        reports = reports.filter(r => 
          r.author.toLowerCase().includes(filters.author!.toLowerCase())
        )
      }
      if (filters.branch) {
        reports = reports.filter(r => 
          r.branch.toLowerCase().includes(filters.branch!.toLowerCase())
        )
      }
    }
    
    const sortedReports = reports.sort((a, b) => 
      new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
    )
    
    console.log('🎯 ApiService.getReports final result:', sortedReports.length, 'reports')
    return sortedReports
  }

  static async getReport(id: string): Promise<DeploymentReport | null> {
    // Try to fetch from production first, fallback to mock data
    if (!import.meta.env.DEV) {
      try {
        const response = await fetch(`${this.baseUrl}/reports/${id}.json`)
        if (response.ok) {
          return await response.json()
        }
      } catch (error) {
        console.error(`Failed to fetch report ${id}:`, error)
      }
    }
    
    // Fallback to mock data (both in development and when production fetch fails)
    return mockReports.find(r => r.id === id) || null
  }
}