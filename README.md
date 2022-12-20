# xtls-dockerized

## Initialization
If not already, install docker and docker-compose using below commands:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt install docker-compose
```

Make sure ports **443** and **80** are open on your cloud/server firewall.

## Install and Configure the Xray and Caddy with installer script
Use the installer below, this is step-by-step installer which will spin off docker containers and does the heavy lifting for you.

```bash
mkdir xray-docker && cd xray-docker
wget https://raw.githubusercontent.com/Arman92/xtls-dockerized/main/install.sh -O ./install.sh && chmod +x ./install.sh && ./install.sh install
```

## Share the links
Once finished with the above installer, you can view the VLESS and VMESS share links using the below command:
```bash
./install.sh  links
```

You can also generate QR codes to easily import the configs in your phone:
```bash
./install.sh qr
```

###  TODO
- Enable Trojan protocol
- Enable VMess over TCP

### Credits
This repo uses https://github.com/Colllect/colllect.io as a decoy website, you can manually change it to something else by changing contents of `xray-docker/site` directory