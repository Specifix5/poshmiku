#!/usr/bin/env bash
set -euo pipefail

# -- [ post-update.sh ] --
# -- [ installs fish plugins, patches prompt (remote transient func only), enforces TERM, loads bash envs via bass, installs fastfetch assets ] --

# -- [ config urls ] --
STARSHIP_URL="https://raw.githubusercontent.com/Specifix5/poshmiku/refs/heads/main/starship.toml"
FASTFETCH_CFG_URL="https://raw.githubusercontent.com/Specifix5/poshmiku/refs/heads/main/fastfetch-config.jsonc"
FASTFETCH_LOGO_URL="https://raw.githubusercontent.com/Specifix5/poshmiku/refs/heads/main/fastfetch-logo"
FISH_PROMPT_REMOTE_URL="https://raw.githubusercontent.com/Specifix5/poshmiku/refs/heads/main/__fish_prompt.fish"

# -- [ paths ] --
XDG_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

FISH_FUNCS_DIR="$XDG_CFG/fish/functions"
FISH_PROMPT_FILE="$FISH_FUNCS_DIR/__fish_prompt.fish"
FISH_CONFIG_FILE="$XDG_CFG/fish/config.fish"

STARSHIP_PATH="$XDG_CFG/starship.toml"

FASTFETCH_DIR="$XDG_CFG/fastfetch"
FASTFETCH_CFG_PATH="$FASTFETCH_DIR/config.jsonc"
FASTFETCH_LOGO_PATH="$FASTFETCH_DIR/logo"

TERM_VALUE="xterm-256color"

TERM_MARK_BEGIN="# >>> post-update TERM override >>>"
TERM_MARK_END="# <<< post-update TERM override <<<"

BASS_MARK_BEGIN="# >>> post-update bass bash_profile >>>"
BASS_MARK_END="# <<< post-update bass bash_profile <<<"

# -- [ helpers ] --
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local b="${f}.bak.$(date +%Y%m%d_%H%M%S)"
    cp -p "$f" "$b"
    echo "Backup: $b"
  fi
}

ensure_block_in_file() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local content="$4"

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : >"$file"

  if grep -Fq "$begin" "$file"; then
    return 0
  fi

  backup_file "$file"
  {
    echo ""
    echo "$begin"
    echo "$content"
    echo "$end"
    echo ""
  } >>"$file"
}

# -- [ extract function from a fish file ] --
# -- [ outputs the function block to stdout; returns non-zero if not found ] --
extract_fish_function() {
  local file="$1"
  local funcname="$2"
  awk -v fn="$funcname" '
    BEGIN { inside=0; found=0 }
    $0 ~ "^function[[:space:]]+" fn "([[:space:]]|$)" { inside=1; found=1 }
    inside { print }
    inside && $0 ~ "^end[[:space:]]*$" { exit }
    END { if (!found) exit 7 }
  ' "$file"
}

# -- [ replace function in target file with replacement block ] --
replace_fish_function_in_file() {
  local target="$1"
  local funcname="$2"
  local replacement_block_file="$3"

  awk -v fn="$funcname" -v repl="$replacement_block_file" '
    BEGIN { inside=0; replaced=0 }

    $0 ~ "^function[[:space:]]+" fn "([[:space:]]|$)" {
      inside=1; replaced=1
      while ((getline line < repl) > 0) print line
      close(repl)
      next
    }

    inside && $0 ~ "^end[[:space:]]*$" { inside=0; next }

    !inside { print }

    END { if (!replaced) exit 9 }
  ' "$target"
}

# -- [ preflight ] --
need_cmd curl
need_cmd fish
need_cmd awk
need_cmd mktemp
need_cmd grep

mkdir -p "$FISH_FUNCS_DIR"

# -- [ install fisher ] --
curl -fsSL "https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish" \
  -o "$FISH_FUNCS_DIR/fisher.fish"

