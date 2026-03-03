#!/usr/bin/env bash
set -euo pipefail

umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OPENSSL_PROFILE_DIR="$SCRIPT_DIR/openssl"

DEFAULT_CA_DIR="$HOME/.ptak/internal-ca"
CA_DIR="${PTAK_CA_DIR:-$DEFAULT_CA_DIR}"
if [[ "$CA_DIR" == ~* ]]; then
  CA_DIR="$HOME${CA_DIR:1}"
fi
CA_PASS_FILE="${PTAK_CA_PASS_FILE:-$CA_DIR/.ca-passphrase}"

ROOT_KEY="$CA_DIR/root/private/root-ca.key.pem"
ROOT_CERT="$CA_DIR/root/certs/root-ca.crt"
ISSUING_KEY="$CA_DIR/issuing/private/issuing-ca.key.pem"
ISSUING_CERT="$CA_DIR/issuing/certs/issuing-ca.crt"
ONLINE_KEY="$CA_DIR/online/private/fts-online-ca.key.pem"
ONLINE_CERT="$CA_DIR/online/certs/fts-online-ca.crt"
PUBLIC_DIR="$CA_DIR/public"
PUBLIC_CHAIN="$PUBLIC_DIR/ca-chain.crt"
PUBLIC_CRL="$PUBLIC_DIR/ca.crl.pem"
PUBLIC_ONLINE_CRL="$PUBLIC_DIR/ca-online.crl.pem"

TMP_FILES=()

cleanup_tmp_files() {
  local f
  for f in "${TMP_FILES[@]:-}"; do
    if [[ -n "$f" && -f "$f" ]]; then
      rm -f "$f"
    fi
  done
}
trap cleanup_tmp_files EXIT

usage() {
  cat <<'USAGE'
Usage: ./scripts/ptak-ca.sh <command> [options]

Commands:
  init [--force]
  issue-server <name> --cn <cn> --san <csv> --out <dir> [--rsa-bits <bits>] [--days <days>] [--ca issuing|online] [--force]
  issue-client <name> --cn <cn> [--san <csv>] --out <dir> [--rsa-bits <bits>] [--days <days>] [--ca issuing|online] [--p12] [--p12-password-file <path>] [--p12-password-env <ENV>] [--no-p12-password] [--force]
  provision [--fts-cn <cn>] [--fts-san <csv>] [--mqtt-cn <cn>] [--mqtt-san <csv>] [--wintak-client-name <name>] [--wintak-client-cn <cn>] [--wintak-client-san <csv>] [--wintak-p12-password-file <path>] [--wintak-p12-password-env <ENV>] [--wintak-p12-password <password>] [--no-p12-password] [--allow-online-ca-key] [--rsa-bits <bits>] [--days <days>] [--skip-mqtt] [--skip-fts] [--skip-wintak]
  revoke <cert-name-or-path> [--ca issuing|online] [--reason <reason>]
  crl [--ca issuing|online]
  backup [--backup-password-file <path>] [--include-passphrase]
  show

Environment:
  PTAK_CA_DIR            Override CA state directory (default: $HOME/.ptak/internal-ca)
  PTAK_CA_PASS_FILE      Override CA passphrase file path (default: $PTAK_CA_DIR/.ca-passphrase)
  PTAK_CA_PASS           Optional passphrase override for CA key decrypt/encrypt operations
USAGE
}

log() {
  printf '[ptak-ca] %s\n' "$*"
}

