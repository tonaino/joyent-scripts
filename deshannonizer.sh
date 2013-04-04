# Luigi Erardi docet
rootB=$(A=$(cat vnic | grep "^net" | tr -s " " | cut -d " " -f 7 | sort -u  ); for i in $A; do b=$(sdc-mapi /zones/$i | grep -c "HTTP/1.1 404 Not Found"); c=$(sdc-mapi /vms/$i | grep -c "HTTP/1.1 404 Not Found"); [ $b -gt 0 -a $c -gt 0 ] && echo $i ; done; ); for i in $B ; do grep "$i" vnic ; done
