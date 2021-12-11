#!/bin/bash
#
# Pure Bash Alidns scripts for *unix.
#
# ## Alidns documents
#   Signature: https://help.aliyun.com/document_detail/29747.html
#   Open API Online: https://next.api.aliyun.com/api/Alidns/2015-01-09/AddCustomLine?params={}
#
#
# ## Requirements
# OpenWRT:
#   opkg update
#   opkg install openssl-util bash curl jq
#
# ## Usage
# 1. Modify the configuration: ak_id, ak_secret, domain, records
# 2. ./run.sh
#

# Debug:
# set -x




# Alidns properties
# -----------------------------------------------------------------------------
api_domain='alidns.aliyuncs.com'

# https://ram.console.aliyun.com/manage/ak
ak_id="Your AccessKeyId"
ak_secret="Your AccessKeySecret"

# Fixed, only one
signature_method='HMAC-SHA1'

# Alidns Domain properties
# -----------------------------------------------------------------------------
domain="youdomain.com"
records=('www' 'blog' 'demo')



# get public ip
# -----------------------------------------------------------------------------
get_public_ip() {
  public_ip=`which ip &> /dev/null && (ip addr show pppoe-wan | grep -Eo "inet \d{0,3}.\d{0,3}.\d{0,3}.\d{0,3}" | sed -e "s/inet //g") || echo ''`
  if [ -z "$public_ip" ]; then
    curl -k -s "https://ipv4.jsonip.com/" | jq .ip | sed -e "s/\"//g"
  else
    echo $public_ip
  fi
}

# build param & signed
# -----------------------------------------------------------------------------
param_encode() {
  params=$1
  str=""
  for (( i=0; i<${#params}; i++ )); do
    char="${params:$i:1}"
    if [[ $char == [a-zA-Z0-9.~_-] ]]; then
      str="$str$char"
    else
      hex=`printf '%%%02X' "'$char"`
      str="$str$hex"
    fi
  done
  echo $str | sed -e 's/+/%20/g' -e 's/*/%21/g' -e 's/%7E/~/g'
}

# TODO: ':' hex is '%3A', but, alidns api return '%253A'
# I didn't find the reason, so I made a replacement first, there may be other problems.
param_tosign() {
  echo -n "GET&$(param_encode "/")&$(param_encode $1)" \
    | sed -e "s/\%3A/\%253A/g" \
    | openssl sha1 -binary -hmac "$ak_secret&" \
    | openssl base64
}


# dns actions
# -----------------------------------------------------------------------------

request() {
  timestamp=`date -u +%Y-%m-%dT%TZ`
  signature_nonce=`date +%d-%m-%Y_%H-%M-%S`
  params="AccessKeyId=$ak_id&DomainName=$1&Format=json&SignatureMethod=$signature_method&SignatureNonce=$signature_nonce&SignatureVersion=1.0&Timestamp=$timestamp&Version=2015-01-09&Action=$2"
  if [ ! -z "$3" ]; then
    params=$params"&"$3
  fi
  # dictionary sorting
  params=`awk 'BEGIN{split('"\"$params\""',arr,"&"); for(i in arr) {v=arr[i]"&"; print v}}' | sort | xargs echo | sed 's/ //g;s/&$//g'`
  sign=$(param_encode $(param_tosign $params))
  echo `curl -k -s "https://$api_domain/?$params&Signature=$sign"`
}

fetch_domain_records() {
  echo $(request $1 "DescribeDomainRecords")
}

update_domain_record() {
  request $1 "UpdateDomainRecord" "RR=$2&RecordId=$3&Type=A&Value=$4"
}

add_domain_record() {
  request $1 "AddDomainRecord" "RR=$2&Type=A&Value=$3"
}

batch_update() {
  ip=`get_public_ip`
  if [ "$?" != "0" ]; then
    echo "cannot get public ip"
    exit 1
  fi

  echo ""
  echo "Public IP: $ip"
  echo "-----------------------------------------------------------------------"
  echo ""

  existed_records=`fetch_domain_records "epfighter.com" | jq .DomainRecords.Record`
  for i in "${records[@]}"; do
    echo $i
    if [ "$existed_records" = "null" ]; then
      add_domain_record $domain $i $ip
    else
      record=`echo $existed_records | jq -c '.[] | select( .RR | contains("'$i'"))'`
      if [ -z $record ]; then
        add_domain_record $domain $i $ip
      else
        record_id=`echo $record | jq .RecordId | sed -e "s/\"//g"`
        old_value=`echo $record | jq .Value | sed -e "s/\"//g"`
        if [ "$old_value" != "$ip" ]; then
          if [ "$record_id" = "null" ]; then
            add_domain_record $domain $i $ip
          else
            update_domain_record $domain $i $record_id $ip
          fi
        fi
      fi
    fi
    echo ""
    sleep 1
  done
}

batch_update
