$TTL 86400      ; 1 day
@     IN SOA dns.example.com. postmaster.example.com. (
                                1          ; serial
                                21600      ; refresh (6 hours)
                                3600       ; retry (1 hour)
                                604800     ; expire (1 week)
                                21600      ; minimum (6 hours)
                                )
@     IN  NS      dns.example.com.
$ORIGIN example.com.
nodo1	    IN	A	10.1.1.101
nodo2   	IN	A	10.1.1.102
dns		    IN  A	10.1.1.103


www         IN  CNAME   www.http
http        IN  NS      nodo1
http	    IN  NS      nodo2

