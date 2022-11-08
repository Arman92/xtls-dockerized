#!/bin/bash
DEST_PATH="TEST"

Precheck() {
	DOCKER_V=$(docker -v | grep -i "version")
	DOCKER_COMPOSE_V=$(docker-compose -v | grep -i "version")
	if [ -z "$DOCKER_V" ] || [ -z "$DOCKER_COMPOSE_V" ]; then
		echo "Docker or docker-compose not found. ";
		exit 0
	fi
	case "${1}" in
	1)
		if [ -e tls ]; then
			# if body
			rm -rf tls
		fi
		;;
	*) ;;
	esac

	EssentialFiles="site Caddyfile .settings xray/config.json docker-compose.yml"
	for file in $EssentialFiles; do
		if [ ! -e $file ]; then
			case "${file}" in
			"Caddyfile" | "xray/config.json" | "docker-compose.yml")
				curl -sO "https://raw.githubusercontent.com/Arman92/xtls-dockerized/main/${file}"
				;;
			"tls" | "site")
				mkdir $file
				;;
			".settings")
				touch $file
				;;
			*) ;;
			esac
		fi
	done
}

ChangeSettings() {
	if [ -z "$(grep "$1" ./.settings)" ]; then
		echo "$1=$2" >>./.settings
	else
		sed -i -E "s|$1=.+|$1=$2|g" ./.settings
	fi
}


SetCaddy() {
  count=1
  domains=""

  echo -e "Please input your domain(s). \nYes you can enter more than one domain!"
  while read -p "Domain #$count: (hit enter to skip):   " input; do
    if [ "$input" = "" ]; then break; fi

    if [ "$count" -eq 1 ]; then
      domains="$input"
    else
      domains="$domains, $input"
    fi

    count=$((count+1))

    # echo "Added $input to your list of domain, add another one and hit enter, or if you're finished just press enter" >&2
    echo "Domains: $domains"
  done
	
  sed -i -E "1s|.*\{|$domains \{|g" ./Caddyfile
  echo -e "\nFallback to use \n\t1.file_server for a decoy website \n\t2.redirect to another URL?\n(Default 1) : "
	read mode
	case "${mode}" in
	2)
		echo "Using redirect to another URL"
		read -p "Please input the URL (e.g. https://google.com) you want to redirect to as fallback: " ppppp
		sed -i -E "14,+0s|^\s+#+| |g" ./Caddyfile
		sed -i -E "11,+1s|^|#|g" ./Caddyfile
		sed -i -E "14s|redir .*|redir $ppppp {|g" ./Caddyfile
		;;
	*)
		echo "Using file_server to serve a decoy website"
		sed -i -E "14,+0s|^| #|g" ./Caddyfile
		sed -i -E "11,+1s|^\s+#+| |g" ./Caddyfile
		;;
	esac
	ChangeSettings "DOMAINS" "$domains"
}


ChangeCaddy() {
	iscaddyset=$(grep 'DOMAINS' ./.settings | awk '{print NR}' | sed -n '$p')
	case "${iscaddyset}" in
	1)
		read -p "Want to change domain settings? (yN default N): " changefqdn
		case "${changefqdn}" in
		'y' | 'Y')
			SetCaddy
			;;
		*) ;;
		esac
		;;
	*)
		SetCaddy
		;;
	esac
}

ChangeUUID() {
	case "$(grep 'UUID' ./.settings | awk '{print NR}' | sed -n '$p')" in
	1)
		read -p "Change the UUID? (y or N def N)" setUUID
		case "${setUUID}" in
		'y' | 'Y')
			UUIDN1=$(curl -s https://www.uuidgenerator.net/api/version4)
			sed -i -E "s|\w{8}(-\w{4}){3}-\w{12}\"|$UUIDN1\"|g" ./config.json
			ChangeSettings "UUID" "$UUIDN1"
			;;
		*) ;;
		esac
		;;
	*)
		UUIDN1=$(curl -s https://www.uuidgenerator.net/api/version4)
		sed -i -E "s|\w{8}(-\w{4}){3}-\w{12}\"|$UUIDN1\"|g" ./config.json
		ChangeSettings "UUID" "$UUIDN1"
		echo -e "Changed the UUID in configs to a random one: \n\t\"$UUIDN1\""

		echo -e "Generating random paths for vmess and vless protocols..."
		vless_ws_path=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-15} | head -n 1)
		vmess_tcp_path=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-15} | head -n 1)
		vmess_ws_path=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-15} | head -n 1)
		ChangeSettings "vless_ws_path" "$vless_ws_path"
		ChangeSettings "vmess_tcp_path" "$vmess_tcp_path"
		ChangeSettings "vmess_ws_path" "$vmess_ws_path"

		echo "Vless WS path: /$vless_ws_path"
		echo "Vmess TCP path: /$vmess_tcp_path"
		echo "Vless WS path: /$vmess_ws_path"

		sed -i -E "s|/vless-ws-path\"|/$vless_ws_path\"|g" ./config.json
		sed -i -E "s|/vmess-tcp-path\"|/$vmess_tcp_path\"|g" ./config.json
		sed -i -E "s|/vmess-ws-path\"|/$vmess_ws_path\"|g" ./config.json

		;;
	esac
}

