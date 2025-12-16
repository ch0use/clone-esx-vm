#!/bin/sh

if [[ -z ${3} ]]; then
    echo "Usage: ${0} <vm source name> <vm clone name> <vm clone datastore name> <optional vm clone disk format: thin(default)|zerotedthick|eagerzeroredthick|2gbsparse"
    exit 1
fi

VM_NAME_SOURCE=$1
VM_NAME_CLONE=$2
VM_DS_CLONE=$3

if [[ -z ${4} ]]; then
    VM_CLONE_DISK_FORMAT="thin"
else
    VM_CLONE_DISK_FORMAT=$4
fi

VIM_OUTPUT=$(vim-cmd vmsvc/getallvms | grep ${VM_NAME_SOURCE})
if [[ ${?} -gt 0 ]]; then
    echo "$(date) Could not find VM ${VM_NAME_SOURCE} registered on host! Check output of vim-cmd vmsvc/getallvms"
    exit 1
else
    echo "$(date) Found VM ${VM_NAME_SOURCE} registered on host:"
    echo ${VIM_OUTPUT}
fi

VM_DS_CLONE_PATH="/vmfs/volumes/${VM_DS_CLONE}"
ls -la ${VM_DS_CLONE_PATH}
if [[ ${?} -gt 0 ]]; then
    echo "$(date) Could not find clone destination datastore ${VM_DS_CLONE}!"
    exit 1
fi

VM_DS_SOURCE=$(echo ${VIM_OUTPUT} | cut -d "[" -f 2 | cut -d "]" -f 1)
VM_VMX_SOURCE=$(echo ${VIM_OUTPUT} | awk '{print($4)}')
VM_VMX_PATH_SOURCE="/vmfs/volumes/${VM_DS_SOURCE}/${VM_VMX_SOURCE}"

ls -la ${VM_VMX_PATH_SOURCE}
if [[ ${?} -gt 0 ]]; then
    echo "$(date) Some error locating VMX file at ${VM_VMX_PATH_SOURCE}, not found!"
    exit 1
fi

VM_PATH_CLONE="${VM_DS_CLONE_PATH}/${VM_NAME_CLONE}"
echo "$(date) All checks passed, creating destination VM folder at ${VM_PATH_CLONE}"
mkdir -p ${VM_PATH_CLONE}
if [[ ${?} -gt 0 ]]; then
    echo "$(date) Some error creating destination directory ${VM_PATH_CLONE}!"
    exit 1
fi

echo "$(date) Customizing ${VM_VMX_PATH_SOURCE} to ${VM_NAME_CLONE} and saving to ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx ..."
sed "s/${VM_NAME_SOURCE}/${VM_NAME_CLONE}/g" ${VM_VMX_PATH_SOURCE} | grep -v vmdk > ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx
if [[ ${?} -gt 0 ]]; then
    echo "$(date) Some error customizing VMX at ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx!"
    exit 1
fi

VM_NVRAM_SOURCE=$(grep -i nvram ${VM_VMX_PATH_SOURCE} | cut -d "\"" -f 2)
VM_HOMEDIR_SOURCE=$(dirname ${VM_VMX_PATH_SOURCE})
echo "$(date) Copying NVRAM file from ${VM_HOMEDIR_SOURCE}/${VM_NVRAM_SOURCE} to ${VM_PATH_CLONE}/${VM_NAME_CLONE}.nvram"
cp ${VM_HOMEDIR_SOURCE}/${VM_NVRAM_SOURCE} ${VM_PATH_CLONE}/${VM_NAME_CLONE}.nvram
if [[ ${?} -gt 0 ]]; then
    echo "$(date) Some error copying NVRAM from ${VM_HOMEDIR_SOURCE}/${VM_NVRAM_SOURCE} to ${VM_PATH_CLONE}/${VM_NAME_CLONE}.nvram!"
    exit 1
fi

VM_DISKS_SOURCE=$(grep vmdk ${VM_VMX_PATH_SOURCE} | cut -d "\"" -f 2)
for VM_DISK in ${VM_DISKS_SOURCE}; do
    echo "$(date) Cloning disk ${VM_DISK} using ${VM_CLONE_DISK_FORMAT} format ..."
    # need to add -W vsan if source is on VSAN datastore
    vmkfstools -i "${VM_HOMEDIR_SOURCE}/${VM_DISK}" "${VM_PATH_CLONE}/${VM_DISK}" -d ${VM_CLONE_DISK_FORMAT}
    if [[ ${?} -gt 0 ]]; then
        echo "$(date) Some error cloning ${VM_HOMEDIR_SOURCE}/${VM_DISK} to ${VM_PATH_CLONE}/${VM_DISK} using ${VM_CLONE_DISK_FORMAT} format! Continuing ..."
    else
        SCSI_PATH=$(grep ${VM_DISK} ${VM_VMX_PATH_SOURCE} | cut -d "=" -f 1)
        echo "$(date) Cloning completed successfully."
        echo "${SCSI_PATH} = \"${VM_DISK}\"" >> ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx
    fi
done

echo "$(date) Registering cloned VM on host from ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx ..."
vim-cmd solo/registervm ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx
if [[ ${?} -gt 0 ]]; then
    echo "$(date) Some error registering cloned VM on host! Check ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx and try again manually using vim-cmd solo/registervm ${VM_PATH_CLONE}/${VM_NAME_CLONE}.vmx"
    exit 1
fi
