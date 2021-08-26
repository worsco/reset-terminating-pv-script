#!/bin/bash

ETCD_CERTS=./etcd-certs/

echo
echo "Starting repair, good luck!"

# Get an etcdmaster
export mymaster=$(oc get pods -l app=etcd -n openshift-etcd -o jsonpath='{range .items[0]}{.metadata.name}{"\n"}{end}')

# pod is named: etcd-master0.cluster1.zcsi.local
# but cert is named: etcd-peer-master0.cluster1.zcsi.local
# Create a new variable that removes "etcd-" from the master name 

export mycertmaster="etcd-peer-${mymaster:5}"

echo
echo "I will be using '$mymaster' as the etcd master."

echo
echo "Creating directory for certs"
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

./bin/resetpv \
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