warn() {
  printf '[ptak-ca] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[ptak-ca] ERROR: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

timestamp() {
  date -u +"%Y%m%d-%H%M%S"
}

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

add_tmp_file() {
  local p="$1"
  TMP_FILES+=("$p")
}

make_temp_file() {
  local f
  f="$(mktemp)"
  add_tmp_file "$f"
  printf '%s' "$f"
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

ensure_repo_symlink() {
  local link="$REPO_ROOT/secrets/internal-ca"
  mkdir -p "$REPO_ROOT/secrets"

  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    if [[ "$current" != "$CA_DIR" ]]; then
      ln -sfn "$CA_DIR" "$link"
      log "Updated symlink: secrets/internal-ca -> $CA_DIR"
    fi
    return
  fi

  if [[ -e "$link" ]]; then
    die "Expected $link to be a symlink, but a file/directory exists. Move it and rerun init."
  fi

  ln -s "$CA_DIR" "$link"
  log "Created symlink: secrets/internal-ca -> $CA_DIR"
}

ensure_ca_pass_file() {
  mkdir -p "$(dirname "$CA_PASS_FILE")"

  if [[ -f "$CA_PASS_FILE" ]]; then
    chmod 600 "$CA_PASS_FILE"
    return
  fi

  if [[ -n "${PTAK_CA_PASS:-}" ]]; then
    printf '%s' "$PTAK_CA_PASS" >"$CA_PASS_FILE"
  else
    openssl rand -hex 48 >"$CA_PASS_FILE"
  fi
  chmod 600 "$CA_PASS_FILE"
  log "Created CA passphrase file: $CA_PASS_FILE"
}

get_ca_passin() {
  if [[ -n "${PTAK_CA_PASS:-}" ]]; then
    printf 'pass:%s' "$PTAK_CA_PASS"
    return
  fi
  [[ -f "$CA_PASS_FILE" ]] || die "CA passphrase file not found: $CA_PASS_FILE"
  printf 'file:%s' "$CA_PASS_FILE"
}

get_ca_passout() {
  if [[ -n "${PTAK_CA_PASS:-}" ]]; then
    printf 'pass:%s' "$PTAK_CA_PASS"
    return
  fi
  [[ -f "$CA_PASS_FILE" ]] || die "CA passphrase file not found: $CA_PASS_FILE"
  printf 'file:%s' "$CA_PASS_FILE"
}

normalize_san_csv() {
  local raw="$1"
  local -a items=()
  local token

  IFS=',' read -r -a items <<<"$raw"

  local -a normalized=()
  for token in "${items[@]}"; do
    token="$(trim "$token")"
    [[ -n "$token" ]] || continue

    if [[ "$token" =~ ^DNS: ]] || [[ "$token" =~ ^IP: ]]; then
      normalized+=("$token")
    elif [[ "$token" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      normalized+=("IP:$token")
    else
      normalized+=("DNS:$token")
    fi
  done

  if [[ ${#normalized[@]} -eq 0 ]]; then
    printf ''
    return
  fi

  local joined
  joined="$(IFS=,; printf '%s' "${normalized[*]}")"
  printf '%s' "$joined"
}

validate_rsa_bits() {
  local bits="$1"
  [[ "$bits" =~ ^[0-9]+$ ]] || die "RSA bits must be numeric (got: $bits)"
  (( bits >= 2048 )) || die "RSA bits must be >= 2048"
}

ca_cert_filename() {
  local ca_name="$1"
  case "$ca_name" in
    issuing) printf 'issuing-ca.crt' ;;
    online) printf 'fts-online-ca.crt' ;;
    *) die "Unknown CA name: $ca_name" ;;
  esac
}

ca_key_filename() {
  local ca_name="$1"
  case "$ca_name" in
    issuing) printf 'issuing-ca.key.pem' ;;
    online) printf 'fts-online-ca.key.pem' ;;
    *) die "Unknown CA name: $ca_name" ;;
  esac
}

ca_cert_path() {
  local ca_name="$1"
  printf '%s/%s/certs/%s' "$CA_DIR" "$ca_name" "$(ca_cert_filename "$ca_name")"
}

ca_key_path() {
  local ca_name="$1"
  printf '%s/%s/private/%s' "$CA_DIR" "$ca_name" "$(ca_key_filename "$ca_name")"
}

ensure_ca_db() {
  local ca_name="$1"
  local dir="$CA_DIR/$ca_name/db"
  mkdir -p "$dir/newcerts"
  touch "$dir/index.txt"
  [[ -s "$dir/serial" ]] || printf '1000\n' >"$dir/serial"
  [[ -s "$dir/crlnumber" ]] || printf '1000\n' >"$dir/crlnumber"
  if [[ ! -f "$dir/index.txt.attr" ]]; then
    printf 'unique_subject = no\n' >"$dir/index.txt.attr"
  fi
}

render_root_config() {
  local out="$1"
  cp "$OPENSSL_PROFILE_DIR/root-ca.cnf" "$out"
}

render_issuing_config() {
  local ca_name="$1"
  local out="$2"
  local ca_path="$CA_DIR/$ca_name"
  local cert_file
  cert_file="$(ca_cert_filename "$ca_name")"
  local key_file
  key_file="$(ca_key_filename "$ca_name")"
  local crl_path="$PUBLIC_CRL"

  if [[ "$ca_name" == "online" ]]; then
    crl_path="$PUBLIC_ONLINE_CRL"
  fi

  sed \
    -e "s|__CA_PATH__|$(escape_sed "$ca_path")|g" \
    -e "s|__CA_CERT_FILE__|$(escape_sed "$cert_file")|g" \
    -e "s|__CA_KEY_FILE__|$(escape_sed "$key_file")|g" \
    -e "s|__PUBLIC_CRL_PATH__|$(escape_sed "$crl_path")|g" \
    "$OPENSSL_PROFILE_DIR/issuing-ca.cnf" >"$out"
}

refresh_public_material() {
  mkdir -p "$PUBLIC_DIR"
  cp "$ROOT_CERT" "$PUBLIC_DIR/root-ca.crt"
  cp "$ISSUING_CERT" "$PUBLIC_DIR/issuing-ca.crt"
  cat "$ISSUING_CERT" "$ROOT_CERT" >"$PUBLIC_CHAIN"

  if [[ -f "$ONLINE_CERT" ]]; then
    cat "$ONLINE_CERT" "$ISSUING_CERT" "$ROOT_CERT" >"$PUBLIC_DIR/online-ca-chain.crt"
    cp "$ONLINE_CERT" "$PUBLIC_DIR/fts-online-ca.crt"
  fi
}

print_cert_fingerprint() {
  local label="$1"
  local cert="$2"

  if [[ ! -f "$cert" ]]; then
    warn "$label certificate missing: $cert"
    return
  fi

  local fp subj
  fp="$(openssl x509 -in "$cert" -noout -fingerprint -sha256 | cut -d= -f2-)"
  subj="$(openssl x509 -in "$cert" -noout -subject | sed 's/^subject=//')"
  printf '%s\n' "$label:"
  printf '  Subject: %s\n' "$subj"
  printf '  SHA256:  %s\n' "$fp"
}

create_root_ca_if_needed() {
  local force="$1"
  local root_cn="${PTAK_ROOT_CN:-pTAK Root CA}"
  local root_days="${PTAK_ROOT_DAYS:-3650}"

  mkdir -p "$CA_DIR/root/private" "$CA_DIR/root/certs"
  chmod 700 "$CA_DIR/root/private"

  if [[ -f "$ROOT_KEY" && -f "$ROOT_CERT" && "$force" -eq 0 ]]; then
    return
  fi

  local root_cfg
  root_cfg="$(make_temp_file)"
  render_root_config "$root_cfg"

  openssl req -new -x509 -sha256 -days "$root_days" \
    -config "$root_cfg" -extensions v3_root_ca \
    -subj "/CN=$root_cn" \
    -keyout "$ROOT_KEY" \
    -out "$ROOT_CERT" \
    -passout "$(get_ca_passout)"

  chmod 600 "$ROOT_KEY"
  log "Created root CA certificate: $ROOT_CERT"
}

create_intermediate_ca_if_needed() {
  local ca_name="$1"
  local force="$2"
  local cn="$3"
  local days="$4"

  local key_path cert_path ca_dir
  key_path="$(ca_key_path "$ca_name")"
  cert_path="$(ca_cert_path "$ca_name")"
  ca_dir="$CA_DIR/$ca_name"

  mkdir -p "$ca_dir/private" "$ca_dir/certs"
  chmod 700 "$ca_dir/private"
  ensure_ca_db "$ca_name"

  if [[ -f "$key_path" && -f "$cert_path" && "$force" -eq 0 ]]; then
    return
  fi

  local csr
  csr="$(make_temp_file)"
  local root_cfg
  root_cfg="$(make_temp_file)"
  render_root_config "$root_cfg"

  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
    -aes-256-cbc -pass "$(get_ca_passout)" -out "$key_path"
  chmod 600 "$key_path"

  openssl req -new -sha256 \
    -key "$key_path" -passin "$(get_ca_passin)" \
    -subj "/CN=$cn" \
    -out "$csr"

  openssl x509 -req -sha256 -days "$days" \
    -in "$csr" \
    -CA "$ROOT_CERT" \
    -CAkey "$ROOT_KEY" \
    -CAcreateserial \
    -passin "$(get_ca_passin)" \
    -extfile "$root_cfg" -extensions v3_issuing_ca \
    -out "$cert_path"

  log "Created $ca_name intermediate CA certificate: $cert_path"
}

init_layout_dirs() {
  mkdir -p "$CA_DIR" "$CA_DIR/backups" "$CA_DIR/issued/server" "$CA_DIR/issued/client" "$PUBLIC_DIR"
}

init_impl() {
  local force="$1"
  need_command openssl
  init_layout_dirs
  ensure_ca_pass_file

  if [[ "$force" -eq 1 ]]; then
    local stamp backup_dir
    stamp="$(timestamp)"
    backup_dir="$CA_DIR/backups/init-force-$stamp"
    mkdir -p "$backup_dir"

    local d
    for d in root issuing online issued public; do
      if [[ -e "$CA_DIR/$d" ]]; then
        mv "$CA_DIR/$d" "$backup_dir/$d"
      fi
    done

    mkdir -p "$CA_DIR/issued/server" "$CA_DIR/issued/client" "$PUBLIC_DIR"
    log "Forced init: previous CA state moved to $backup_dir"
  fi

  create_root_ca_if_needed 0
  create_intermediate_ca_if_needed "issuing" 0 "${PTAK_ISSUING_CN:-pTAK Issuing CA}" "${PTAK_ISSUING_DAYS:-1825}"
  refresh_public_material
  ensure_repo_symlink

  if [[ ! -f "$PUBLIC_CRL" ]]; then
    generate_crl "issuing"
  fi

  print_cert_fingerprint "Root CA" "$ROOT_CERT"
  print_cert_fingerprint "Issuing CA" "$ISSUING_CERT"

  log "CA initialized at $CA_DIR"
}

ensure_initialized() {
  if [[ ! -f "$ROOT_CERT" || ! -f "$ISSUING_CERT" ]]; then
    log "CA state missing; initializing..."
    init_impl 0
  fi
}

ensure_online_ca() {
  ensure_initialized
  create_intermediate_ca_if_needed "online" 0 "${PTAK_ONLINE_ISSUING_CN:-pTAK FTS Online Issuing CA}" "${PTAK_ONLINE_ISSUING_DAYS:-825}"
  refresh_public_material

  local online_cfg
  online_cfg="$(make_temp_file)"
  render_issuing_config "online" "$online_cfg"

  if [[ ! -f "$PUBLIC_ONLINE_CRL" ]]; then
    openssl ca -config "$online_cfg" -gencrl -out "$PUBLIC_ONLINE_CRL" -passin "$(get_ca_passin)"
  fi
}

chain_for_ca() {
  local ca_name="$1"
  case "$ca_name" in
    issuing)
      printf '%s' "$PUBLIC_CHAIN"
      ;;
    online)
      printf '%s' "$PUBLIC_DIR/online-ca-chain.crt"
      ;;
    *)
      die "Unknown CA selection: $ca_name"
      ;;
  esac
}

