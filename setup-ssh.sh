#!/bin/bash
# This script sets up SSH key-based authentication between multiple Vagrant VMs.
# It automatically detects the number of VMs and distributes SSH keys between them.
# Finally, it tests the SSH connections to ensure everything is set up correctly.

# Usage: Run this script from the directory containing your Vagrantfile.

echo "==================================================="
echo "SSH Key Distribution Script for Vagrant VMs"
echo "==================================================="
echo ""

# Step 1: Detect all running VMs
echo "Step 1: Detecting running VMs..."
VM_LIST=$(vagrant status --machine-readable | grep ",state,running" | cut -d',' -f2 | sort -V)

if [ -z "$VM_LIST" ]; then
    echo "ERROR: No running VMs detected. Please run 'vagrant up' first."
    exit 1
fi

VM_ARRAY=($VM_LIST)
NUM_VMS=${#VM_ARRAY[@]}

echo "✓ Detected $NUM_VMS running VM(s): ${VM_ARRAY[*]}"
echo ""

# Step 2: Get public keys from each VM
echo "Step 2: Retrieving public keys from each VM..."

declare -A VM_KEYS

for vm in "${VM_ARRAY[@]}"; do
    echo "  Retrieving key from $vm..."
    key=$(vagrant ssh "$vm" -c 'cat ~/.ssh/id_rsa.pub 2>/dev/null' 2>/dev/null | sed 's/\r$//')
    
    if [ -z "$key" ]; then
        echo "  ⚠ No SSH key found on $vm, generating one..."
        vagrant ssh "$vm" -c 'ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N "" >/dev/null 2>&1' 2>/dev/null
        key=$(vagrant ssh "$vm" -c 'cat ~/.ssh/id_rsa.pub 2>/dev/null' 2>/dev/null | sed 's/\r$//')
        
        if [ -z "$key" ]; then
            echo "ERROR: Could not generate or retrieve SSH key from $vm"
            exit 1
        fi
    fi
    
    VM_KEYS[$vm]="$key"
    echo "  ✓ Retrieved key from $vm"
done

echo "✓ Retrieved all public keys"
echo ""

# Step 3: Distribute keys to all VMs
echo "Step 3: Distributing SSH keys..."

for target_vm in "${VM_ARRAY[@]}"; do
    echo "  Updating authorized_keys on $target_vm..."
    
    # Build a list of keys to add (all keys except the target VM's own key)
    for source_vm in "${VM_ARRAY[@]}"; do
        if [ "$source_vm" != "$target_vm" ]; then
            key="${VM_KEYS[$source_vm]}"
            # Add key only if it doesn't already exist
            vagrant ssh "$target_vm" -c "grep -qF '$key' ~/.ssh/authorized_keys 2>/dev/null || echo '$key' >> ~/.ssh/authorized_keys" 2>/dev/null
        fi
    done
    
    # Ensure correct permissions
    vagrant ssh "$target_vm" -c "chmod 600 ~/.ssh/authorized_keys" 2>/dev/null
    echo "  ✓ $target_vm authorized keys updated"
done

echo "✓ All keys distributed"
echo ""

# Step 4: Configure SSH client on each VM to skip host verification for peer VMs
echo "Step 4: Configuring SSH client on each VM..."

# Build the list of all VM hostnames and IPs for the SSH config Host line
HOST_PATTERNS=""
for vm in "${VM_ARRAY[@]}"; do
    vm_hostname=$(vagrant ssh "$vm" -c 'hostname' 2>/dev/null | sed 's/\r$//')
    vm_ip=$(vagrant ssh "$vm" -c "hostname -I | awk '{print \$2}'" 2>/dev/null | sed 's/\r$//')
    HOST_PATTERNS="$HOST_PATTERNS $vm_hostname $vm_ip"
done

# Extract the base IP subnet for a wildcard match
FIRST_IP=$(vagrant ssh "${VM_ARRAY[0]}" -c "hostname -I | awk '{print \$2}'" 2>/dev/null | sed 's/\r$//')
BASE_SUBNET=$(echo "$FIRST_IP" | cut -d'.' -f1-3)

for vm in "${VM_ARRAY[@]}"; do
    vagrant ssh "$vm" -c "cat > ~/.ssh/config <<EOF
Host ${BASE_SUBNET}.*${HOST_PATTERNS}
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel ERROR
EOF
chmod 600 ~/.ssh/config" 2>/dev/null
    echo "  ✓ $vm SSH client configured"
done

echo "✓ All VMs configured"
echo ""

# Step 5: Test SSH connections
echo "Step 5: Testing SSH connections..."
echo ""

test_connection() {
    local from=$1
    local to_host=$2
    local to_label=$3
    local result=$(vagrant ssh "$from" -c "ssh -o BatchMode=yes -o ConnectTimeout=5 vagrant@$to_host 'echo SUCCESS' 2>/dev/null" 2>/dev/null | grep SUCCESS)
    
    if [ -n "$result" ]; then
        echo "  ✓ $from -> $to_label: Connected"
        return 0
    else
        echo "  ✗ $from -> $to_label: Failed"
        return 1
    fi
}

# Get hostname for each VM for testing
declare -A VM_HOSTNAMES
for vm in "${VM_ARRAY[@]}"; do
    VM_HOSTNAMES[$vm]=$(vagrant ssh "$vm" -c 'hostname' 2>/dev/null | sed 's/\r$//')
done

# Test all possible connections
failed_connections=0
total_connections=0

for from_vm in "${VM_ARRAY[@]}"; do
    for to_vm in "${VM_ARRAY[@]}"; do
        if [ "$from_vm" != "$to_vm" ]; then
            total_connections=$((total_connections + 1))
            to_hostname="${VM_HOSTNAMES[$to_vm]}"
            if ! test_connection "$from_vm" "$to_hostname" "$to_vm"; then
                failed_connections=$((failed_connections + 1))
            fi
        fi
    done
done

echo ""
echo "==================================================="
echo "Setup Complete!"
echo "==================================================="
echo ""
echo "Summary:"
echo "  Total VMs: $NUM_VMS"
echo "  Total connections tested: $total_connections"
echo "  Successful connections: $((total_connections - failed_connections))"
echo "  Failed connections: $failed_connections"
echo ""

if [ $failed_connections -eq 0 ]; then
    echo "✅ All SSH connections are working perfectly!"
    echo ""
    echo "You can now SSH between VMs without passwords:"
    for vm in "${VM_ARRAY[@]}"; do
        echo "  vagrant ssh $vm"
        echo "    Then inside: ssh <hostname-of-other-vm>"
    done
else
    echo "⚠️  Some connections failed. Please check the output above."
    echo "You may need to run this script again or check VM configurations."
fi
echo ""
