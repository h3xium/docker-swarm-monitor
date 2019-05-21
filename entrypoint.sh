#!/bin/bash

# Output version
echo -e "\nStarting swarm-monitor ${VERSION} ..."

# Set redirect url
echo -e "\nSetting redirect url in index.html to 'http://${CHK_URL}' ..."
sed -i "s|{URL}|${CHK_URL}|g" /usr/share/nginx/html/index.html

echo -e "\nStarting nginx ..."
/usr/sbin/nginx

echo -e "\nStarting to monitor the following services:"
for service in $CHK_SERVICES
do
    echo "  * ${service%%.*}"
done

while true;
do
    case $CHK_MONITOR in
        "prtg")
            output="{ \"prtg\": { \"result\": ["
            for service in $CHK_SERVICES
            do
                expected="${service##*.}"
                service="${service%%.*}"

                check=$(curl -sg --unix-socket /var/run/docker.sock http://$CHK_DOCKER_API_VERSION/tasks?filters={%22service%22:[%22$service%22]} | jq '.[]? | select((.Status.State|index("running")>=0))? | .ID?' | wc -l)
                
                state="0"
                if [ $check = $expected ]; then
                    state="1"
                fi

                output="$output { \"channel\": \"$service\", \"value\": \"$state\" },"
            done
            output="$output { \"channel\": \"updated\", \"value\": \"$(date +%s)\" } ] } }"          
            ;;

        *)
            output="{ \"Warning\": \"Monitor '$CHK_MONITOR' is unsupported.\" }"
            ;;
    esac
    
    echo $output | jq '.' > /usr/share/nginx/html/status.json
    
    sleep $CHK_INTERVAL
done