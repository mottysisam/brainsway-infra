include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/apigw_rest" }
inputs = {
  "apis": {
    "staging-s3-url": {
      "name": "S3 URL Staging",
      "description": "Staging API for presigned S3 URLs",
      "tags": {}
    },
    "staging-sync-api": {
      "name": "Sync API Staging", 
      "description": "Staging API for sync operations",
      "tags": {}
    }
  },
  "stages": {}
}
