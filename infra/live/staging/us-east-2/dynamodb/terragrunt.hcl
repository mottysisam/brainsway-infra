include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/dynamodb" }
inputs = {
  "tables": {
    "event_log-staging": {
      "billing_mode": "PAY_PER_REQUEST",
      "hash_key": "date",
      "range_key": "device_id",
      "attributes": {
        "date": "S",
        "device_id": "S"
      },
      "stream_enabled": null,
      "ttl_attribute": null,
      "ttl_enabled": false,
      "tags": {
        "Environment": "staging"
      }
    },
    "sw_update-staging": {
      "billing_mode": "PAY_PER_REQUEST",
      "hash_key": "update_date",
      "range_key": "device_id",
      "attributes": {
        "device_id": "S",
        "update_date": "S"
      },
      "stream_enabled": null,
      "ttl_attribute": null,
      "ttl_enabled": false,
      "tags": {
        "Environment": "staging"
      }
    }
  }
}
