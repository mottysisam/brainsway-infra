# brainsway-infra scaffold (import-first)

This bundle contains:
- `infra/modules/*` minimal modules for **import-first** adoption
- `infra/live/<env>/us-east-2/*` Terragrunt stacks
- `import_maps/*.map` import address → AWS ID mappings derived from your export

## How to import (prod, read-only)

```bash
# Example for RDS (prod)
cd infra/live/prod/us-east-2/rds
terragrunt init -migrate-state -force-copy
while read -r addr id; do terragrunt import "$addr" "$id"; done < ../../../../../../import_maps/prod-rds.map
terragrunt plan  # expect minimal/no changes
```

Repeat for other stacks with their respective `.map` files.
