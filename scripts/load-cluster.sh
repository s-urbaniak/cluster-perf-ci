#!/bin/bash

set -x

pushd /tmp
curl -sS https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz | tar xz
export PATH=${PATH}:/tmp

token=$(oc sa get-token -n openshift-monitoring prometheus-k8s)
prometheus_url=https://$(oc get route -n openshift-monitoring prometheus-k8s -o yaml -o jsonpath="{.spec.host}")
warmup=https://raw.githubusercontent.com/rsevilla87/cluster-perf-ci/master/warm-up.yml
load_cluster=https://raw.githubusercontent.com/rsevilla87/cluster-perf-ci/master/load-cluster.yml
control_plane_labels="app=openshift-kube-apiserver app=kube-controller-manager app=etcd"


git clone https://github.com/cloud-bulldozer/kube-burner.git --depth=1
pushd kube-burner
# Compile kube-burner
make build -j $(nproc)
# Wait for control plane pods to be ready
for label in ${control_plane_labels}; do
  oc wait pod --for=condition=Ready -A -l ${label} --timeout=300s
done

# Warm-up
./bin/kube-burner init -c ${warmup} -u ${prometheus_url} -t ${token} -a https://raw.githubusercontent.com/rsevilla87/cluster-perf-ci/master/alert-profiles/generalistic.yml --uuid $(uuidgen)

# Load-cluster
./bin/kube-burner init -c ${load_cluster} -u ${prometheus_url} -t ${token} -a https://raw.githubusercontent.com/rsevilla87/cluster-perf-ci/master/alert-profiles/generalistic.yml --uuid $(uuidgen) -m https://raw.githubusercontent.com/rsevilla87/cluster-perf-ci/master/metric-profiles/metrics.yml