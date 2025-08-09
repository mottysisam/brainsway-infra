include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/apigw_rest" }
inputs = {
  "apis": {
    "dev-s3-url-v18": {
      "name": "S3 URL V-1-8 (Dev)",
      "description": "Dev - to get presigned URL for S3 for version 1.8",
      "tags": {
        "Environment": "dev"
      }
    },
    "dev-s3-url": {
      "name": "S3 URL (Dev)",
      "description": "Dev - to get presigned URL for S3",
      "tags": {
        "Environment": "dev"
      }
    },
    "dev-sync-clock-api": {
      "name": "sync_clock_api (Dev)",
      "description": "Dev - Clock synchronization API",
      "tags": {
        "Environment": "dev"
      }
    },
    "dev-sw-update": {
      "name": "sw update (Dev)",
      "description": "Dev - call to lambda which handles sw update cases",
      "tags": {
        "Environment": "dev"
      }
    },
    "dev-s3-url-2": {
      "name": "S3 URL 2 (Dev)",
      "description": "Dev - to get presigned URL for S3",
      "tags": {
        "Environment": "dev"
      }
    },
    "dev-insert-ppu-data": {
      "name": "dev-insert-ppu-data (Dev)",
      "description": "Dev - PPU data insertion API",
      "tags": {
        "Environment": "dev"
      }
    }
  },
  "stages": {
    "dev-s3-url-v18/dev": {
      "rest_api_id": "dev-s3-url-v18",
      "stage_name": "dev",
      "deployment_id": null,  # Will be generated on first deployment
      "description": "Development environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "dev-s3-url/dev": {
      "rest_api_id": "dev-s3-url",
      "stage_name": "dev",
      "deployment_id": null,
      "description": "Development environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "dev-sync-clock-api/dev": {
      "rest_api_id": "dev-sync-clock-api",
      "stage_name": "dev",
      "deployment_id": null,
      "description": "Development environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "dev-sw-update/dev": {
      "rest_api_id": "dev-sw-update",
      "stage_name": "dev",
      "deployment_id": null,
      "description": "Development environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "dev-s3-url-2/dev": {
      "rest_api_id": "dev-s3-url-2",
      "stage_name": "dev",
      "deployment_id": null,
      "description": "Development environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "dev-insert-ppu-data/dev": {
      "rest_api_id": "dev-insert-ppu-data",
      "stage_name": "dev",
      "deployment_id": null,
      "description": "Development environment",
      "variables": null,
      "xray_tracing_enabled": false
    }
  }
}
