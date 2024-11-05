# srv6-sonic-lab

## Prerequisites

- Kernel 6.6 or newer
- Git
- Docker

## Upgrade the kernel

This demo requires Linux kernel 6.6 or newer.
If you have an older kernel, you need to upgrade the kernel first.

The following steps can be used to upgrade the kernel on Debian 12:

1. Add **bookworm-backports** to **sources.list**:

```shell
# echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list
````

2. Update packages index:

```shell
apt-get update
```

3. Update the kernel:

```shell
apt-get install -t bookworm-backports linux-image-amd64
```

## How to deploy the topology

1. Clone this repository:

```shell
$ git clone https://github.com/cscarpitta/srv6-sonic-lab --branch srv6
```

2. cd to the repository folder:

```shell
$ cd srv6-sonic-lab
```

3. Deploy the topology

```shell
$ sudo bash ./deploy-topology.sh
```

## Access node CLI

This topology contains sonic10, sonic11, sonic20, sonic21, a0, a1, h0, h1.

You can access a node shell using the following command:

```shell
$ docker exec -it <NODE_NAME> bash
```

For example:

```shell
$ docker exec -it sonic10 bash
```
