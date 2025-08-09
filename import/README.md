# Production Import (Read‑Only)

**Policy:** Prod is read‑only. Use these steps to adopt resources into state without changing AWS.

1. Model the real config in module inputs under `infra/live/prod/...`.
2. Use the `prod-import` workflow to generate `import.sh` or build your own map.
3. Align import addresses to your module naming (e.g., `module.network.aws_vpc.this`).
4. Run imports from the stack dir:

   ```bash
   terragrunt init -migrate-state -force-copy
   bash import.sh   # or: while read -r addr id; do terragrunt import "$addr" "$id"; done < prod.map
   terragrunt plan  # expect no changes
   ```