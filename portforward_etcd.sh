#!/bin/bash

OC_CMD=oc
echo
echo "Launching port-forward.."

if ! command -v $OC_CMD &> /dev/null
then
  echo
  echo "Cannot find '$OC_CMD' command."
  echo "Terminating."
  exit
fi

# Test to see if we are logged into the cluster

echo
echo "Are we logged into the cluster?"
$OC_CMD whoami

if [[ $? -ne 0 ]]
then
  echo
  echo "You are not logged into cluster."
  echo "Terminating."
  exit
else
  echo
  echo "You are logged into cluster, continuing."
  echo
fi

# Get an etcdmaster
export mymaster=$($OC_CMD get pods -l app=etcd -n openshift-etcd -o jsonpath='{range .items[0]}{.metadata.name}{"\n"}{end}')

# pod is named: etcd-master0.cluster1.example.local
# but cert is named: etcd-peer-master0.cluster1.example.local
# Create a new variable that removes "etcd-" from the master name 

echo
echo "I will be using '$mymaster' as the etcd master..."

oc port-forward pods/$mymaster 2379:2379 -n openshift-etcd

#EOF