issue_leaf() {
  local ca_name="$1"
  local leaf_type="$2"
  local name="$3"
  local cn="$4"
  local san_csv="$5"
  local out_dir="$6"
  local rsa_bits="$7"
  local days="$8"
  local force="$9"

  validate_rsa_bits "$rsa_bits"
  ensure_initialized
  [[ "$ca_name" == "issuing" || "$ca_name" == "online" ]] || die "Invalid CA: $ca_name"
  if [[ "$ca_name" == "online" ]]; then
    ensure_online_ca
  fi

  mkdir -p "$out_dir"
  local key_file="$out_dir/$name.key"
  local csr_file="$out_dir/$name.csr"
  local crt_file="$out_dir/$name.crt"
  local chain_file="$out_dir/$name.chain.crt"

  if [[ "$force" -eq 0 ]]; then
    if [[ -f "$key_file" || -f "$csr_file" || -f "$crt_file" || -f "$chain_file" ]]; then
      die "Output already exists for '$name' under $out_dir. Re-run with --force to overwrite files."
    fi
  else
    rm -f "$key_file" "$csr_file" "$crt_file" "$chain_file"
  fi

  openssl genpkey -algorithm RSA -pkeyopt "rsa_keygen_bits:$rsa_bits" -out "$key_file"
  chmod 600 "$key_file"

  openssl req -new -sha256 -key "$key_file" -subj "/CN=$cn" -out "$csr_file"

  local normalized_san=""
  normalized_san="$(normalize_san_csv "$san_csv")"

  local ext_file ext_section
  case "$leaf_type" in
    server)
      [[ -n "$normalized_san" ]] || die "Server certificate requires --san"
      ext_file="$OPENSSL_PROFILE_DIR/server-leaf.cnf"
      ext_section="server_cert"
      export PTAK_SAN="$normalized_san"
      ;;
    client)
      ext_file="$OPENSSL_PROFILE_DIR/client-leaf.cnf"
      if [[ -n "$normalized_san" ]]; then
        ext_section="client_cert"
        export PTAK_SAN="$normalized_san"
      else
        ext_section="client_cert_nosan"
        unset PTAK_SAN || true
      fi
      ;;
    *)
      die "Unknown leaf type: $leaf_type"
      ;;
  esac

  local ca_cfg
  ca_cfg="$(make_temp_file)"
  render_issuing_config "$ca_name" "$ca_cfg"

  openssl ca -batch -config "$ca_cfg" \
    -extensions "$ext_section" \
    -extfile "$ext_file" \
    -days "$days" \
    -notext \
    -in "$csr_file" \
    -out "$crt_file" \
    -passin "$(get_ca_passin)"

  local chain_source
  chain_source="$(chain_for_ca "$ca_name")"
  [[ -f "$chain_source" ]] || die "Missing chain file for CA '$ca_name': $chain_source"
  cat "$crt_file" "$chain_source" >"$chain_file"

  chmod 644 "$crt_file" "$chain_file"
}

