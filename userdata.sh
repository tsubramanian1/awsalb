#!/bin/bash
if ! sudo yum update -y; then
  echo "YUM update failed"
  exit 1
fi
sudo yum install -y httpd
sudo systemctl start httpd
if ! sudo systemctl is-active --quiet httpd; then
  echo "Apache failed to start"
  exit 1
fi
sudo systemctl enable httpd
echo "<h1>Hello friend! This is $(hostname -f)</h1>" | sudo tee /var/www/html/index.html > /dev/null
