/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_TITLE: string
  readonly VITE_GITHUB_TOKEN: string
  readonly VITE_REPO_OWNER: string
  readonly VITE_REPO_NAME: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}