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
  }
}
