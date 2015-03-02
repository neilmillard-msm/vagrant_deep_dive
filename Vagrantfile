# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "puppetlabs/ubuntu-12.04-64-puppet"

  config.vm.synced_folder("puppet/hiera", "/tmp/vagrant-puppet-3/hiera")

  config.vm.provision :shell, :inline => "test -d /etc/puppet/modules/rvm || puppet module install maestrodev/rvm"
  config.vm.provision :shell, path: "vagrant_tools/remove_puppet_unless_modern.sh"  # in case the VM has old crap installed...
  config.vm.provision :shell, path: "vagrant_tools/install_puppet_on_ubuntu.sh"


  # Enable provisioning with Puppet stand alone.  Puppet manifests
  # are contained in a directory path relative to this Vagrantfile.
  # You will need to create the manifests directory and a manifest in
  # the file default.pp in the manifests_path directory.
  #
  config.vm.provision "puppet" do |puppet|
    puppet.manifests_path = "puppet/manifests"
    # as my Puppet interactions get more complex I like keeping everything in a puppet folder
    puppet.manifest_file  = "site.pp"

    puppet.module_path   = "puppet/modules"
    # mostly for modules I create

    puppet.hiera_config_path = "puppet/hiera/node_site_config.yaml"
    puppet.working_directory = "/tmp/vagrant-puppet-3/"
  end


end
