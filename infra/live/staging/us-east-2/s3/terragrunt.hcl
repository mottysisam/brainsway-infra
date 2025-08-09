include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/s3" }
inputs = {
  "buckets": {
    "stsoftwareupdate-staging": {
      "versioning_enabled": true,
      "force_destroy": false,
      "tags": {
        "Environment": "staging"
      }
    },
    "steventlogs-staging": {
      "versioning_enabled": null,
      "force_destroy": false,
      "tags": {
        "Environment": "staging"
      }
    }
  }
}
