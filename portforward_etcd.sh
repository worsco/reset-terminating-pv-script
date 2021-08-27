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

# Get an etcdmaster
export mymaster=$($OC_CMD get pods -l app=etcd -n openshift-etcd -o jsonpath='{range .items[0]}{.metadata.name}{"\n"}{end}')

# pod is named: etcd-master0.cluster1.example.local
# but cert is named: etcd-peer-master0.cluster1.example.local
# Create a new variable that removes "etcd-" from the master name 

echo
echo "I will be using '$mymaster' as the etcd master..."

oc port-forward pods/$mymaster 2379:2379 -n openshift-etcd

#EOF