prompt_secret_twice() {
  local prompt="$1"
  local p1 p2

  if [[ ! -t 0 ]]; then
    die "Cannot prompt for secrets in non-interactive mode. Provide a password file/env option."
  fi

  read -r -s -p "$prompt" p1
  printf '\n' >&2
  read -r -s -p "Confirm: " p2
  printf '\n' >&2

  [[ "$p1" == "$p2" ]] || die "Secret values did not match"
  [[ -n "$p1" ]] || die "Secret cannot be empty"
  printf '%s' "$p1"
}

resolve_secret_source() {
  local inline_value="$1"
  local file_path="$2"
  local env_name="$3"
  local no_password="$4"
  local prompt_label="$5"

  if [[ "$no_password" -eq 1 ]]; then
    printf 'pass:'
    return
  fi

  if [[ -n "$file_path" ]]; then
    [[ -f "$file_path" ]] || die "Password file not found: $file_path"
    printf 'file:%s' "$file_path"
    return
  fi

  if [[ -n "$env_name" ]]; then
    local env_value="${!env_name:-}"
    [[ -n "$env_value" ]] || die "Environment variable '$env_name' is empty or not set"
    local tmp
    tmp="$(make_temp_file)"
    printf '%s' "$env_value" >"$tmp"
    chmod 600 "$tmp"
    printf 'file:%s' "$tmp"
    return
  fi

  if [[ -n "$inline_value" ]]; then
    local tmp_inline
    tmp_inline="$(make_temp_file)"
    printf '%s' "$inline_value" >"$tmp_inline"
    chmod 600 "$tmp_inline"
    printf 'file:%s' "$tmp_inline"
    return
  fi

  local prompted
  prompted="$(prompt_secret_twice "$prompt_label")"
  local tmp_prompt
  tmp_prompt="$(make_temp_file)"
  printf '%s' "$prompted" >"$tmp_prompt"
  chmod 600 "$tmp_prompt"
  printf 'file:%s' "$tmp_prompt"
}

