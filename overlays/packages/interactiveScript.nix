{ pkgs, ... }:
pkgs.writeScriptBin "interactiveScript.sh" ''
          #! /usr/bin/env nix-shell
          #! nix-shell -i bash -p bash -p tmux -p wireguard-tools

          ###### /usr/bin/env bash
          # SPDX-License-Identifier: GPL-2.0
          #
          # Copyright (C) 2015-2020 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
  	# Adapted / Re-Used for KittenConnect fastNEasy-deployment


          set -eu -o pipefail
          [[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

  	WG=${pkgs.wireguard-tools}/bin/wg
  	wg() {
  		$WG $@
  	}

  	IPROUTE2=${pkgs.iproute2}/bin/ip
  	ip() {
  		$IPROUTE2 $@
  	}

          set -x

          : ''${PORT:=51888}
          : ''${IFACE:=kitten}
          : ''${ENDPOINT:=pve.ig1.svc.kittenconnect.net}
          : ''${DEFGW:=0}

          : ''${TCPSOCK:=/dev/tcp/$ENDPOINT/$PORT}


          if ip -d -c link show $IFACE; then
            ip -brief -c address show $IFACE
            exit 1
          fi

  	: ''${MAXRETRY=10}
  	: ''${DELAY=5}

  	RETRY=0
          while ! exec 3<>$TCPSOCK; do
  		RETRY=$(( $RETRY + 1 ))

  		if [[ $RETRY -gt $MAXRETRY ]]; then break; fi
  		echo "Waiting $DELAY seconds before retrying"
  		sleep $DELAY
  	done

          privatekey="$(wg genkey)"
          wg pubkey <<<"$privatekey" >&3
  	echo "$(hostname)-$(cat /sys/class/dmi/id/product_serial)-$(cat /sys/class/dmi/id/product_uuid)" >&3
          IFS=: read -r status server_pubkey server_port ip_cidr internal_ip <&3
          [[ $status == OK ]]
          ip link del dev $IFACE 2>/dev/null || true
          ip link add dev $IFACE type wireguard
  	( set +x; wg set $IFACE private-key <(echo "$privatekey"); ) # Keep PrivKey private
          wg set $IFACE peer "$server_pubkey" allowed-ips 0.0.0.0/0,::/0 endpoint "$ENDPOINT:$server_port" persistent-keepalive 25
          ip address add "$internal_ip"/"$ip_cidr" dev $IFACE
          ip link set up dev $IFACE

          slog() {
                  echo "[S: $TCPSOCK] $@"
          }

          main () {
          while read line; do
            case $line in
                    SSH:*)
                            sshKey="$(cut -d: -f2- <<< $line)"
                            if ! grep -qF "$(awk '{ print $2 }' <<< $sshKey)" $HOME/.ssh/authorized_keys; then
                                  slog "[SSH] Adding $sshKey to $HOME/.ssh/authorized_keys"
                                  mkdir -vp $HOME/.ssh
                                  echo "$sshKey" >> $HOME/.ssh/authorized_keys
                                  chmod 600 $HOME/.ssh/authorized_keys
                            fi

                            ;;
                    *) slog $line
                            ;;
            esac
          done <&3
          }

          set +x
          main

  	clear
  	echo "Root Password: $(cat /var/shared/root-password)"
  	echo "Hostname $(hostname).local"
  	echo
  	wg
  	echo
  	ip -brief -color address show 

          # echo Follow installation by running : tmux new-session -A -s installation
''
