#!/bin/bash
# This bootstraps Puppet on CentOS 6.x
# It has been tested on CentOS 6.4 64bit

set -e

REPO_URL="http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm"

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if which puppet > /dev/null 2>&1; then
  echo "Puppet is already installed."
  exit 0
fi

# Install puppet labs repo
echo "Configuring PuppetLabs repo..."
repo_path=$(mktemp)
wget --output-document="${repo_path}" "${REPO_URL}" 2>/dev/null
rpm -i "${repo_path}" >/dev/null

# Install dependanies
yum -y install git gcc augeas-devel ruby-devel
# Install Puppet...
echo "Installing puppet"
yum install -y puppet > /dev/null

echo "Puppet installed!"

# Install RubyGems for the provider
# echo "Installing RubyGems..."
# if [ $DISTRIB_CODENAME != "trusty" ]; then
#   apt-get install -y rubygems >/dev/null
# fi
# gem install --no-ri --no-rdoc rubygems-update
# update_rubygems >/dev/null