export_client_p12() {
  local name="$1"
  local cert_file="$2"
  local key_file="$3"
  local out_file="$4"
  local inline_pass="$5"
  local pass_file="$6"
  local pass_env="$7"
  local no_password="$8"

  local passout
  passout="$(resolve_secret_source "$inline_pass" "$pass_file" "$pass_env" "$no_password" "Enter PKCS#12 export password: ")"

  openssl pkcs12 -export -legacy \
    -name "$name" \
    -inkey "$key_file" \
    -in "$cert_file" \
    -certfile "$PUBLIC_CHAIN" \
    -out "$out_file" \
    -passout "$passout"
}

generate_crl() {
  local ca_name="$1"

  if [[ "$ca_name" == "online" ]]; then
    ensure_online_ca
  else
    ensure_initialized
  fi

  local cfg
  cfg="$(make_temp_file)"
  render_issuing_config "$ca_name" "$cfg"

  local out_path="$PUBLIC_CRL"
  if [[ "$ca_name" == "online" ]]; then
    out_path="$PUBLIC_ONLINE_CRL"
  fi

  openssl ca -config "$cfg" -gencrl -out "$out_path" -passin "$(get_ca_passin)"
  chmod 644 "$out_path"

  log "Generated CRL: $out_path"
}

backup_runtime_dirs() {
  local include_mqtt="$1"
  local include_fts="$2"
  local stamp="$3"

  local backup_dir="$REPO_ROOT/backups/pki-provision-$stamp"
  local copied=0

  mkdir -p "$REPO_ROOT/backups"

  if [[ "$include_mqtt" -eq 1 && -d "$REPO_ROOT/mqtt-certs" ]]; then
    mkdir -p "$backup_dir"
    cp -a "$REPO_ROOT/mqtt-certs" "$backup_dir/"
    copied=1
  fi

  if [[ "$include_fts" -eq 1 && -d "$REPO_ROOT/fts-certs" ]]; then
    mkdir -p "$backup_dir"
    cp -a "$REPO_ROOT/fts-certs" "$backup_dir/"
    copied=1
  fi

  if [[ "$copied" -eq 1 ]]; then
    log "Backed up runtime certs to: $backup_dir"
  else
    log "No existing runtime cert directories found; skipping backup copy"
  fi
}

resolve_cert_path() {
  local id="$1"

  if [[ -f "$id" ]]; then
    printf '%s' "$id"
    return
  fi

  local candidate
  for candidate in \
    "$CA_DIR/issued/server/$id.crt" \
    "$CA_DIR/issued/client/$id.crt" \
    "$REPO_ROOT/fts-certs/$id.crt" \
    "$REPO_ROOT/mqtt-certs/$id.crt"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return
    fi
  done

  die "Could not resolve certificate by name/path: $id"
}

cmd_init() {
  local force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option for init: $1"
        ;;
    esac
  done

  init_impl "$force"
}

cmd_issue_server() {
  [[ $# -ge 1 ]] || die "Usage: issue-server <name> --cn <cn> --san <csv> --out <dir> [options]"

  local name="$1"
  shift

  local cn=""
  local san=""
  local out_dir=""
  local rsa_bits=2048
  local days=825
  local ca_name="issuing"
  local force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cn)
        cn="$2"
        shift 2
        ;;
      --san)
        san="$2"
        shift 2
        ;;
      --out)
        out_dir="$2"
        shift 2
        ;;
      --rsa-bits)
        rsa_bits="$2"
        shift 2
        ;;
      --days)
        days="$2"
        shift 2
        ;;
      --ca)
        ca_name="$2"
        shift 2
        ;;
      --force)
        force=1
        shift
        ;;
      *)
        die "Unknown issue-server option: $1"
        ;;
    esac
  done

  [[ -n "$cn" ]] || die "--cn is required"
  [[ -n "$san" ]] || die "--san is required"
  [[ -n "$out_dir" ]] || die "--out is required"

  issue_leaf "$ca_name" "server" "$name" "$cn" "$san" "$out_dir" "$rsa_bits" "$days" "$force"
  log "Issued server cert: $out_dir/$name.crt"
}

