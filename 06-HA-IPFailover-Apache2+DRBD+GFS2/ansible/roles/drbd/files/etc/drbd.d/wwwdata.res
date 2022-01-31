resource wwwdata {
     protocol C;
     meta-disk internal;
     device /dev/drbd1;
     syncer {
      verify-alg sha1;
     }
     net {
      allow-two-primaries;
     }
     on nodo1 {
      disk   /dev/vdb;
      address  10.1.1.101:7789;
     }
     on nodo2 {
      disk   /dev/vdb;
      address  10.1.1.102:7789;
     }
    }
