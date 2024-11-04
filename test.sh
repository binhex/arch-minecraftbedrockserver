set -x
trap 'running=false' SIGINT SIGTERM; running=true; while $running; do echo "hello"; sleep 2s; done
