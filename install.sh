#!/bin/bash

# Create a new udev rule file
cat <<EOF | sudo tee /etc/udev/rules.d/99-gowinsemiusb.rules > /dev/null
SUBSYSTEM=="usb", ATTR{idVendor}=="33aa", ATTR{idProduct}=="0120", SYMLINK+="gowinsemi_gwu2x%n", MODE="0666"
EOF

cat <<EOF | sudo tee /etc/udev/rules.d/99-icesugar.rules > /dev/null
SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="602b", SYMLINK+="icesugar_nano%n", MODE="0666"
EOF

# Reload the udev rules to apply the changes
sudo udevadm control --reload-rules

# Trigger udev to re-evaluate devices
echo "Triggering udev to re-evaluate devices..."
sudo udevadm trigger

echo "Installation completed successfully!"