cmd_issue_client() {
  [[ $# -ge 1 ]] || die "Usage: issue-client <name> --cn <cn> [--san <csv>] --out <dir> [options]"

  local name="$1"
  shift

  local cn=""
  local san=""
  local out_dir=""
  local rsa_bits=2048
  local days=825
  local ca_name="issuing"
  local force=0
  local generate_p12=0
  local p12_password_file=""
  local p12_password_env=""
  local p12_inline_password=""
  local no_p12_password=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cn)
        cn="$2"
        shift 2
        ;;
      --san)
        san="$2"
        shift 2
        ;;
      --out)
        out_dir="$2"
        shift 2
        ;;
      --rsa-bits)
        rsa_bits="$2"
        shift 2
        ;;
      --days)
        days="$2"
        shift 2
        ;;
      --ca)
        ca_name="$2"
        shift 2
        ;;
      --p12)
        generate_p12=1
        shift
        ;;
      --p12-password-file)
        p12_password_file="$2"
        shift 2
        ;;
      --p12-password-env)
        p12_password_env="$2"
        shift 2
        ;;
      --p12-password)
        p12_inline_password="$2"
        shift 2
        ;;
      --no-p12-password)
        no_p12_password=1
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      *)
        die "Unknown issue-client option: $1"
        ;;
    esac
  done

  [[ -n "$cn" ]] || die "--cn is required"
  [[ -n "$out_dir" ]] || die "--out is required"

  issue_leaf "$ca_name" "client" "$name" "$cn" "$san" "$out_dir" "$rsa_bits" "$days" "$force"
  log "Issued client cert: $out_dir/$name.crt"

  if [[ "$generate_p12" -eq 1 ]]; then
    local p12_path="$out_dir/$name.p12"
    export_client_p12 "$name" "$out_dir/$name.crt" "$out_dir/$name.key" "$p12_path" \
      "$p12_inline_password" "$p12_password_file" "$p12_password_env" "$no_p12_password"
    chmod 600 "$p12_path"
    log "Exported PKCS#12 bundle: $p12_path"
  fi
}

cmd_provision() {
  local fts_cn="freetakserver"
  local fts_san="freetakserver,localhost,127.0.0.1"
  local mqtt_cn="mqtt-broker"
  local mqtt_san="mqtt-broker,mosquitto,localhost,127.0.0.1,marzocchi-tech.ewe-mulley.ts.net"
  local wintak_client_name="WinTAK-Paul"
  local wintak_client_cn="WinTAK-Paul"
  local wintak_client_san="WinTAK-Paul"
  local allow_online_ca_key=0
  local rsa_bits=2048
  local days=825
  local do_mqtt=1
  local do_fts=1
  local do_wintak=1
  local wintak_p12_password_file=""
  local wintak_p12_password_env=""
  local wintak_p12_inline_password=""
  local no_p12_password=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fts-cn)
        fts_cn="$2"
        shift 2
        ;;
      --fts-san)
        fts_san="$2"
        shift 2
        ;;
      --mqtt-cn)
        mqtt_cn="$2"
        shift 2
        ;;
      --mqtt-san)
        mqtt_san="$2"
        shift 2
        ;;
      --wintak-client-name)
        wintak_client_name="$2"
        shift 2
        ;;
      --wintak-client-cn)
        wintak_client_cn="$2"
        shift 2
        ;;
      --wintak-client-san)
        wintak_client_san="$2"
        shift 2
        ;;
      --wintak-p12-password-file)
        wintak_p12_password_file="$2"
        shift 2
        ;;
      --wintak-p12-password-env)
        wintak_p12_password_env="$2"
        shift 2
        ;;
      --wintak-p12-password)
        wintak_p12_inline_password="$2"
        shift 2
        ;;
      --no-p12-password)
        no_p12_password=1
        shift
        ;;
      --allow-online-ca-key)
        allow_online_ca_key=1
        shift
        ;;
      --rsa-bits)
        rsa_bits="$2"
        shift 2
        ;;
      --days)
        days="$2"
        shift 2
        ;;
      --skip-mqtt)
        do_mqtt=0
        shift
        ;;
      --skip-fts)
        do_fts=0
        shift
        ;;
      --skip-wintak)
        do_wintak=0
        shift
        ;;
      *)
        die "Unknown provision option: $1"
        ;;
    esac
  done

  validate_rsa_bits "$rsa_bits"

  init_impl 0

  local stamp
  stamp="$(timestamp)"
  backup_runtime_dirs "$do_mqtt" "$do_fts" "$stamp"

  mkdir -p "$REPO_ROOT/mqtt-certs" "$REPO_ROOT/fts-certs"

  if [[ "$do_mqtt" -eq 1 ]]; then
    issue_leaf "issuing" "server" "mqtt-server" "$mqtt_cn" "$mqtt_san" "$CA_DIR/issued/server" "$rsa_bits" "$days" 1

    cp "$PUBLIC_DIR/root-ca.crt" "$REPO_ROOT/mqtt-certs/ca.crt"
    cp "$CA_DIR/issued/server/mqtt-server.crt" "$REPO_ROOT/mqtt-certs/server.crt"
    cp "$CA_DIR/issued/server/mqtt-server.key" "$REPO_ROOT/mqtt-certs/server.key"
    chmod 600 "$REPO_ROOT/mqtt-certs/server.key"
    chmod 644 "$REPO_ROOT/mqtt-certs/ca.crt" "$REPO_ROOT/mqtt-certs/server.crt"

    log "Provisioned MQTT compatibility files under mqtt-certs/"
  fi

  if [[ "$do_fts" -eq 1 ]]; then
    issue_leaf "issuing" "server" "fts-server" "$fts_cn" "$fts_san" "$CA_DIR/issued/server" "$rsa_bits" "$days" 1

    cp "$CA_DIR/issued/server/fts-server.crt" "$REPO_ROOT/fts-certs/server.crt"
    cp "$CA_DIR/issued/server/fts-server.key" "$REPO_ROOT/fts-certs/server.key"
    cat "$CA_DIR/issued/server/fts-server.crt" "$PUBLIC_CHAIN" >"$REPO_ROOT/fts-certs/server.pem"

    cp "$PUBLIC_DIR/root-ca.crt" "$REPO_ROOT/fts-certs/ca.crt"
    cp "$PUBLIC_CHAIN" "$REPO_ROOT/fts-certs/ca.pem"

    if [[ "$allow_online_ca_key" -eq 1 ]]; then
      ensure_online_ca
      warn "Dangerous mode enabled: copying dedicated online CA key into fts-certs/ca.key"
      cp "$ONLINE_KEY" "$REPO_ROOT/fts-certs/ca.key"
      cat "$ONLINE_CERT" "$ISSUING_CERT" "$ROOT_CERT" >"$REPO_ROOT/fts-certs/ca.pem"
      chmod 600 "$REPO_ROOT/fts-certs/ca.key"
    else
      rm -f "$REPO_ROOT/fts-certs/ca.key"
    fi

    chmod 600 "$REPO_ROOT/fts-certs/server.key"
    chmod 644 "$REPO_ROOT/fts-certs/server.crt" "$REPO_ROOT/fts-certs/server.pem" "$REPO_ROOT/fts-certs/ca.crt" "$REPO_ROOT/fts-certs/ca.pem"

    log "Provisioned FreeTAK compatibility files under fts-certs/"
  fi

  if [[ "$do_wintak" -eq 1 ]]; then
    issue_leaf "issuing" "client" "$wintak_client_name" "$wintak_client_cn" "$wintak_client_san" "$CA_DIR/issued/client" "$rsa_bits" "$days" 1

    cp "$CA_DIR/issued/client/$wintak_client_name.crt" "$REPO_ROOT/fts-certs/$wintak_client_name.crt"
    cp "$CA_DIR/issued/client/$wintak_client_name.key" "$REPO_ROOT/fts-certs/$wintak_client_name.key"

    local wintak_p12_path="$REPO_ROOT/fts-certs/$wintak_client_name.p12"
    export_client_p12 "$wintak_client_name" \
      "$CA_DIR/issued/client/$wintak_client_name.crt" \
      "$CA_DIR/issued/client/$wintak_client_name.key" \
      "$wintak_p12_path" \
      "$wintak_p12_inline_password" "$wintak_p12_password_file" "$wintak_p12_password_env" "$no_p12_password"

    cp "$CA_DIR/issued/client/$wintak_client_name.crt" "$REPO_ROOT/fts-certs/client.pem"
    cp "$CA_DIR/issued/client/$wintak_client_name.key" "$REPO_ROOT/fts-certs/client.key"

    chmod 600 "$REPO_ROOT/fts-certs/$wintak_client_name.key" "$REPO_ROOT/fts-certs/client.key" "$wintak_p12_path"
    chmod 644 "$REPO_ROOT/fts-certs/$wintak_client_name.crt" "$REPO_ROOT/fts-certs/client.pem"

    log "Provisioned WinTAK/client compatibility files under fts-certs/"
  fi

  log "Provision complete"
}

