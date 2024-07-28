# Pre-requiesites
# Check MAC and default gateway address 
    ip link --> ( Should be unique for every host/VM )
    ip r  --> ( there should min single route with default via, Kubernetes picks the first IP to use as advertise address for its components if multiple default gateway are present, if there is no default gateway custom IP should be provided during kubeadm init command arguments )

# Open the necessary port to allow inbound traffic ( Customisable other than defaults )
    a. 6443 APISERVER --> ( Kubelet of worker node )
    b. 2379-2380 --> ( API server - external etcd)
    c. 10250 Kubelet --> ( API server )
    d. 10256 Kubeproxy
    e. 30000-32767 Nodeport 
    
    to check nc 127.0.0.1 <port> -v


# Disable swap ( not needed if kubelet is configured to use swap )
    swapoff -a --> ( Turns of swap memory temperovarily )
    vi /etc/fstab --> ( comment out the line with SWAP and save to permanently disable swap)
    mount -a --> ( for changes to reflect without reboot )
    free -h --> ( to check the swap memory usage should be 0)
    blkid --> ( provides the mount point for swap ppartition )
    lsblk --> ( shows disks partition and mount point )

# Enable IP forwarding --> ( Needed for k8s components to communicate to each other )
    # sysctl params required by setup, params persist across reboots
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
    # Apply sysctl params without reboot
    sudo sysctl --system
    sysctl net.ipv4.ip_forward  --> ( Verify that net.ipv4.ip_forward is set to 1 )

# Install runtime
# Step 1: Installing containerd --> ( Runtime interface )
    Download the containerd-<VERSION>-<OS>-<ARCH>.tar.gz archive from https://github.com/containerd/containerd/releases , verify its sha256sum, and extract it under /usr/local:

    $ wget https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz --> ( Download binary )
    $ sudo tar Cxzvf /usr/local containerd-1.6.2-linux-amd64.tar.gz --> ( unzip tar file )
        bin/
        bin/containerd-shim-runc-v2
        bin/containerd-shim
        bin/ctr
        bin/containerd-shim-runc-v1
        bin/containerd
        bin/containerd-stress

    If you intend to start containerd via systemd, you should also download the containerd.service unit file from https://raw.githubusercontent.com/containerd/containerd/main/containerd.service into /usr/local/lib/systemd/system/containerd.service, and run the following commands:
    
    wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service --> ( download systemd custom unit file )
    sudo mv containerd.service /lib/systemd/system/containerd.service --> ( copy the unit configuration file default location )
    sudo systemctl daemon-reload 
    sudo systemctl enable --now containerd

# Step 2: Installing runc --> ( OCI runtime, interacts with kernel to provide resources )
    Download the runc.<ARCH> binary from https://github.com/opencontainers/runc/releases , verify its sha256sum, and install it as /usr/local/sbin/runc.

    $ wget https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64
    $ sudo install -m 755 runc.amd64 /usr/local/sbin/runc

# Configure cgroup driver of runtime ( match kubelet cgroup drive (systemd by default))
    
    To use the systemd cgroup driver in /etc/containerd/config.toml with runc, set

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        ...
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true

    sudo mkdir /etc/containerd/
    sudo containerd config default > config.toml
    sudo mv config.toml /etc/containerd/
    sudo sed -ie "s/SystemdCgroup = False/SystemdCgroup = true/g" /etc/containerd/config.toml
    sudo systemctl restart containerd

# Installing binaries ( Kubelet, Kubectl, Kubeadm)
  These instructions are for Kubernetes v1.30.

    sudo apt-get update
    # apt-transport-https may be a dummy package; if so, you can skip that package
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
        
    Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:
    # If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:

    sudo apt-get update 
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    (Optional) Enable the kubelet service before running kubeadm:
    sudo systemctl enable --now kubelet

# Start the cluster creation

    sudo kubeadm init 

# Connect to the cluster
    To start using your cluster, you need to run the following as a regular user:

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    Alternatively, if you are the root user, you can run:

    export KUBECONFIG=/etc/kubernetes/admin.conf

# deploy a pod network to the cluster.
    curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml -O
    kubectl apply -f calico.yaml
    kubectl get pods --all-namespaces

# Join any number of worker nodes
sudo kubeadm join <api-server-ip>:6443 --token <join-token> --discovery-token-ca-cert-hash <ca-cert-hash> 




    
