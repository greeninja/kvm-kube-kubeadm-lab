
#!/bin/bash                                                                                                                                                          
                                                                                                                                                                     
# Network Vars                                                                    
dns_domain="kubernetes.lab"


##### Start #####

# Remove the Bastion VM

for i in bastion lb; do
virsh destroy $i.$dns_domain
virsh undefine $i.$dns_domain --remove-all-storage
done

# Remove Kube VMs

for i in `seq -w 01 03`; do
  for p in kube-master kube-worker; do
    virsh destroy $p$i.$dns_domain
    virsh undefine $p$i.$dns_domain --remove-all-storage
  done
done

# Remove Network files

echo "Removing kubernetes-lab xml file"

rm $tmp_dir/kubernetes-lab.xml -rf

echo "Removing kubernetes networks in libvirt"

for network in kubernetes-lab; do
  virsh net-destroy $network
  virsh net-undefine $network
done