# -- [ install fish plugins ] --
fish -lc 'source ~/.config/fish/functions/fisher.fish; fisher install jorgebucaran/fisher'
fish -lc 'source ~/.config/fish/functions/fisher.fish; fisher install zzhaolei/transient.fish'
fish -lc 'source ~/.config/fish/functions/fisher.fish; fisher install edc/bass'

# -- [ replace starship config ] --
mkdir -p "$(dirname "$STARSHIP_PATH")"
backup_file "$STARSHIP_PATH"
curl -fsSL "$STARSHIP_URL" -o "$STARSHIP_PATH"

# -- [ patch __transient_prompt_func only: download remote file, extract function, replace in local file ] --
if [[ -f "$FISH_PROMPT_FILE" ]]; then
  backup_file "$FISH_PROMPT_FILE"

  remote_tmp="$(mktemp)"
  func_tmp="$(mktemp)"
  out_tmp="$(mktemp)"

  curl -fsSL "$FISH_PROMPT_REMOTE_URL" -o "$remote_tmp"

  # -- [ quick sanity: ensure remote file contains the function header somewhere ] --
  if ! grep -Eq '^function[[:space:]]+__transient_prompt_func([[:space:]]|$)' "$remote_tmp"; then
    rm -f "$remote_tmp" "$func_tmp" "$out_tmp"
    echo "Error: remote file does not contain function __transient_prompt_func" >&2
    exit 1
  fi

  if ! extract_fish_function "$remote_tmp" "__transient_prompt_func" >"$func_tmp"; then
    rm -f "$remote_tmp" "$func_tmp" "$out_tmp"
    echo "Error: failed extracting __transient_prompt_func from remote __fish_prompt.fish" >&2
    exit 1
  fi

  if ! grep -Eq '^function[[:space:]]+__transient_prompt_func([[:space:]]|$)' "$FISH_PROMPT_FILE"; then
    rm -f "$remote_tmp" "$func_tmp" "$out_tmp"
    echo "Error: local file does not contain function __transient_prompt_func: $FISH_PROMPT_FILE" >&2
    exit 1
  fi

  if ! replace_fish_function_in_file "$FISH_PROMPT_FILE" "__transient_prompt_func" "$func_tmp" >"$out_tmp"; then
    rm -f "$remote_tmp" "$func_tmp" "$out_tmp"
    echo "Error: failed replacing __transient_prompt_func in local file: $FISH_PROMPT_FILE" >&2
    exit 1
  fi

  mv "$out_tmp" "$FISH_PROMPT_FILE"
  rm -f "$remote_tmp" "$func_tmp"
fi

# -- [ enforce TERM for ssh compatibility ] --
TERM_BLOCK=$(cat <<FISH
# Force a sane terminal type for SSH compatibility
if not set -q TERM; or not string match -rq '256color\$' -- \$TERM
    set -gx TERM $TERM_VALUE
end
FISH
)
ensure_block_in_file "$FISH_CONFIG_FILE" "$TERM_MARK_BEGIN" "$TERM_MARK_END" "$TERM_BLOCK"

# -- [ load bash envs into fish via bass ] --
BASS_BLOCK=$(cat <<'FISH'
# Import bash environment into fish (node, npm, sdkman, etc.)
if status is-interactive
    bass source ~/.bash_profile
end
FISH
)
ensure_block_in_file "$FISH_CONFIG_FILE" "$BASS_MARK_BEGIN" "$BASS_MARK_END" "$BASS_BLOCK"

# -- [ fastfetch config + logo ] --
mkdir -p "$FASTFETCH_DIR"

backup_file "$FASTFETCH_CFG_PATH"
curl -fsSL "$FASTFETCH_CFG_URL" -o "$FASTFETCH_CFG_PATH"

backup_file "$FASTFETCH_LOGO_PATH"
curl -fsSL "$FASTFETCH_LOGO_URL" -o "$FASTFETCH_LOGO_PATH"

# -- [ validate fish syntax ] --
[[ -f "$FISH_PROMPT_FILE" ]] && fish -n "$FISH_PROMPT_FILE"
fish -n "$FISH_CONFIG_FILE"

echo "post-update.sh completed successfully"