cmd_revoke() {
  [[ $# -ge 1 ]] || die "Usage: revoke <cert-name-or-path> [--ca issuing|online] [--reason <reason>]"

  local id="$1"
  shift

  local ca_name="issuing"
  local reason="unspecified"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ca)
        ca_name="$2"
        shift 2
        ;;
      --reason)
        reason="$2"
        shift 2
        ;;
      *)
        die "Unknown revoke option: $1"
        ;;
    esac
  done

  if [[ "$ca_name" == "online" ]]; then
    ensure_online_ca
  else
    ensure_initialized
  fi

  local cert_path
  cert_path="$(resolve_cert_path "$id")"

  local cfg
  cfg="$(make_temp_file)"
  render_issuing_config "$ca_name" "$cfg"

  openssl ca -config "$cfg" -revoke "$cert_path" -crl_reason "$reason" -passin "$(get_ca_passin)"
  log "Revoked certificate: $cert_path"

  generate_crl "$ca_name"
}

cmd_crl() {
  local ca_name="issuing"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ca)
        ca_name="$2"
        shift 2
        ;;
      *)
        die "Unknown crl option: $1"
        ;;
    esac
  done

  generate_crl "$ca_name"
}

cmd_backup() {
  local backup_password_file=""
  local include_passphrase=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backup-password-file)
        backup_password_file="$2"
        shift 2
        ;;
      --include-passphrase)
        include_passphrase=1
        shift
        ;;
      *)
        die "Unknown backup option: $1"
        ;;
    esac
  done

  ensure_initialized
  need_command tar
  need_command sha256sum

  if [[ -z "$backup_password_file" ]]; then
    local entered
    entered="$(prompt_secret_twice "Enter backup encryption password: ")"
    local tmp_pass
    tmp_pass="$(make_temp_file)"
    printf '%s' "$entered" >"$tmp_pass"
    chmod 600 "$tmp_pass"
    backup_password_file="$tmp_pass"
  fi

  [[ -f "$backup_password_file" ]] || die "Backup password file not found: $backup_password_file"

  local stamp tmp_tar out_file
  stamp="$(timestamp)"
  tmp_tar="$(make_temp_file)"
  out_file="$CA_DIR/backups/internal-ca-$stamp.tar.gz.enc"

  mkdir -p "$CA_DIR/backups"

  if [[ "$include_passphrase" -eq 1 ]]; then
    tar -C "$CA_DIR" -czf "$tmp_tar" .
  else
    tar -C "$CA_DIR" --exclude='.ca-passphrase' -czf "$tmp_tar" .
  fi

  openssl enc -aes-256-cbc -pbkdf2 -salt \
    -in "$tmp_tar" \
    -out "$out_file" \
    -pass "file:$backup_password_file"

  sha256sum "$out_file" >"$out_file.sha256"
  chmod 600 "$out_file"
  chmod 644 "$out_file.sha256"

  log "Encrypted backup created: $out_file"
  log "Checksum written: $out_file.sha256"
}

