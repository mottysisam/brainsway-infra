include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/s3" }
inputs = {
  "buckets": {
    "stsoftwareupdate": {
      "versioning_enabled": true,
      "force_destroy": false,
      "tags": {}
    },
    "steventlogs": {
      "versioning_enabled": null,
      "force_destroy": false,
      "tags": {}
    }
  }
}
