# -*- mode: ruby -*-
# vi: set ft=ruby :

# ============================================================
# CONFIGURATION VARIABLES
# ============================================================
# Customize these variables to create as many VMs as needed

# Number of VMs to create
NUM_VMS = 4

# VM Configuration
VM_CONFIG = {
  box_image: "bento/ubuntu-24.04",
  box_version: "202510.26.0",
  memory: "1024",
  cpus: 1,
  base_ip: "192.168.56",
  starting_ip: 101,
  hostname_prefix: "omni",
  vm_name_prefix: "Omni-VM",
  vm_group: "/Main-VMs"
}

# ============================================================
# VAGRANT CONFIGURATION
# ============================================================

Vagrant.configure("2") do |config|
  # Set the base box for all VMs
  config.vm.box = VM_CONFIG[:box_image]
  config.vm.box_version = VM_CONFIG[:box_version]
  
  # Loop to create VMs dynamically
  (1..NUM_VMS).each do |i|
    config.vm.define "vm#{i}" do |node|
      # Calculate IP address for this VM
      vm_ip = "#{VM_CONFIG[:base_ip]}.#{VM_CONFIG[:starting_ip] + i - 1}"
      
      # Set hostname
      node.vm.hostname = "#{VM_CONFIG[:hostname_prefix]}-#{i}"
      
      # Configure network
      node.vm.network "private_network", ip: vm_ip
      node.vm.network "public_network"
      
      # VirtualBox provider settings
      node.vm.provider "virtualbox" do |vb|
        vb.name = "#{VM_CONFIG[:vm_name_prefix]}#{i}"
        vb.memory = VM_CONFIG[:memory]
        vb.cpus = VM_CONFIG[:cpus]
        vb.customize ["modifyvm", :id, "--groups", VM_CONFIG[:vm_group]]
      end
      
      # Provisioning script
      node.vm.provision "shell", inline: <<-SHELL
        apt-get update -qq
        systemctl enable ssh
        systemctl start ssh
        
        # Generate /etc/hosts entries for all VMs
        #{generate_hosts_entries(i, NUM_VMS, VM_CONFIG[:base_ip], VM_CONFIG[:starting_ip])}
        
        # Generate SSH key if not exists
        if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
          sudo -u vagrant ssh-keygen -t rsa -b 2048 -f /home/vagrant/.ssh/id_rsa -N ""
        fi
        
        # Ensure authorized_keys exists with correct permissions
        sudo -u vagrant touch /home/vagrant/.ssh/authorized_keys
        chmod 600 /home/vagrant/.ssh/authorized_keys
        chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
        
        # Configure SSH client to not ask for host verification
        sudo -u vagrant cat > /home/vagrant/.ssh/config <<EOF
Host #{VM_CONFIG[:base_ip]}.* #{(1..NUM_VMS).map { |j| "vm#{j}" }.join(' ')}
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
        chmod 600 /home/vagrant/.ssh/config
        chown vagrant:vagrant /home/vagrant/.ssh/config
        
        echo "✅ VM#{i} provisioned successfully!"
      SHELL
    end
  end
end

# ============================================================
# HELPER METHODS
# ============================================================

# Generate /etc/hosts entries for all VMs except the current one
def generate_hosts_entries(current_vm, total_vms, base_ip, starting_ip)
  hosts_entries = []
  (1..total_vms).each do |i|
    next if i == current_vm  # Skip the current VM
    vm_ip = "#{base_ip}.#{starting_ip + i - 1}"
    hosts_entries << "echo \"#{vm_ip} vm#{i}\" >> /etc/hosts"
  end
  hosts_entries.join("\n        ")
end