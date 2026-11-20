#!/bin/bash
set -e
export DSH_HOME="${DSH_HOME:-$HOME/.dsh}"

# Workspace fix: dsh resolves the default workspace via `xdg-user-dir DOCUMENTS`;
# minimal containers lack xdg-user-dirs, so provide a shim and the directory.
mkdir -p "$HOME/Documents" "$HOME/.config"
if ! grep -q "XDG_DOCUMENTS_DIR" "$HOME/.config/user-dirs.dirs" 2>/dev/null; then
  echo 'XDG_DOCUMENTS_DIR="$HOME/Documents"' >> "$HOME/.config/user-dirs.dirs"
fi
if ! command -v xdg-user-dir >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\nif [ "$1" = "DOCUMENTS" ]; then echo "$HOME/Documents"; else echo "$HOME"; fi\n' > "$HOME/.local/bin/xdg-user-dir"
  chmod +x "$HOME/.local/bin/xdg-user-dir"
  export PATH="$HOME/.local/bin:$PATH"
fi

# Preconfigure the 100MilionSeek provider (key comes from the SEEK_API_KEY env var).
PATCH="$DSH_HOME/profiles/web/cordis.patch.yml"
if [ ! -f "$PATCH" ]; then
  mkdir -p "$(dirname "$PATCH")"
  cat > "$PATCH" <<'YAML'
- id: llm-pi-ai
  config:
    providers:
      exaone:
        apiKeyEnv: EXAONE_API_KEY
        api: openai-completions
        baseURL: https://api.exaone.ai/v1
        compat:
          supportsDeveloperRole: false
          maxTokensField: max_tokens
        models:
          - id: k-exaone_v2.5
            contextWindow: 512000
YAML
fi

ARGS=(web --no-open --host 127.0.0.1 --port 3090)
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  ARGS+=(--trusted-host "$RAILWAY_PUBLIC_DOMAIN" --public-url "https://$RAILWAY_PUBLIC_DOMAIN")
fi
./node_modules/.bin/dsh "${ARGS[@]}" &
DSH_PID=$!
node proxy.js &
PROXY_PID=$!
wait -n $DSH_PID $PROXY_PID
