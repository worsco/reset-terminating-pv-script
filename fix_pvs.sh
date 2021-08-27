#!/bin/bash

#
# Code design goalis: 
# * Minimal use of 3rd party binaries.
#   - Could have used jq to query json output from
#     kubeclt/oc, but I wanted to minimize the use
#     of additional binaries.
#
# * Script gets all PVs, but only sends PVs that
#   are set to Terminating to the 'resetpv' binary.
#   - However, the 'resetpv' binary does have logic
#     to report that a PV is not in terminating status.
#     It may be overkill to filter out PVs not in
#     terminating state (I had created this script
#     before deep-diving into the resetpv code).
#
# * Download the etcd certs an etcd pod.
#   - Perhaps there is a way to retrieve the certs from
#     secrets within kubernetes.  I defaulted to pulling
#     the etcd certs from a master pod.
#
# Assumptions:
# * The first etcd name returned from 'get pods -l app=etcd'
#   will be consistent as that pod will be used using the
#   same logic in the portforward_etcd.sh script to create
#   port-forwarding to the etcd pod.
#


ETCD_CERTS=./etcd-certs/

OC_CMD=oc
RESETPV_CMD=./bin/resetpv
echo
echo "Starting repair, good luck!"

if ! command -v $OC_CMD &> /dev/null
then
  echo
  echo "Cannot find 'oc' command."
  echo "Terminating."
  exit
fi

if ! command -v $RESETPV_CMD &> /dev/null
then
  echo
  echo "Cannot find '$RESETPV_CMD' command."
  echo "Terminating."
  exit
fi

# Get an etcdmaster
export mymaster=$($OC_CMD get pods -l app=etcd -n openshift-etcd -o jsonpath='{range .items[0]}{.metadata.name}{"\n"}{end}')

# pod is named: etcd-master0.cluster1.example.local
# but cert is named: etcd-peer-master0.cluster1.example.local
# Create a new variable that removes "etcd-" from the master name 

export mycertmaster="etcd-peer-${mymaster:5}"

echo
echo "I will be using '$mymaster' as the etcd master..."

echo
echo "Creating directory for certs..."
mkdir -p $ETCD_CERTS

echo
echo "rsyncing etcd-all-peer certificate files..."
# Get the etcd secrets from the master
oc rsync $mymaster:/etc/kubernetes/static-pod-certs/secrets/etcd-all-peer/ $ETCD_CERTS -n openshift-etcd -c etcdctl

echo
echo "rsyncing etcd-peer-client-ca certificate files..."
# Get the CA cert
oc rsync $mymaster:/etc/kubernetes/static-pod-certs/configmaps/etcd-peer-client-ca/ $ETCD_CERTS -n openshift-etcd -c etcdctl


echo
echo "generating list of PVs that are 'Terminating'..."
# Create an list of "pv-name,deletionTimestamp-value" separated by a newline
export allPVs=$(oc get pv -o jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.deletionTimestamp}{"\n"}{end}')

# Iterate through the list and determine which PVs have a deletionTimestamp set
for PV in $allPVs; do
IFS="," read -a myPVarray <<< $PV
  # if the second array value is not null, we have a deletionTimestamp on the PV
  if [[ -n ${myPVarray[1]} ]] ; then
     PVs2fix="${PVs2fix:+$PVs2fix }${myPVarray[0]}"
  fi
done

# If the list is empty, don't try to fix nothing
if [[ -n $PVs2fix ]] ; then
  counter=0

  echo

  # iterate and fix all PVs that have deletionTimestamp set
  for PV in $PVs2fix; do
    ((counter+=1))
    echo "Fixing PV #$counter: $PV"

$RESETPV_CMD \
--etcd-key etcd-certs/$mycertmaster.key \
--etcd-cert etcd-certs/$mycertmaster.crt \
--etcd-ca etcd-certs/ca-bundle.crt \
--etcd-host localhost \
--k8s-key-prefix kubernetes.io $PV

  done

else

  echo
  echo "No PVs in Terminating for me to fix."

fi
#EOF

