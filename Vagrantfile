# -*- mode: ruby -*-
# vi: set ft=ruby :

# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# CONFIGURATION VARIABLES
# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# Customize these variables to create as many VMs as needed

# Number of VMs to create
NUM_VMS = 2

# VM Configuration
VM_CONFIG = {
  box_image: "bento/ubuntu-25.04",
  box_version: "202510.26.0",
  memory: "1024",
  cpus: 1,
  base_ip: "192.168.56",
  starting_ip: 101,
  hostname_prefix: "omni",
  vm_name_prefix: "Omni-VM",
  vm_group: "/Main Linux System"
}

UTILITY_PACKAGES = %w[
  build-essential net-tools util-linux software-properties-common curl wget  zip tar sysstat unzip ncal vim nano htop 
  tree jq dnsutils iputils-ping ntfs-3g traceroute nmap lsof psmisc screen tmux parted ncal rsync whois strace tcpdump
  e2fsprogs ca-certificates gnupg lsb-release socat netcat-openbsd proot  p7zip-full exfatprogs cloud-utils nfs-common  
  unrar xfsprogs 
].join(' ')

# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# VAGRANT CONFIGURATION
# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
Vagrant.configure("2") do |config|
  # Set the base box for all VMs
  config.vm.box = VM_CONFIG[:box_image]
  config.vm.box_version = VM_CONFIG[:box_version]
  
  # Loop to create VMs dynamically
  (1..NUM_VMS).each do |i|
    # Determine VM name for vagrant status and VirtualBox display
    vm_define_name = NUM_VMS == 1 ? VM_CONFIG[:vm_name_prefix] : "#{VM_CONFIG[:vm_name_prefix]}_#{i}"

    config.vm.define vm_define_name do |node|
      # Calculate IP address for this VM
      vm_ip = "#{VM_CONFIG[:base_ip]}.#{VM_CONFIG[:starting_ip] + i - 1}"
      
      # Set hostname
      node.vm.hostname = "#{VM_CONFIG[:hostname_prefix]}-#{i}"
      
      # Configure network
      node.vm.network "private_network", ip: vm_ip
      node.vm.network "public_network"
      
      # VirtualBox provider settings
      node.vm.provider "virtualbox" do |vb|
        vb.name = vm_define_name
        vb.memory = VM_CONFIG[:memory]
        vb.cpus = VM_CONFIG[:cpus]
        vb.customize ["modifyvm", :id, "--groups", VM_CONFIG[:vm_group]]
      end
      
      # Provisioning script
      node.vm.provision "shell", inline: <<-SHELL
        apt-get update -qq
        apt-get install -y -qq #{UTILITY_PACKAGES}
        apt-get upgrade -y -qq
        systemctl enable ssh
        systemctl start ssh
        
        # Generate /etc/hosts entries for all VMs
        #{generate_hosts_entries(i, NUM_VMS, VM_CONFIG)}
        
        echo "✅ VM#{i} provisioned successfully!"
      SHELL
    end
  end
end

# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# HELPER METHODS
# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# Generate /etc/hosts entries for all VMs except the current one
def generate_hosts_entries(current_vm, total_vms, vm_config)
  hosts_entries = []
  (1..total_vms).each do |i|
    next if i == current_vm  # Skip the current VM
    vm_ip = "#{vm_config[:base_ip]}.#{vm_config[:starting_ip] + i - 1}"
    vm_display_name = total_vms == 1 ? vm_config[:vm_name_prefix] : "#{vm_config[:vm_name_prefix]}_#{i}"
    hosts_entries << "echo \"#{vm_ip} vm#{i} #{vm_config[:hostname_prefix]}-#{i} #{vm_display_name}\" >> /etc/hosts"
  end
  hosts_entries.join("\n        ")
end
# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# END OF VAGRANTFILE
# ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────
