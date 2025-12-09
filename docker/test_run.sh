#!/usr/bin/env bash

set -euo pipefail

debug_env() {
  echo "================ ENV DEBUG BEGIN ================"
  echo "[DEBUG] date: $(date || echo 'date failed')"
  echo "[DEBUG] whoami: $(whoami || echo 'whoami failed')"
  echo "[DEBUG] id: $(id || echo 'id failed')"
  echo "[DEBUG] pwd: $(pwd || echo 'pwd failed')"
  echo "[DEBUG] shell options: \$- = $-"

  echo
  echo "---- uname -a ----"
  uname -a || true

  echo
  echo "---- /etc/os-release ----"
  if [[ -r /etc/os-release ]]; then
    cat /etc/os-release
  else
    echo "no /etc/os-release"
  fi

  echo
  echo "---- lsb_release -a ----"
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -a || true
  else
    echo "lsb_release not installed"
  fi

  echo
  echo "---- locale ----"
  if command -v locale >/dev/null 2>&1; then
    locale || echo "locale command failed"
  else
    echo "locale command not found"
  fi

  echo
  echo "---- LANG / LC_* ----"
  echo "LANG=${LANG-<unset>}"
  echo "LC_ALL=${LC_ALL-<unset>}"
  env | grep '^LC_' || echo "no LC_* in env"

  echo
  echo "---- locale config files ----"
  for f in /etc/locale.gen /etc/locale.conf /etc/default/locale; do
    if [[ -r "$f" ]]; then
      echo ">>> $f"
      cat "$f"
    else
      echo ">>> $f (not present)"
    fi
  done

  echo "---- timezone ----"
  echo "TZ=${TZ-<unset>}"
  if [ -L /etc/localtime ]; then
    echo "/etc/localtime -> $(readlink -f /etc/localtime || true)"
  elif [ -f /etc/localtime ]; then
    echo "/etc/localtime is a regular file"
  else
    echo "/etc/localtime not found"
  fi

  echo
  echo "---- env (sorted) ----"
  env | sort

  echo
  echo "---- network ----"
  # TCP ping function using netcat or bash /dev/tcp
  tcp_ping() {
    local host=$1
    local port=$2
    local ip_version=$3  # 4 for IPv4, 6 for IPv6
    local timeout=${4:-3}
    
    # Try netcat first
    if command -v nc >/dev/null 2>&1; then
      local nc_output
      if [ "$ip_version" = "6" ]; then
        if command -v timeout >/dev/null 2>&1; then
          nc_output=$(timeout "$timeout" nc -6 -zv -w "$timeout" "$host" "$port" 2>&1) || true
        else
          nc_output=$(nc -6 -zv -w "$timeout" "$host" "$port" 2>&1) || true
        fi
      else
        if command -v timeout >/dev/null 2>&1; then
          nc_output=$(timeout "$timeout" nc -4 -zv -w "$timeout" "$host" "$port" 2>&1) || true
        else
          nc_output=$(nc -4 -zv -w "$timeout" "$host" "$port" 2>&1) || true
        fi
      fi
      if echo "$nc_output" | grep -q "succeeded\|open"; then
        return 0
      fi
    fi
    
    # Fallback to bash /dev/tcp (works in bash)
    # Note: bash /dev/tcp uses DNS resolution, so we can't force IPv4/IPv6 directly
    if [ -n "${BASH_VERSION:-}" ]; then
      if command -v timeout >/dev/null 2>&1; then
        if timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
          return 0
        fi
      else
        if bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
          return 0
        fi
      fi
    fi
    
    return 1
  }
  
  for host in github.com wps.com; do
    # Test IPv4 with TCP ping (port 443)
    echo "[DEBUG] TCP ping -4 $host:443"
    if tcp_ping "$host" 443 4; then
      echo "[OK] TCP ping -4 $host:443 succeeded"
    else
      echo "[WARN] TCP ping -4 $host:443 failed (exit=$?)"
    fi
    
    # Test IPv6 with TCP ping (port 443)
    echo "[DEBUG] TCP ping -6 $host:443"
    if tcp_ping "$host" 443 6; then
      echo "[OK] TCP ping -6 $host:443 succeeded"
    else
      echo "[WARN] TCP ping -6 $host:443 failed (exit=$?)"
    fi
    
    # Test IPv4 with curl
    if command -v curl >/dev/null 2>&1; then
      echo "[DEBUG] curl -4 $host"
      if curl -4 -sSf --connect-timeout 3 --max-time 5 "https://$host" >/dev/null 2>&1; then
        echo "[OK] curl -4 $host succeeded"
      else
        echo "[WARN] curl -4 $host failed (exit=$?)"
      fi
    fi
    
    # Test IPv6 with curl
    if command -v curl >/dev/null 2>&1; then
      echo "[DEBUG] curl -6 $host"
      # Try with hostname first
      if curl -6 -sSf --connect-timeout 3 --max-time 5 "https://$host" >/dev/null 2>&1; then
        echo "[OK] curl -6 $host succeeded"
      else
        # If failed, try to resolve IPv6 address and use IP directly
        ipv6_addr=""
        if command -v getent >/dev/null 2>&1; then
          # getent aaaa returns: hostname IPv6_address
          ipv6_line=$(getent aaaa "$host" 2>/dev/null | head -n1) || true
          if [ -n "$ipv6_line" ]; then
            # Extract IPv6 address (second field)
            ipv6_addr=$(echo "$ipv6_line" | cut -d' ' -f2) || true
          fi
        elif command -v host >/dev/null 2>&1 && command -v grep >/dev/null 2>&1; then
          # host returns: hostname has IPv6 address IPv6_address
          ipv6_line=$(host -t AAAA "$host" 2>/dev/null | grep "has IPv6 address") || true
          if [ -n "$ipv6_line" ]; then
            # Extract IPv6 address (last field, using space as delimiter)
            # Use a simple while loop to get last field
            for word in $ipv6_line; do
              ipv6_addr="$word"
            done
          fi
        fi
        
        if [ -n "$ipv6_addr" ]; then
          # Try with IPv6 address directly
          if curl -6 -sSf --connect-timeout 3 --max-time 5 "https://[$ipv6_addr]" >/dev/null 2>&1; then
            echo "[OK] curl -6 $host succeeded (via $ipv6_addr)"
          else
            echo "[WARN] curl -6 $host failed (exit=$?)"
          fi
        else
          # If TCP ping succeeded but curl failed, it's likely a DNS issue
          echo "[WARN] curl -6 $host failed (exit=$?) - IPv6 DNS may not be available, but TCP ping succeeded"
        fi
      fi
    fi
    echo
  done

  echo "================= ENV DEBUG END ================="
  echo
}

debug_env

[ -d ~/.config/ruyi ] && rm -rf ~/.config/ruyi
rm -rf /tmp/rit.bash

./rit.bash ruyi -p ruyi-bin

cat >> ruyi-litester-reports/report_my_configs.sh <<EOF
TEST_LITESTER_PATH=$(pwd)
TEST_START_TIME=${TEST_START_TIME}
EOF

DISTRO_ID=${DISTRO_ID}-$(uname -m)
cp -v ruyi_ruyi-bin_ruyi-basic_*.log ruyi-litester-reports/report_tmpl/26test_log.md
bash ruyi-litester-reports/report_gen.sh ${DISTRO_ID}

rm -f *.md

sudo mv ruyi-test-logs.tar.gz /artifacts/ruyi-test-${DISTRO_ID}-logs.tar.gz
sudo mv ruyi-test-logs_failed.tar.gz /artifacts/ruyi-test-${DISTRO_ID}-logs_failed.tar.gz
sudo mv ruyi_report/*.md /artifacts/

