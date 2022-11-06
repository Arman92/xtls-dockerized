#!/bin/bash
Precheck() {
	DOCKER_V=$(docker -v | grep -i "version")
	DOCKER_COMPOSE_V=$(docker-compose -v | grep -i "version")
	if [ -z "$DOCKER_V" ] || [ -z "$DOCKER_COMPOSE_V" ]; then
		echo "Docker or docker-compose not found. "
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

	EssentialFiles="Caddyfile .settings"
	for file in $EssentialFiles; do
		if [ ! -e $file ]; then
			case "${file}" in
			"Caddyfile")
				# curl -sO "https://raw.githubusercontent.com/Arman92/xtls-dockerized/main/${file}"
        # git clone https://github.com/Arman92/xtls-dockerized.git
				;;
			"tls" | "Webdata")
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

SetCF() {
	read -p "Please Input Your CloudFlare Mailbox: " MAILBOX
	read -p "Please Input Your CloudFlare API_Key: " APIKEY
	sed -i -E "s|CF_Email=.+|CF_Email=$MAILBOX|g" ./docker-compose.yml
	sed -i -E "s|CF_Key=.+|CF_Key=$APIKEY|g" ./docker-compose.yml
	ChangeSettings "CF_Email" "$MAILBOX"
	ChangeSettings "CF_Key" "$APIKEY"
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
	
  sed -i -E "1s|domain.com \{|$domains \{|g" ./Caddyfile.template
  echo -e "\nFallback to use \n\t1.file_server for a decoy website \n\t2.redirect to another URL?\n(Default 1) : "
	read mode
	case "${mode}" in
	2)
		echo "Using redirect to another URL"
		read -p "Please input the URL (e.g. https://google.com) you want to redirect to as fallback: " ppppp
		sed -i -E "14,+0s|^\s+#+| |g" ./Caddyfile.template
		sed -i -E "11,+1s|^|#|g" ./Caddyfile.template
		sed -i -E "14s|redir .*|redir $ppppp {|g" ./Caddyfile.template
		;;
	*)
		echo "Using file_server to serve a decoy website"
		sed -i -E "14,+0s|^| #|g" ./Caddyfile.template
		sed -i -E "11,+1s|^\s+#+| |g" ./Caddyfile.template
		;;
	esac
	ChangeSettings "DOMAINS" "$domains"
}

ChangeCF() {
	iscfset=$(grep 'CF_' ./.settings | awk '{print NR}' | sed -n '$p')
	case "${iscfset}" in
	2)
		read -p "Want to change CloudFlare settings? (yN default N): " changecf
		case "${changecf}" in
		'y' | 'Y')
			SetCF
			;;
		*) ;;
		esac
		;;
	*)
		SetCF
		;;
	esac
}

ChangeCaddy() {
	iscaddyset=$(grep 'FQDN' ./.settings | awk '{print NR}' | sed -n '$p')
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
			sed -i -E "s|\w{8}(-\w{4}){3}-\w{12}\",//xtls|$UUIDN1\",//xtls|g" ./config.json
			ChangeSettings "UUID" "$UUIDN1"
			;;
		*) ;;
		esac
		;;
	*)
		UUIDN1=$(curl -s https://www.uuidgenerator.net/api/version4)
		sed -i -E "s|\w{8}(-\w{4}){3}-\w{12}\",//xtls|$UUIDN1\",//xtls|g" ./config.json
		ChangeSettings "UUID" "$UUIDN1"

		;;
	esac
}

ChangeFlow() {
	CurrentFlowTpe=$(grep FLOW .settings | awk -F= '{print $2}')
	if [ -z "$CurrentFlowTpe" ]; then
		CurrentFlowTpe=$(grep 'flow' config.json | awk -F'"' '{print $4}')
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
	FQDN=$(grep 'FQDN' .settings | awk -F= '{print $2}')
	UUID=$(grep 'UUID' .settings | awk -F= '{print $2}')
	FLOW=$(grep 'FLOW' .settings | awk -F= '{print $2}')
	sharelink="vless://$UUID@$FQDN:443?flow=$FLOW&encryption=none&security=xtls&type=tcp&headerType=none#$FQDN"
	echo "Your VLESS ShareLink is:"
	echo $sharelink
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
	# ChangeCF
	ChangeCaddy
	ChangeUUID
	ChangeFlow
	docker-compose down --rmi all
	docker-compose up -d
	docker exec acme --issue --dns dns_cf -d $FQDN --server letsencrypt
	docker exec acme --install-cert -d $FQDN --key-file /tls/key.key --fullchain-file /tls/cert.crt
	docker-compose restart
	if [ -e "/usr/bin/docker-compose" ]; then
		DockerComposePath="/usr/bin/docker-compose"
		echo "0 0 1 * * cd $PWD && $DockerComposePath restart xray" >>/var/spool/cron/crontabs/"$(whoami)"
	elif [ -e "/usr/local/bin/docker-compose" ]; then
		DockerComposePath="/usr/local/bin/docker-compose"
		echo "0 0 1 * * cd $PWD && $DockerComposePath restart xray" >>/var/spool/cron/crontabs/"$(whoami)"
	fi

	ShowLink
}

Remove() {
	Precheck 3
	sed -i '/caddy-xtls/d' /var/spool/cron/crontabs/"$(whoami)"
	docker-compose down --rmi all
}

#echo "Your Random XTLS UUID Is: $UUIDN1"
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
	*)
		echo -e "Usage guide: \n\n./install.sh install\t\t# Step-By-Step configuration and installation\n./install.sh remove \t\t# Removes the docker containers"
		;;
	esac

}

main $1 $2