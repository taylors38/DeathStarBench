# This Fork

The goal of this fork was to port DeathStarBench from docker to kubernetes. This fork aims to create a plain kubernetes port rather then using helm or openshift.
This fork is also has a few things specific to deploying DeathStarBench on UTA servers, namely the files to startup and tear down the deployment.
So far, all three applications (hotelReservation, mediaServices, socialNetwork) have been ported and are functional.

# A Few Notes About This Fork

 * The frontend for all services is exposed via a NodePort on port 30080
 * The kubernetes files for this fork are in the kubernetes/ directory
 * All applications deploy to the default namespace
 * If you edit any configurating or lua scripts you will have to recreate the configmap for it
 * If you deploy mediaServices or socialNetwork to a namespace other than default you WILL have to update the `fqdn_suffix` environment variable in the nginx deployment.

 The script setup-k8s-cluster.sh is written to ssh into the servers and setup a cluster. It is suppose to be executed off cluster.
 The script reset-k8s-cluster.sh resets kubernetes and cleans up the environment.

 These two scipts are highly specific to my environment. You WILL have to edit them for your environment, if you decide to use them.
 The scripts do show how I setup the cluster and are good reference. I strongly suggest skimming through them if you are creating your own cluster.

 To deploy an application run `kubectl apply -Rf kubernetes/`

 To tear down deployment run `kubectl delete -Rf kubernetes/`

 The `-R` option is only needed to hotelReservation.

# DeathStarBench

Open-source benchmark suite for cloud microservices. DeathStarBench includes five end-to-end services, four for cloud systems, and one for cloud-edge systems running on drone swarms. 

## End-to-end Services <img src="microservices_bundle4.png" alt="suite-icon" width="40"/>

* Social Network (released)
* Media Service (released)
* Hotel Reservation (released)
* E-commerce site (in progress)
* Banking System (in progress)
* Drone coordination system (in progress)

## License & Copyright 

DeathStarBench is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.

DeathStarBench is being developed by the [SAIL group](http://sail.ece.cornell.edu/) at Cornell University. 

## Publications

More details on the applications and a characterization of their behavior can be found at ["An Open-Source Benchmark Suite for Microservices and Their Hardware-Software Implications for Cloud and Edge Systems"](http://www.csl.cornell.edu/~delimitrou/papers/2019.asplos.microservices.pdf), Y. Gan et al., ASPLOS 2019. 

If you use this benchmark suite in your work, we ask that you please cite the paper above. 


## Beta-testing

If you are interested in joining the beta-testing group for DeathStarBench, send us an email at: <microservices-bench-L@list.cornell.edu>
