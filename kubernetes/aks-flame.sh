#!/usr/bin/env bash
#set -eo pipefail

__usage="
  Usage aks-flame --option <argument>

	OPTIONS:
    -p or --pod=<kubernetes pod name>
    -c or --container=<kubernetes container name>
    -t or --time=<time in seconds, default 30 seconds>
    -i or --image-for-profiler=<docker image for profiler to use>
"
usage() {
    echo "usage: ${0##*/} [options]"
    echo "${__usage/[[:space:]]/}"
    exit 1
}

main() {
  while getopts "c:i:p:t:" opt; do
    case $opt in
    c)  BPF_TOOLS_CONTAINER="${OPTARG}";;
    i)  BPF_TOOLS_IMAGE="${OPTARG}";;
    p)  BPF_TOOLS_POD="${OPTARG}";;
    t)  BPF_TOOLS_SECONDS="${OPTARG}";;
    *)  usage;;
    esac
  done
  shift $(( $OPTIND - 1 ))

  if [ $OPTIND = 1 ]; then
      usage
      exit 0
  fi


   bpfprofilername=ebpf-profiler
    [ -z "${BPF_TOOLS_POD}" ] && echo 'missing --pod, try --help' && return 1
    [ -z "${BPF_TOOLS_CONTAINER}" ] && echo 'missing --container, try --help' && return 1
    [ -z "${BPF_TOOLS_IMAGE}" ] && echo 'missing --image-for-profiler, try --help' && return 1
    [ -z "${BPF_TOOLS_SECONDS}" ] && BPF_TOOLS_SECONDS=30 && return 1

    BPF_TOOLS_NODE=$(kubectl get po ${BPF_TOOLS_POD} -o=go-template='{{.spec.nodeName}}')

    cat ./ebpf-profiler.yaml | \
    sed 's@{{BPF_TOOLS_IMAGE}}@'"$BPF_TOOLS_IMAGE"'@' | \
    sed 's@{{BPF_TOOLS_POD}}@'"$BPF_TOOLS_POD"'@' | \
    sed 's@{{BPF_TOOLS_SECONDS}}@'"$BPF_TOOLS_SECONDS"'@' | \
    sed 's@{{BPF_TOOLS_CONTAINER}}@'"$BPF_TOOLS_CONTAINER"'@' | \
    sed 's@{{BPF_TOOLS_NODE}}@'"$BPF_TOOLS_NODE"'@' | tee ouput.yaml | \
    kubectl apply -f -

    #wait for profiler to run
    running=""
    while [ -z "$running" ]; do
        running=$(kubectl get pods "$bpfprofilername" | grep "Running")
        [ -z "$running" ] && sleep 1
        
    done

    #wait for profiler to complete
    completed_flag=""
    echo "profiling pod ${BPF_TOOLS_POD} ..."
    while [ -z "$completed_flag" ]; do
        completed_flag=$(kubectl logs  $bpfprofilername | grep "profiling complete")
        [ -z "$completed_flag" ] && sleep 5
    done

    #get the svg
    kubectl cp ${bpfprofilername}:/${BPF_TOOLS_CONTAINER}.svg ./${BPF_TOOLS_CONTAINER}.svg #2>/dev/null
    echo "created ${BPF_TOOLS_CONTAINER}.svg"

    kubectl delete po $bpfprofilername
    echo "done"

}

main "$@"
exit 0
