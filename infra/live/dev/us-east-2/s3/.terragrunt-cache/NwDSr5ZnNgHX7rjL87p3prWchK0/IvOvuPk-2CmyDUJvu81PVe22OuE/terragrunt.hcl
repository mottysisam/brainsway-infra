include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/s3" }
inputs = {
  "buckets": {
    "stsoftwareupdate-dev": {
      "versioning_enabled": true,
      "force_destroy": false,
      "tags": {
        "Environment": "dev"
      }
    },
    "steventlogs-dev": {
      "versioning_enabled": null,
      "force_destroy": false,
      "tags": {
        "Environment": "dev"
      }
    }
  }
}
