include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/apigw_rest" }
inputs = {
  "apis": {
    "staging-s3-url-v18": {
      "name": "S3 URL V-1-8 (Staging)",
      "description": "Staging - to get presigned URL for S3 for version 1.8",
      "tags": {
        "Environment": "staging"
      }
    },
    "staging-s3-url": {
      "name": "S3 URL (Staging)",
      "description": "Staging - to get presigned URL for S3",
      "tags": {
        "Environment": "staging"
      }
    },
    "staging-sync-clock-api": {
      "name": "sync_clock_api (Staging)",
      "description": "Staging - Clock synchronization API",
      "tags": {
        "Environment": "staging"
      }
    },
    "staging-sw-update": {
      "name": "sw update (Staging)",
      "description": "Staging - call to lambda which handles sw update cases",
      "tags": {
        "Environment": "staging"
      }
    },
    "staging-s3-url-2": {
      "name": "S3 URL 2 (Staging)",
      "description": "Staging - to get presigned URL for S3",
      "tags": {
        "Environment": "staging"
      }
    },
    "staging-insert-ppu-data": {
      "name": "insert-ppu-data (Staging)",
      "description": "Staging - PPU data insertion API",
      "tags": {
        "Environment": "staging"
      }
    }
  },
  "stages": {
    "staging-s3-url-v18/staging": {
      "rest_api_id": "staging-s3-url-v18",
      "stage_name": "staging",
      "deployment_id": null,
      "description": "Staging environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "staging-s3-url/staging": {
      "rest_api_id": "staging-s3-url",
      "stage_name": "staging",
      "deployment_id": null,
      "description": "Staging environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "staging-sync-clock-api/staging": {
      "rest_api_id": "staging-sync-clock-api",
      "stage_name": "staging",
      "deployment_id": null,
      "description": "Staging environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "staging-sw-update/staging": {
      "rest_api_id": "staging-sw-update",
      "stage_name": "staging",
      "deployment_id": null,
      "description": "Staging environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "staging-s3-url-2/staging": {
      "rest_api_id": "staging-s3-url-2",
      "stage_name": "staging",
      "deployment_id": null,
      "description": "Staging environment",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "staging-insert-ppu-data/staging": {
      "rest_api_id": "staging-insert-ppu-data",
      "stage_name": "staging",
      "deployment_id": null,
      "description": "Staging environment",
      "variables": null,
      "xray_tracing_enabled": false
    }
  }
}
