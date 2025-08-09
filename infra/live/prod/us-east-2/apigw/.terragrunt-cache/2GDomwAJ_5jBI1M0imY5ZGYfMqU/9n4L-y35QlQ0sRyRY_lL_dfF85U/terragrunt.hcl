include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/apigw_rest" }
inputs = {
  "apis": {
    "ndk8t3b961": {
      "name": "S3 URL V-1-8",
      "description": "to get presigned URL for S3 for version 1.8",
      "tags": {}
    },
    "9553ewljh9": {
      "name": "S3 URL",
      "description": "to get presigned URL for S3",
      "tags": {}
    },
    "lc0kt8b3p5": {
      "name": "sync_clock_api",
      "description": null,
      "tags": {}
    },
    "j1w31ky0s3": {
      "name": "sw update",
      "description": "call to lambda which handles sw update cases",
      "tags": {}
    },
    "pixwwabvy7": {
      "name": "S3 URL 2",
      "description": "to get presigned URL for S3",
      "tags": {}
    },
    "626pn9jbxh": {
      "name": "dev-insert-ppu-data",
      "description": null,
      "tags": {}
    }
  },
  "stages": {
    "ndk8t3b961/Prod": {
      "rest_api_id": "ndk8t3b961",
      "stage_name": "Prod",
      "deployment_id": "0wk65x",
      "description": "Prod on v1.8",
      "variables": null,
      "xray_tracing_enabled": true
    },
    "9553ewljh9/prod": {
      "rest_api_id": "9553ewljh9",
      "stage_name": "prod",
      "deployment_id": "0ls6p2",
      "description": "production",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "lc0kt8b3p5/dev": {
      "rest_api_id": "lc0kt8b3p5",
      "stage_name": "dev",
      "deployment_id": "pa4zjj",
      "description": null,
      "variables": null,
      "xray_tracing_enabled": false
    },
    "j1w31ky0s3/prod": {
      "rest_api_id": "j1w31ky0s3",
      "stage_name": "prod",
      "deployment_id": "0tlx4p",
      "description": "production",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "pixwwabvy7/prod": {
      "rest_api_id": "pixwwabvy7",
      "stage_name": "prod",
      "deployment_id": "0ms0vd",
      "description": "production",
      "variables": null,
      "xray_tracing_enabled": false
    },
    "626pn9jbxh/dev": {
      "rest_api_id": "626pn9jbxh",
      "stage_name": "dev",
      "deployment_id": "8iknhq",
      "description": null,
      "variables": null,
      "xray_tracing_enabled": false
    },
    "626pn9jbxh/prod": {
      "rest_api_id": "626pn9jbxh",
      "stage_name": "prod",
      "deployment_id": "8iknhq",
      "description": "production",
      "variables": null,
      "xray_tracing_enabled": false
    }
  }
}