ChangeFlow() {
	CurrentFlowTpe=$(grep FLOW .settings | awk -F= '{print $2}')
	if [ -z "$CurrentFlowTpe" ]; then
		CurrentFlowTpe=$(grep 'flow' config.json | awk -F'"' '{print $4}')
		ChangeSettings "FLOW" $CurrentFlowTpe
	fi
	read -p "Current flow control is $CurrentFlowTpe, want to change it?(y or N def N)" ChangeFlowType
	case "${ChangeFlowType}" in
	'y' | 'Y')
		echo -e "Select the new flow control method(def 2):\n1.xtls-rprx-origin\n2.xtls-rprx-direct\n3.xtls-rprx-splice(Linux only)"
		read FlowType
		case "${FlowType}" in
		1)
			sed -i "s|$CurrentFlowTpe|xtls-rprx-origin|g" config.json
			ChangeSettings "FLOW" "xtls-rprx-origin"
			;;
		3)
			sed -i "s|$CurrentFlowTpe|xtls-rprx-splice|g" config.json
			ChangeSettings "FLOW" "xtls-rprx-splice"
			;;
		*)
			sed -i "s|$CurrentFlowTpe|xtls-rprx-direct|g" config.json
			ChangeSettings "FLOW" "xtls-rprx-direct"
			;;
		esac
		;;
	esac

}

ShowLink() {
	DOMAINS=$(grep 'DOMAINS' .settings | awk -F= '{print $2}')
	UUID=$(grep 'UUID' .settings | awk -F= '{print $2}')
	FLOW=$(grep 'FLOW' .settings | awk -F= '{print $2}')
	vless_ws_path=$(grep 'vless_ws_path' .settings | awk -F= '{print $2}')
	vmess_tcp_path=$(grep 'vmess_tcp_path' .settings | awk -F= '{print $2}')
	vmess_ws_path=$(grep 'vmess_ws_path' .settings | awk -F= '{print $2}')
	

	echo -e "\n\n********************\n\n"

	for domain in ${DOMAINS//,/ }
	do
		# call your procedure/other scripts here below
		echo -e "Links for domain \"$domain\""

		vless_share="vless://$UUID@$domain:443?flow=$FLOW&encryption=none&security=tls&type=ws&path=/$vless_ws_path&sni=$domain&host=$domain#vless-$domain"
		echo -e "VLESS over WS:\n$vless_share"

		vmess_ws_share="{\"add\":\"$domain\",\"aid\":\"0\",\"alpn\":\"\",\"host\":\"\",\"id\":\"$UUID\",\"net\":\"ws\",\"path\":\"/$vmess_ws_path\",\"port\":\"443\",\"ps\":\"vmess-$domain\",\"scy\":\"none\",\"sni\":\"\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}"
		echo -e "VLESS over WS:\nvmess://$(echo -n $vmess_ws_share | base64 -w 0 | sed -E 's/=//g')"


		echo -e "\n\n********************\n\n"
	done
}

Update() {
	Precheck 2
	imageID=$(docker-compose images | grep $1 | awk '{print $4}')
	if [ -z $imageID ]; then
		echo "no running container found"
		exit 0
	fi
	case "${1}" in
	"caddy" | "xray")
		#docker-compose stop $1
		docker-compose rm -s $1
		docker rmi $imageID
		docker-compose up -d $1
		;;
	"acme")
		echo "Emmmm"
		;;
	*)
		echo "default (none of caddy, xray or acme)"
		;;
	esac
}

Install() {
	Precheck 1
	ChangeCaddy
	ChangeUUID
	ChangeFlow
	docker-compose down
	docker-compose up -d

	sed -i.old '/^.*restart xray.*/d' /var/spool/cron/crontabs/"$(whoami)"
	if [ -e "/usr/bin/docker-compose" ]; then
		DockerComposePath="/usr/bin/docker-compose"
		echo "0 0 * * * cd $PWD && $DockerComposePath restart xray" >>/var/spool/cron/crontabs/"$(whoami)"
	elif [ -e "/usr/local/bin/docker-compose" ]; then
		DockerComposePath="/usr/local/bin/docker-compose"
		echo "0 0 * * * cd $PWD && $DockerComposePath restart xray" >>/var/spool/cron/crontabs/"$(whoami)"
	fi

	ShowLink
}

Remove() {
	Precheck 3
	sed -i '/caddy-xtls/d' /var/spool/cron/crontabs/"$(whoami)"
	docker-compose down --rmi all
}

main() {
	case "${1}" in
	"install")
		Install
		;;
	"update")
		Update $2
		;;
	"remove")
		Remove
		;;
	"links")
		ShowLink
		;;
	*)
		echo -e "Usage guide: \n\n./install.sh install\t\t# Step-By-Step configuration and installation\n./install.sh remove \t\t# Removes the docker containers"
		;;
	esac

}

main $1 $2