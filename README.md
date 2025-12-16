 # Clone ESX VM on service console without vCenter

This tool automates cloning of a powered-off ESX VM without the need for vCenter by using the ESX service console via SSH.

## Description

Clones a VM directly within an ESX host, without requiring vCenter. VM can be cloned to the same datastore, or a different one. The script uses `vmkfstools` to clone the disk, with a default disk format of `thin`.

The cloned VM's VMX file is updated with the new cloned name and pointers to the cloned disk. NVRAM is also copied.

The script clones whichever disks are configured in the VMX file, so if the VM has any snapshots, the script is cloning the current active disk(s), not any older snapshot. Snapshots do not need to be removed, nor does a snapshot need to be created (nor the script create one) in order to clone the original VM.

Functionally, the clone maintains the same MAC address and UUID of the original, so be sure to answer the VM question during clone power-on when prompted with "I copied it".

The following built-in VMware utilities are used, in addition to common Linux utilities (`grep`, `sed`, `awk`):

* `vim-cmd`
* `vmkfstools`

This tool was tested successfully on ESXi 8 and ESX 9 but should work on older versions as well.

## Pre-requisites

* VM must be registered on an ESX host
* VM must be powered off
* VM can have any number of snapshots, but only the current disk(s) will be used for the clone.
* ESX host must have SSH access enabled
* ESX host root password must be known. 
* Destination datastore must have sufficient free space. The script does not check, but will error if it cannot complete the cloning because of insufficient space.

1. If not already running, start the `TSM-SSH` service on the ESX host where the VM is registered.
2. SSH as root to the host, using the root password.
3. Download script directly to host if it has Internet access and mark it executable:

```shell
wget -O /tmp/clone-vm.sh https://raw.githubusercontent.com/ch0use/clone-esx-vm/refs/heads/main/clone-vm.sh && chmod +x /tmp/clone-vm.sh 
```

4. If the host does not have Internet access, download the script locally and then SCP it to the ESX host and mark it executable:

```shell
wget -O clone-vm.sh https://raw.githubusercontent.com/ch0use/clone-esx-vm/refs/heads/main/clone-vm.sh
scp clone-vm.sh root@<ESX hostname>:/tmp/.
ssh root@<ESX hostname>

[root@<ESX hostname>:~] chmod +x /tmp/clone-vm.sh
```

5. Clone the VM using the script:

```shell
/tmp/clone-vm.sh <original VM name> <cloned VM name> <cloned VM datastore> <optional disk format type, default: thin>
```

Example:

Clones the registered/powered-off VM `vcf-sddc-downloaded` to a new VM called `vcf-sddc`, on the datastore `datastore1`, using the `thin` disk format (default)

```shell
[root@esx01:~] /tmp/clone-vm.sh vcf-sddc-downloaded vcf-sddc datastore1

Tue Dec 16 14:22:57 UTC 2025 Found VM vcf-sddc-downloaded registered on host:
5 vcf-sddc-downloaded [nas] vcf-sddc-downloaded/vcf-sddc-downloaded.vmx vmwarePhoton64Guest vmx-13
lrwxr-xr-x    1 root     root            35 Dec 16 14:22 /vmfs/volumes/datastore1 -> 69407648-5a2f3798-01da-3805253367b4
-rwxrwxrwx    1 1024     users         3862 Dec 12 21:16 /vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded.vmx
Tue Dec 16 14:22:57 UTC 2025 All checks passed, creating destination VM folder at /vmfs/volumes/datastore1/vcf-sddc
Tue Dec 16 14:22:57 UTC 2025 Customizing /vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded.vmx to vcf-sddc and saving to /vmfs/volumes/datastore1/vcf-sddc/vcf-sddc.vmx ...
Tue Dec 16 14:22:57 UTC 2025 Copying NVRAM file from /vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded.nvram to /vmfs/volumes/datastore1/vcf-sddc/vcf-sddc.nvram
Tue Dec 16 14:22:57 UTC 2025 Cloning disk vcf-sddc-downloaded.vmdk using thin format ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded.vmdk'...
Clone: 100% done.
Tue Dec 16 14:27:53 UTC 2025 Cloning completed successfully.
Tue Dec 16 14:27:53 UTC 2025 Cloning disk vcf-sddc-downloaded_1.vmdk using thin format ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded_1.vmdk'...
Clone: 100% done.
Tue Dec 16 14:30:21 UTC 2025 Cloning completed successfully.
Tue Dec 16 14:30:21 UTC 2025 Cloning disk vcf-sddc-downloaded_2.vmdk using thin format ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded_2.vmdk'...
Clone: 100% done.
Tue Dec 16 15:07:19 UTC 2025 Cloning completed successfully.
Tue Dec 16 15:07:19 UTC 2025 Cloning disk vcf-sddc-downloaded_3.vmdk using thin format ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded_3.vmdk'...
Clone: 100% done.
Tue Dec 16 16:26:42 UTC 2025 Cloning completed successfully.
Tue Dec 16 16:26:42 UTC 2025 Cloning disk vcf-sddc-downloaded_4.vmdk using thin format ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded_4.vmdk'...
Clone: 100% done.
Tue Dec 16 16:30:44 UTC 2025 Cloning completed successfully.
Tue Dec 16 16:30:44 UTC 2025 Cloning disk vcf-sddc-downloaded_5.vmdk using thin format ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/nas/vcf-sddc-downloaded/vcf-sddc-downloaded_5.vmdk'...
Clone: 100% done.
Tue Dec 16 16:44:17 UTC 2025 Cloning completed successfully.
Tue Dec 16 16:44:17 UTC 2025 Registering cloned VM on host from /vmfs/volumes/datastore1/vcf-sddc/vcf-sddc.vmx ...
6
[root@esx01:~]
```

6. When cloning finishes, within the ESX Host Client, power on the new VM and select "I Copied it" when prompted.

## Notes

* According to Broadcom's [Cloning and converting virtual machine disks with vmkfstools](https://knowledge.broadcom.com/external/article/343140/cloning-and-converting-virtual-machine-d.html), the disk controller may be changed to an LSI controller, even if Paravirtual was selected. Double check the disk controller if any boot issues are observed.
* Cloning speed depends on disk size, CPU/mem of the ESX host, and any storage path bottlenecks.
* Run `vmkstools` to see the differen options for disk format:
  * `zeroedthick`
  * `thin` (default, recommended)
  * `eagerzeroedthick`

## Troubleshooting

The script has multiple checks built in to it and will exit if any of them fail:

* VM not found on host
* VM not powered off
* Destination datastore not found (only provide the datastore name, not the full `/vmfs/volumes/datastores/...` path)
* VM VMX file not found
* Can't create clone directory on destination datastore
* Can't customize cloned VMX on destination datastore
* Can't copy NVRAM to cloned VM folder on destination datastore
* Cloning an individual disk fails for any reason (script will continue)
* Can't register cloned VM on host
