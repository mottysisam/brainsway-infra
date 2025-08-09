include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/dynamodb" }
inputs = {
  "tables": {
    "event_log": {
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
      "tags": {}
    },
    "sw_update": {
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
      "tags": {}
    }
  }
}
