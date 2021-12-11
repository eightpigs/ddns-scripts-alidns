# ddns-scripts-alidns

Pure Bash Alidns scripts for *unix.

Related: [eightpigs/aliyun-ddns-python](https://github.com/eightpigs/aliyun-ddns)

## Alidns documents

- Signature: https://help.aliyun.com/document_detail/29747.html
- Open API Online: https://next.api.aliyun.com/api/Alidns/2015-01-09/AddCustomLine?params={}


## Requirements

**OpenWRT**

```bash
opkg update
opkg install openssl-util bash curl jq
```

**Debian**

```bash
sudo apt update
sudo apt install libssl-dev bash curl jq
```

**MacOS**

```bash
brew install curl jq
```

## Usage

1. Modify the configuration: `ak_id`, `ak_secret`, `domain`, `records`
2. `./run.sh`

