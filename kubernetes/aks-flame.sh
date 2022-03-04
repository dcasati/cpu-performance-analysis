#!/usr/bin/env bash
#set -eo pipefail

__usage="
    -p	pod to be profiled
    -c	the name of the container inside of the pod.
    -t	time to run the profiler in seconds. Defaults to 30 seconds.
    -i	image name of the profiler.
    -x	action to be executed. See options below. 

Possible verbs are:
    list-images		list available images for the profiler.
"
usage() {
 echo "usage: ${0##*/} [options]"
 echo "${__usage/[[:space:]]/}"
 exit 1
}

do_list_images() {
  echo -e "\nAvailable images for the profiler"
  echo "----------------"
  curl -s https://registry.hub.docker.com/v2/repositories/dcasati/ebpf-tools/tags | jq -r '."results"[]["name"]'
  exit 0
}

exec_case() {
    local _opt=$1

    case ${_opt} in
    list-images)    do_list_images;;
    *)              usage;;
    esac
    unset _opt
}


main() {
 local bpfprofilername=ebpf-profiler

 while getopts "c:i:p:t:x:" opt; do
  case $opt in
   c) BPF_TOOLS_CONTAINER="${OPTARG}" ;;
   i) BPF_TOOLS_IMAGE="${OPTARG}" ;;
   p) BPF_TOOLS_POD="${OPTARG}" ;;
   t) BPF_TOOLS_SECONDS="${OPTARG}" ;;
   x) exec_flag=true
      EXEC_OPT="${OPTARG}" ;;
   *) usage ;;
  esac
 done
 shift $(($OPTIND - 1))

 if [ $OPTIND = 1 ]; then
  usage
  exit 0
 fi

 if [[ "${exec_flag}" == "true" ]]; then
    exec_case ${EXEC_OPT}
 fi

 [ -z "${BPF_TOOLS_POD+x}" ] && echo 'missing --pod, try --help' && return 1
 [ -z "${BPF_TOOLS_CONTAINER+x}" ] && echo 'missing --container, try --help' && return 1
 
 if [ -z "${BPF_TOOLS_IMAGE+x}" ]; then 
    BPF_TOOLS_IMAGE=$(kubectl describe no/aks-general-13253007-vmss000006 | sed -n -E 's/\s+Kernel\sVersion:\s+(.*)/\1/p')
    BPF_TOOLS_IMAGE=dcasati/ebpf-tools:${BPF_TOOLS_IMAGE}
    echo "using $BPF_TOOLS_IMAGE as an image'"
 fi
 
 if [ -z "${BPF_TOOLS_SECONDS+x}" ]; then 
    BPF_TOOLS_SECONDS=30
 fi

 BPF_TOOLS_NODE=$(kubectl get po "${BPF_TOOLS_POD}" -o=go-template='{{.spec.nodeName}}')

 cat ebpf-profiler.yaml |
  sed 's@{{BPF_TOOLS_IMAGE}}@'"$BPF_TOOLS_IMAGE"'@' |
  sed 's@{{BPF_TOOLS_POD}}@'"$BPF_TOOLS_POD"'@' |
  sed 's@{{BPF_TOOLS_SECONDS}}@'"$BPF_TOOLS_SECONDS"'@' |
  sed 's@{{BPF_TOOLS_CONTAINER}}@'"$BPF_TOOLS_CONTAINER"'@' |
  sed 's@{{BPF_TOOLS_NODE}}@'"$BPF_TOOLS_NODE"'@' |
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
  completed_flag=$(kubectl logs $bpfprofilername | grep "profiling complete")
  [ -z "$completed_flag" ] && sleep 5
 done

 #get the svg
 kubectl cp "${bpfprofilername}":/"${BPF_TOOLS_CONTAINER}".svg ./"${BPF_TOOLS_CONTAINER}".svg #2>/dev/null
 echo "created ${BPF_TOOLS_CONTAINER}.svg"

 kubectl delete po $bpfprofilername
 echo "done"

}

main "$@"
exit 0