print_ca_status() {
  local ca_name="$1"
  local label="$2"
  local index="$CA_DIR/$ca_name/db/index.txt"
  local serial="$CA_DIR/$ca_name/db/serial"
  local crlnumber="$CA_DIR/$ca_name/db/crlnumber"

  printf '%s\n' "$label"
  if [[ -f "$index" ]]; then
    local valid revoked expired
    valid="$(grep -c '^V' "$index" || true)"
    revoked="$(grep -c '^R' "$index" || true)"
    expired="$(grep -c '^E' "$index" || true)"
    printf '  Issued: valid=%s revoked=%s expired=%s\n' "$valid" "$revoked" "$expired"
  else
    printf '  Issued: n/a\n'
  fi

  if [[ -f "$serial" ]]; then
    printf '  Next serial: %s\n' "$(cat "$serial")"
  fi

  if [[ -f "$crlnumber" ]]; then
    printf '  Next CRL number: %s\n' "$(cat "$crlnumber")"
  fi
}

print_crl_status() {
  local label="$1"
  local path="$2"

  printf '%s\n' "$label"
  if [[ -f "$path" ]]; then
    local next
    next="$(openssl crl -in "$path" -noout -nextupdate 2>/dev/null | sed 's/^nextUpdate=//')"
    printf '  File: %s\n' "$path"
    if [[ -n "$next" ]]; then
      printf '  Next update: %s\n' "$next"
    fi
  else
    printf '  File: (not generated)\n'
  fi
}

cmd_show() {
  printf 'pTAK Internal PKI Status\n'
  printf '  CA dir: %s\n' "$CA_DIR"
  printf '  Pass file: %s\n' "$CA_PASS_FILE"

  local link="$REPO_ROOT/secrets/internal-ca"
  if [[ -L "$link" ]]; then
    printf '  Repo symlink: %s -> %s\n' "$link" "$(readlink "$link")"
  else
    printf '  Repo symlink: %s (missing)\n' "$link"
  fi

  print_cert_fingerprint "Root CA" "$ROOT_CERT"
  print_cert_fingerprint "Issuing CA" "$ISSUING_CERT"

  if [[ -f "$ONLINE_CERT" ]]; then
    print_cert_fingerprint "Online FTS CA" "$ONLINE_CERT"
  fi

  print_ca_status "issuing" "Issuing CA DB"
  if [[ -f "$ONLINE_CERT" ]]; then
    print_ca_status "online" "Online CA DB"
  fi

  print_crl_status "Issuing CRL" "$PUBLIC_CRL"
  if [[ -f "$ONLINE_CERT" ]]; then
    print_crl_status "Online CRL" "$PUBLIC_ONLINE_CRL"
  fi

  if [[ -f "$PUBLIC_CHAIN" ]]; then
    printf 'Public chain: %s\n' "$PUBLIC_CHAIN"
  fi

  local latest_backup
  latest_backup="$(ls -1t "$CA_DIR/backups"/internal-ca-*.tar.gz.enc 2>/dev/null | head -n 1 || true)"
  if [[ -n "$latest_backup" ]]; then
    printf 'Latest backup: %s\n' "$latest_backup"
  else
    printf 'Latest backup: (none)\n'
  fi
}

main() {
  need_command openssl

  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi
  shift || true

  case "$cmd" in
    init)
      cmd_init "$@"
      ;;
    issue-server)
      cmd_issue_server "$@"
      ;;
    issue-client)
      cmd_issue_client "$@"
      ;;
    provision)
      cmd_provision "$@"
      ;;
    revoke)
      cmd_revoke "$@"
      ;;
    crl)
      cmd_crl "$@"
      ;;
    backup)
      cmd_backup "$@"
      ;;
    show)
      cmd_show "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
