

#!/bin/bash
                                                         
# Node building vars                                                                                               
image_dir="/var/lib/libvirt/images"
base_os_img="/var/lib/libvirt/images/iso/CentOS-7-x86_64-GenericCloud.qcow2"
ssh_pub_key="/root/.ssh/id_ed25519.pub"

# Network Vars
dns_domain="kubernetes.lab"

# Extra Vars
root_password="password"
os_drive_size="120G"
tmp_dir="/tmp"

# You shouldn't have to change anything below here
                                                         
#################                                                         
##### Start #####
#################

                                                         
# Exit on any failure  
                                                         
set -e           
                                                         
# Create Network files

netname="kubernetes-lab"                                                                                             
                                                                                                                   
echo "Creating $netname xml file"                                                                               
                                                         
cat <<EOF > $tmp_dir/$netname.xml
<network>                            
  <name>$netname</name>
  <bridge name="virbr6443"/>
  <forward mode="nat"/>
  <domain name="kubernetes.lab"/>
  <ip address="10.44.60.1" netmask="255.255.255.0">    <dhcp>
      <range start="10.44.60.10" end="10.44.60.100"/>
    </dhcp>
  </ip>   
</network>               
EOF

echo "Creating kubernetes network in libvirt"

check_rep=$(virsh net-list --all | grep $netname >/dev/null && echo "0" || echo "1")

networks=()

if [[ $check_rep == "1" ]]; then
  networks+=("$netname")
fi

net_len=$(echo "${#networks[@]}")

if [ "$net_len" -ge 1 ]; then
  for network in ${networks[@]}; do 
    virsh net-define $tmp_dir/$network.xml
    virsh net-start $network
    virsh net-autostart $network
  done
else
  echo "Network already created"
fi

# Check OS image exists

if [ -f "$base_os_img" ]; then
  echo "Base OS image exists"
else
  echo "Base image doesn't exist ($base_os_img). Exiting"
  exit 1
fi

echo "Building Bastion node"

check=$(virsh list --all | grep bastion.$dns_domain > /dev/null && echo "0" || echo "1" )
if [[ $check == "0" ]]; then
  echo "bastion.$dns_domain already exists"
else
  echo "Starting Bastion"
  echo "Creating $image_dir/bastion.$dns_domain.qcow2 at $os_drive_size"
  qemu-img create -f qcow2 $image_dir/bastion.$dns_domain.qcow2 $os_drive_size
  echo "Resizing base OS image"
  virt-resize --expand /dev/sda1 $base_os_img $image_dir/bastion.$dns_domain.qcow2
  echo "Customising OS for bastion"
  virt-customize -a $image_dir/bastion.$dns_domain.qcow2 \
    --root-password password:$root_password \
    --uninstall cloud-init \
    --install bind-utils \
    --hostname bastion.$dns_domain \
    --ssh-inject root:file:$ssh_pub_key \
    --selinux-relabel
  echo "Defining bastion"
  virt-install --name bastion.$dns_domain \
    --virt-type kvm \
    --memory 4096 \
    --vcpus 2 \
    --boot hd,menu=on \
    --disk path=$image_dir/bastion.$dns_domain.qcow2,device=disk \
    --os-type Linux \
    --os-variant centos7 \
    --network network:$netname \
    --graphics spice \
    --noautoconsole 
fi

count=1
host_prefix="kube-master"
for i in `seq -w 01 03`; do 
  check=$(virsh list --all | grep $host_prefix$i.$dns_domain > /dev/null && echo "0" || echo "1" )
  if [[ $check == "0" ]]; then
    echo "$host_prefix$i.$dns_domain already exists"
    count=$(( $count + 1 ))
  else
    echo "Starting $host_prefix$i"
    echo "Creating $image_dir/$host_prefix$i.$dns_domain.qcow2 at $os_drive_size"
    qemu-img create -f qcow2 $image_dir/$host_prefix$i.$dns_domain.qcow2 $os_drive_size
    echo "Resizing base OS image"
    virt-resize --expand /dev/sda1 $base_os_img $image_dir/$host_prefix$i.$dns_domain.qcow2
    echo "Customising OS for gluster$i"
    virt-customize -a $image_dir/$host_prefix$i.$dns_domain.qcow2 \
      --root-password password:$root_password \
      --uninstall cloud-init \
      --hostname $host_prefix$i.$dns_domain \
      --ssh-inject root:file:$ssh_pub_key \
      --selinux-relabel
    echo "Defining gluster$i"
    virt-install --name $host_prefix$i.$dns_domain \
      --virt-type kvm \
      --memory 8192 \
      --vcpus 4 \
      --boot hd,menu=on \
      --disk path=$image_dir/$host_prefix$i.$dns_domain.qcow2,device=disk \
      --os-type Linux \
      --os-variant centos7 \
      --network network:$netname \
      --graphics spice \
      --noautoconsole
    
    count=$(( $count + 1 ))
  fi
done

count=1
host_prefix="kube-worker"
for i in `seq -w 01 03`; do 
  check=$(virsh list --all | grep $host_prefix$i.$dns_domain > /dev/null && echo "0" || echo "1" )
  if [[ $check == "0" ]]; then
    echo "$host_prefix$i.$dns_domain already exists"
    count=$(( $count + 1 ))
  else
    echo "Starting $host_prefix$i"
    echo "Creating $image_dir/$host_prefix$i.$dns_domain.qcow2 at $os_drive_size"
    qemu-img create -f qcow2 $image_dir/$host_prefix$i.$dns_domain.qcow2 $os_drive_size
    echo "Resizing base OS image"
    virt-resize --expand /dev/sda1 $base_os_img $image_dir/$host_prefix$i.$dns_domain.qcow2
    echo "Customising OS for gluster$i"
    virt-customize -a $image_dir/$host_prefix$i.$dns_domain.qcow2 \
      --root-password password:$root_password \
      --uninstall cloud-init \
      --hostname $host_prefix$i.$dns_domain \
      --ssh-inject root:file:$ssh_pub_key \
      --selinux-relabel
    echo "Defining gluster$i"
    virt-install --name $host_prefix$i.$dns_domain \
      --virt-type kvm \
      --memory 8192 \
      --vcpus 4 \
      --boot hd,menu=on \
      --disk path=$image_dir/$host_prefix$i.$dns_domain.qcow2,device=disk \
      --os-type Linux \
      --os-variant centos7 \
      --network network:$netname \
      --graphics spice \
      --noautoconsole
    
    count=$(( $count + 1 ))
  fi
done

# Print running VMs

virsh list
