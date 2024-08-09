#!/bin/bash
CONFIG_FILE="$(dirname $0)/config.json"

CEDULA=$(cat $CONFIG_FILE | jq .cedula --raw-output)
LOL=$(cat $CONFIG_FILE | jq .lol --raw-output)

LOGIN=$(curl --path-as-is -s -k -X 'POST' \
    -H 'Host: www.colsubsidio.com' -H 'Content-Type: application/json' \
    --data "{\"documentNumber\":\"$CEDULA\",\"documentType\":2,\"password\":\"$LOL\"}" \
    'https://www.colsubsidio.com/api-ssoc/users/login')

#echo $LOGIN
TOKEN=$(echo -n $LOGIN | jq .data.tokenId --raw-output)
#echo "TOKEN: $TOKEN"

SSO_FILE="$(dirname $0)/cookie.txt"
SSO=$(curl --path-as-is -i -s -k -c $SSO_FILE -X $'GET' --get \
    -H $'Host: www.diversioncolsubsidio.com' \
    -H $'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0' \
    -H $'Accept: text/html' \
    -b $'sistema=whatever' \
    --data-urlencode "redireccion=https://www.diversioncolsubsidio.com//" \
    --data-urlencode "autenticador=SesionPersonaColsubsidio" \
    --data-urlencode "iPlanetDirectoryPro=$TOKEN" \
    "https://www.diversioncolsubsidio.com/sistema.php/default/loguearSitio")

#echo $SSO
COOKIE=$(cat $SSO_FILE | tail -1 | grep -Eo "([0-9a-z]+)$")
rm $SSO_FILE 2> /dev/null

#echo "Cookie: $COOKIE"

# https://unix.stackexchange.com/questions/222368/get-date-of-next-saturday-from-a-given-date
PREV_SAT=$(date -d "+ $(( ( (6 - 1 - $(date +%u)) % 7) + 1 )) days" +%Y-%m-%d)
#PREV_MON=$(date -d "+ $(( ( (6 + 1 - $(date +%u)) % 7) + 1 )) days" +%Y-%m-%d)
#NEXT_SAT=$(date -d "+ $(( ( (6 + 6 - $(date +%u)) % 7) + 1 )) days" +%Y-%m-%d)
NEXT_MON=$(date -d "+ $(( ( (6 + 8 - $(date +%u)) % 7) + 1 )) days" +%Y-%m-%d)

SCHEDULES=$(curl --path-as-is -s -k -X $'POST' \
    -H $'Host: www.diversioncolsubsidio.com' \
    -H $'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0' \
    -H $'Accept: application/json, text/plain, */*' \
    -H $'Content-Type: application/json;charset=utf-8' \
    -b "sitio=$COOKIE" \
    -d "{\"filtro_disponibilidad\":{\"fecha_inicio\":\"${PREV_SAT}T00:00:00-05:00\",\"fecha_fin\":\"${NEXT_MON}T23:59:59-05:00\"}}" \
    "https://www.diversioncolsubsidio.com/v1/centro_entrenamiento/263/practicalibre/disponibilidad?filtrarSinCupo=0")

#echo $SCHEDULES
FILTER='.horarios[] | "\(.horario.fecha), \(.horario.hora_inicio), \(.cupos)"'
JQ_SCHEDULES=$(echo $SCHEDULES | jq -r "$FILTER")

#echo "$JQ_NEXT_SCHEDULES"

while IFS= read -r line; do
    IFS=", " read -r day hour turns <<< "$line"
    echo "$(date -d $day +'%A %b %d'): $hour $turns"
done <<< "$JQ_SCHEDULES"
