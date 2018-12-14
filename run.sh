docker run -it --rm --name=sysdig --privileged=true \
   --volume=/var/run/docker.sock:/host/var/run/docker.sock \
   --volume=/dev:/host/dev \
   --volume=/proc:/host/proc:ro \
   --volume=/boot:/host/boot:ro \
   --volume=/lib/modules:/host/lib/modules:ro \
   --volume=/usr:/host/usr:ro \
   sysdig/sysdig
