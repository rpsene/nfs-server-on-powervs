##About

This is a simple se of scripts that creates a new VM in PowerVS with 
aditional storage and configures it as NFS server. It works with either
CentOS or RHEL.

### Step 0: PowerVS Preparation Checklist

- [ ] **[Create a paid IBM Cloud Account](https://cloud.ibm.com/)**.
- [ ] **[Create an API key](https://cloud.ibm.com/docs/account?topic=account-userapikey)**.
- [ ] Add a new instance of an Object Storage Service (or reuse any existing one):
	- [ ] Create a new bucket.
	- [ ] Create a new credential with HMAC enabled.
	- [ ] Create and upload (or just upload if you already have it) the required .ova images.
- [ ] Add a new instance of the Power Virtual Service.
	- [ ] Create a private network and **[create a support ticket](https://cloud.ibm.com/unifiedsupport/cases/form)** to enable connectivity between the VMs within this private network. [Take a look at this video to learn how to create a new support ticket](https://youtu.be/S5ljNc2kU_A).
	- [ ] [Create the boot images](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-importing-boot-image).

You need to ensure you already have the boot images available in your PowerVS instance. Also, you need to install the ibmcloud CLI and connect to IBM Cloud. Consider using the [PowerVS Actions](https://github.com/rpsene/powervs-actions) to get started and **create a required public network**. An ova CentOS8 image is available [here](ftp://public.dhe.ibm.com/software/server/powervs/images/) for your convenience.

### Step 1: Deploy

```
	vi ./deploy.sh and add the respective values for these variables:

	VOLUME_SIZE=
	SERVER_IMAGE=
	PRIVATE_NETWORK=
	PUBLIC_NETWORK=
	SSH_KEY_NAME=
	SERVER_MEMORY=
	SERVER_PROCESSOR=
	SERVER_SYS_TYPE=
```

### Step 2: Configure the NFS Server

```
	ssh root@<SERVER IP>
	./create-nfs.sh <DEVICE>
	
	NOTES: you just need to set the last part of the device, for instance 
	(assuming you have /dev/mapper/mpatha):
	
	./create-nfs.sh mpatha
```

### Step 3: Configure the NFS Client

```
	dnf install nfs-utils
	mkdir -p /data/nfs-storage
	mount <SERVER IP>:/data/nfs-storage /data/nfs-storage
```

### Step 4: Details

You can get the ID of the VM and the additional storage created by looking 
at the directory created for each deployment. The file called server-build.log 
contains the details. You can use the [PowerVS Actions](https://github.com/rpsene/powervs-actions) 
to delete those resources when needed.

```
➜  nfs-server-powervs git:(master) ✗ tree -L 2
.
├── README.md
├── deploy.sh
├── nfs-server-0d3a56c8e5
│   ├── server-build.log
│   ├── server.log
│   └── volume.log
```
