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
  }
}
