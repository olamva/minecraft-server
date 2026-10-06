#!/bin/bash
set -u
export OCI_CLI_PROFILE=API PYTHONWARNINGS=ignore SUPPRESS_LABEL_WARNING=True
D=$(cd "$(dirname "$0")" && pwd)
source "$D/.notes/oci-ids.env"
T=$(awk -F= '/^\[API\]/{f=1} f&&/^tenancy/{print $2; exit}' ~/.oci/config)
NTNU=(ssh -o BatchMode=yes -i ~/.ssh/gitntntnu olamva@login.stud.ntnu.no)
VM=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "ubuntu@$PUBIP")
log() { echo "$(date '+%F %T') $*"; }
fail() { log "FAILED: $*"; exit 1; }

ocpus() { oci compute instance get --instance-id "$INSTANCE" --query 'data."shape-config".ocpus' --raw-output 2> /dev/null | cut -d. -f1; }

if [ -z "${INSTANCE:-}" ]; then
  i=0
  qx=0
  while [ -z "${INSTANCE:-}" ]; do
    i=$((i + 1))
    for size in "4 24" "2 12" "1 6"; do
      set -- $size
      out=$(oci compute instance launch --compartment-id "$T" --availability-domain "UTTG:EU-STOCKHOLM-1-AD-1" --display-name minecraft --shape VM.Standard.A1.Flex --shape-config "{\"ocpus\":$1,\"memoryInGBs\":$2}" --image-id ocid1.image.oc1.eu-stockholm-1.aaaaaaaazp54xqtal5jhxsjrzem2nxjcqf7rih3tmhubvc4w76eivc63zdla --boot-volume-size-in-gbs 50 --subnet-id "$SUB" --assign-public-ip false --ssh-authorized-keys-file ~/.ssh/id_ed25519.pub --user-data-file "$D/cloud-init.yaml" --query 'data.id' --raw-output 2> "$D/.notes/launch.err")
      err=$(cat "$D/.notes/launch.err")
      id=$(grep -oE 'ocid1\.instance\.[a-z0-9.-]+' <<< "$out" | head -1)
      if [ -n "$id" ]; then
        INSTANCE=$id
        echo "INSTANCE=$INSTANCE" >> "$D/.notes/oci-ids.env"
        log "LAUNCHED $1 OCPU / $2 GB in round $i"
        break
      fi
      msg=$(echo "$err" | grep -m1 '"message"' | tr -s ' ')
      if [[ $msg =~ quotas\ were\ exceeded ]]; then
        qx=$((qx + 1))
        (( qx > 90 )) && fail "QuotaExceeded 90 times in a row: $msg"
        continue
      fi
      qx=0
      [[ $msg =~ capacity|Too\ many\ requests|InternalError|required\ information\ to\ complete\ authentication ]] || [[ $err =~ RequestException|ConnectionError|timed\ out ]] || fail "launch: $out $err"
    done
    [ -n "${INSTANCE:-}" ] && break
    (( i % 30 == 1 )) && log "round $i: $msg (quota errors in a row: $qx)"
    sleep 60
  done
fi

oci compute instance get --instance-id "$INSTANCE" --wait-for-state RUNNING --max-wait-seconds 900 > /dev/null 2>&1 || fail "instance not RUNNING"
VNIC=$(oci compute instance list-vnics --instance-id "$INSTANCE" --query 'data[0].id' --raw-output 2>/dev/null)
PRIV=$(oci network private-ip list --vnic-id "$VNIC" --query 'data[0].id' --raw-output 2>/dev/null)
oci network public-ip update --public-ip-id "$PUBIP_ID" --private-ip-id "$PRIV" --wait-for-state ASSIGNED > /dev/null 2>&1 || fail "public IP attach"
log "IP attached"

for _ in $(seq 1 60); do "${VM[@]}" true 2> /dev/null && break; sleep 15; done
"${VM[@]}" 'cloud-init status --wait > /dev/null; cloud-init status' | grep -q 'status: done' || fail "cloud-init: $("${VM[@]}" 'cloud-init status --long' 2>&1 | tail -5)"
"${VM[@]}" 'java -version 2>&1 | head -1; sudo iptables -S INPUT | grep 25565; systemctl is-enabled minecraft' || fail "VM check"
log "VM ready"

"${NTNU[@]}" 'tmux send-keys -t mc stop Enter 2> /dev/null; while tmux has-session -t mc 2> /dev/null; do sleep 2; done'
"${NTNU[@]}" 'tar -C ~/minecraft --exclude=server.jar --exclude=eula.txt --exclude=libraries --exclude=versions --exclude=logs -czf - .' | "${VM[@]}" 'sudo tar -C /opt/minecraft -xzf - && sudo chown -R minecraft:minecraft /opt/minecraft' || fail "world copy"
log "world copied"

"${VM[@]}" 'sudo systemctl start minecraft; for i in $(seq 1 120); do sudo grep -q "Done (" /opt/minecraft/logs/latest.log 2> /dev/null && exit 0; sleep 2; done; exit 1' || fail "server start: $("${VM[@]}" 'sudo journalctl -u minecraft -n 20 --no-pager' 2>&1)"
log "PING $(python3 -I "$D/ping.py" "$PUBIP" 25565 2>&1)"
log "DONE at $(ocpus) OCPU"

r=0
while [ "$(ocpus)" != 4 ]; do
  sleep 600
  r=$((r + 1))
  oci compute instance update --instance-id "$INSTANCE" --shape-config '{"ocpus":4,"memoryInGBs":24}' --force > /dev/null 2> "$D/.notes/resize.err"
  (( r % 6 == 1 )) && log "resize try $r: $(grep -m1 '"message"' "$D/.notes/resize.err" | tr -s ' ')"
  sleep 60
  oci compute instance get --instance-id "$INSTANCE" --wait-for-state RUNNING --wait-for-state STOPPED --max-wait-seconds 1200 > /dev/null 2>&1
  if [ "$(oci compute instance get --instance-id "$INSTANCE" --query 'data."lifecycle-state"' --raw-output 2> /dev/null)" = STOPPED ]; then
    log "instance STOPPED after resize try $r, starting it"
    oci compute instance action --instance-id "$INSTANCE" --action START --wait-for-state RUNNING --max-wait-seconds 1200 > /dev/null 2>&1 || fail "restart after resize"
  fi
done
log "RESIZED to 4 OCPU / 24 GB"
log "PING $(python3 -I "$D/ping.py" "$PUBIP" 25565 2>&1)"
