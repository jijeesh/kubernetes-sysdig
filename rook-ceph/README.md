
# Prerequisites

Rook can be installed on any existing Kubernetes clusters as long as it meets the minimum version and have the required privilege to run in the cluster (see below for more information). If you dont have a Kubernetes cluster, you can quickly set one up using [Minikube](#minikube), [Kubeadm](#kubeadm) or [CoreOS/Vagrant](#new-local-kubernetes-cluster-with-vagrant).

## Minimum Version

Kubernetes v1.10 or higher is supported by Rook.

## Privileges and RBAC

Rook requires privileges to manage the storage in your cluster. See the details [here](rbac.md) for setting up RBAC.

## Flexvolume Configuration

The Rook agent requires setup as a Flex volume plugin to manage the storage attachments in your cluster.
See the [Flex Volume Configuration](flexvolume.md) topic to configure your Kubernetes deployment to load the Rook volume plugin.

## Kernel modules directory configuration

Normally, on Linux, kernel modules can be found in `/lib/modules`. However, there are some distributions that put them elsewhere. In that case the environment variable `LIB_MODULES_DIR_PATH` can be used to override the default. Also see the documentation in [helm-operator](helm-operator.md) on the parameter `agent.libModulesDirPath`. One notable distribution where this setting is useful would be [NixOS](https://nixos.org).

## Extra agent mounts

On certain distributions it may be necessary to mount additional directories into the agent container. That is what the environment variable `AGENT_MOUNTS` is for. Also see the documentation in [helm-operator](helm-operator.md) on the parameter `agent.mounts`. The format of the variable content should be `mountname1=/host/path1:/container/path1,mountname2=/host/path2:/container/path2`.

## Bootstrapping Kubernetes

Rook will run wherever Kubernetes is running. Here are some simple environments to help you get started with Rook.

## Ceph and RBD utilities installed on the nodes
The Kubernetes kubelet shells out to system utilities to mount Rook volumes. This means that every Kubernetes host must have these utilities installed. This requirement extends to the control plane, since there may be interactions between kube-controller-manager and the Ceph cluster. Login to each Kubernetes host where Kubelet runs and execute the following:

For Debian-based distros:
```
apt-get install ceph-fs-common ceph-common
```
For Redhat-based distros:
```
yum install ceph
```

## Deploy the Rook Operator

The first step is to deploy the Rook system components, which include the Rook agent running on each node in your cluster as well as Rook operator pod.

```bash
cd cluster/examples/kubernetes/ceph
kubectl create -f operator.yaml

# verify the rook-ceph-operator, rook-ceph-agent, and rook-discover pods are in the `Running` state before proceeding
kubectl -n rook-ceph-system get pod
```

You can also deploy the operator with the [Rook Helm Chart](helm-operator.md).

## Create a Rook Cluster

Now that the Rook operator, agent, and discover pods are running, we can create the Rook cluster. For the cluster to survive reboots,
make sure you set the `dataDirHostPath` property that is valid for your hosts. For more settings, see the documentation on [configuring the cluster](ceph-cluster-crd.md).


Create the cluster:

```bash
kubectl create -f cluster.yaml
```

Use `kubectl` to list pods in the `rook` namespace. You should be able to see the following pods once they are all running.
The number of osd pods will depend on the number of nodes in the cluster and the number of devices and directories configured.

```bash
$ kubectl -n rook-ceph get pod
NAME                                   READY     STATUS      RESTARTS   AGE
rook-ceph-mgr-a-9c44495df-ln9sq        1/1       Running     0          1m
rook-ceph-mon-a-69fb9c78cd-58szd       1/1       Running     0          2m
rook-ceph-mon-b-cf4ddc49c-c756f        1/1       Running     0          2m
rook-ceph-mon-c-5b467747f4-8cbmv       1/1       Running     0          2m
rook-ceph-osd-0-f6549956d-6z294        1/1       Running     0          1m
rook-ceph-osd-1-5b96b56684-r7zsp       1/1       Running     0          1m
rook-ceph-osd-prepare-mynode-ftt57     0/1       Completed   0          1m
```


# Shared File System

A shared file system can be mounted with read/write permission from multiple pods. This may be useful for applications which can be clustered using a shared filesystem.

This example runs a shared file system for the [kube-registry](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/registry).

### Prerequisites

This guide assumes you have created a Rook cluster as explained in the main [Kubernetes guide](ceph-quickstart.md)

### Multiple File Systems Not Supported

By default only one shared file system can be created with Rook. Multiple file system support in Ceph is still considered experimental and can be enabled with the environment variable `ROOK_ALLOW_MULTIPLE_FILESYSTEMS` defined in `operator.yaml`.

Please refer to [cephfs experimental features](http://docs.ceph.com/docs/master/cephfs/experimental-features/#multiple-filesystems-within-a-ceph-cluster) page for more information.

## Create the File System

Create the file system by specifying the desired settings for the metadata pool, data pools, and metadata server in the `CephFilesystem` CRD. In this example we create the metadata pool with replication of three and a single data pool with erasure coding. For more options, see the documentation on [creating shared file systems](ceph-filesystem-crd.md).

The Rook operator will create all the pools and other resources necessary to start the service. This may take a minute to complete.
```bash
# Create the file system
$ kubectl create -f filesystem.yaml

# To confirm the file system is configured, wait for the mds pods to start
$ kubectl -n rook-ceph get pod -l app=rook-ceph-mds
NAME                                      READY     STATUS    RESTARTS   AGE
rook-ceph-mds-myfs-7d59fdfcf4-h8kw9       1/1       Running   0          12s
rook-ceph-mds-myfs-7d59fdfcf4-kgkjp       1/1       Running   0          12s
```


To see detailed status of the file system, start and connect to the [Rook toolbox](ceph-toolbox.md). A new line will be shown with `ceph status` for the `mds` service. In this example, there is one active instance of MDS which is up, with one MDS instance in `standby-replay` mode in case of failover.

```bash
$ ceph status
  ...
  services:
    mds: myfs-1/1/1 up {[myfs:0]=mzw58b=up:active}, 1 up:standby-replay
```

#  Rook Toolbox
The Rook toolbox is a container with common tools used for rook debugging and testing.
The toolbox is based on CentOS, so more tools of your choosing can be easily installed with `yum`.

## Running the Toolbox in Kubernetes

The rook toolbox can run as a deployment in a Kubernetes cluster.  After you ensure you have a running Kubernetes cluster with rook deployed (see the [Kubernetes](ceph-quickstart.md) instructions),
launch the rook-ceph-tools pod.


Launch the rook-ceph-tools pod:
```bash
kubectl create -f toolbox.yaml
```

Wait for the toolbox pod to download its container and get to the `running` state:
```bash
kubectl -n rook-ceph get pod -l "app=rook-ceph-tools"
```

Once the rook-ceph-tools pod is running, you can connect to it with:
```bash
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') bash
```

All available tools in the toolbox are ready for your troubleshooting needs.  Example:
```bash
ceph status
ceph osd status
ceph df
rados df
```
