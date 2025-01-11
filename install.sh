#!/bin/bash

# Detect distro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro=$ID
else
    echo "Cannot detect the distribution."
    exit 1
fi
echo "Detected distro: $distro"
case "$distro" in
    "ubuntu" | "debian" | "kali")
        echo "Installing dependencies for $distro"
        libSecurityPath="/lib/x86_64-linux-gnu/security"
        sudo apt-get update
        sudo apt-get install -y cmake make gcc g++ python3 python3-dev python3-pip python3-venv libpam0g-dev
        ;;
    "fedora")
        echo "Installing dependencies for Fedora"
        libSecurityPath="/lib64/security"
        sudo dnf install -y cmake make gcc gcc-c++ python3 python3-devel python3-pip pam-devel
        ;;
    "arch")
        echo "Installing dependencies for Arch"
        libSecurityPath="/lib/security"
        sudo pacman -S --noconfirm cmake make gcc python python-pip python-virtualenv pam
        ;;
    *)
        echo "Unsupported distro"
        exit 1
        ;;
esac

# Create directories
sudo mkdir -p /opt/daxauth
sudo mkdir -p /var/lib/daxauth/data

# Create virtual environment
sudo python3 -m venv /opt/daxauth/.venv
# Activate virtual environment
source /opt/daxauth/.venv/bin/activate

# Install requirements
sudo /opt/daxauth/.venv/bin/pip install -r requirements.txt

# Copy src files
sudo cp -r src /opt/daxauth
sudo cp -r config /opt/daxauth

# Copy script to /usr/local/bin
sudo cp src/daxauth /usr/local/bin/daxauth

# Make script executable
sudo chmod +x /usr/local/bin/daxauth

# Compile C code
cd /opt/daxauth/src/pam
sudo make

# Copy pam module to /lib/security
sudo cp pam_face_auth.so $libSecurityPath

# Create a backup of the sudo PAM configuration file
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak

# Define the line to add
LINE="auth sufficient pam_face_auth.so"

# Define the file to modify
FILE="/etc/pam.d/sudo"

# Check if the line already exists
if ! grep -qF "$LINE" "$FILE"; then
    # Insert the line after the first line
    sudo sed -i "1a $LINE" "$FILE"
fi

# Verify the changes
echo "Updated $FILE:"
sudo cat "$FILE"

echo "Installation completed successfully."

# Add face to the database

echo "Do you want to add a face to the database? (y/n)"
read -r response
if [ "$response" = "y" ]; then
    sudo daxauth add
fi