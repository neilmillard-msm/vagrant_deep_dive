A Vagrant setup that supports my blog entry on "Vagrant / Puppet and Hiera Deep Dive". Below is a reproduction of that article.


Introduction
==============

This weekend I spent far more time than I'd like diving deep into Puppet, Hiera and Vagrant.

Puppet is a configration/automation tool for installing and setting up machines. I prefer Puppet to other competitors (such as Chef) for Reasons, even though I also use Chef.

Hiera is an interesting tool of Puppet (with no equivalent I've found in Chef, at least that I've found): instead of setting variables in your configuration source, do it in YAML (or JSON or MYSL or...) files. This ideally keeps your Puppet manifests (your configuration sourcecode) more sharable and easier to manage. (Ever had a situation in general programming where you need to pass a variable into a function because it's passed to another function three function calls down the stacktrace? Hiera also avoids that.)

However, documentation on Puppet, Hiera is pretty scarce - especially when used with [Vagrant](http://vagrantup.com), which is how I like to use Puppet.

This article assumes you're familiar with Vagrant.

My Vagrant use cases
--------------------

I use (or have used) Vagrant for two things:

  1. To create local development VMs with exactly the tools I need for a project. ([Sample](http://github.com/rwilcox/vagrant_base))
  2. To create client serving infrastructure (mostly early stage stuff).
  
For use case #2, usually this is a client with a new presence just getting their online site ramped up. So I'm provisioning only a couple of boxes this way: I know this wouldn't work for more than a couple dozen instance, but by then they're serving serious traffic. 

My goal is to use Vagrant and 99% the same Puppet code to do both tasks, even though these are two very different use cases.

Thanks to [Vagrant's Multi VM support](https://docs.vagrantup.com/v2/multi-machine/index.html) I can actually have these two VMs controlled in the same `Vagrantfile`

First, general Vagrant Puppet Setup Tricks
============

File Organization
------------

I set my `Vagrantfile`'s puppet block to look like this:

    config.vm.provision "puppet" do |puppet|
      puppet.manifests_path = "puppet/manifests"
      puppet.manifest_file  = "site.pp"

      puppet.module_path   = "puppet/modules"
    end

Note how my manifests and modules folder are in a puppet folder. Our directory structure now looks like:

    vagrant_hiera_deep_dive:
      puppet:
        manifests:
          site.pp
        modules:
      README.markdown
      Vagrantfile

Why? Vagrant, for me, is a tool that ties a bunch of other tools together: uniting virtual machine running with various provisioning tools locally and remotely. Plus the fact that the `Vagrantfile` is just Ruby means that I'm often pulling values out into a [vagrantfile_config pattern](https://github.com/mozilla/playdoh), or writing tools or something. Thus, the more organization I can have at the top level the better.

Modules vs Manifests
-----------------

I tend to one module per project I'm trying to deploy. By that I mean if I'm deploying a Rails bookstore app, I'll create a `bookstore` module. This module will contain all the manifests I need to get the bookstore up and running: manifests to configure mysql, Rails, redis, what-have-you.

Sometimes these individual manifests are simple (and honestly probably could be replaced with clever hiera configs, once I dig into that more), and sometimes a step means configuring two or three things. (a "configure mysql" step yes, needs to use an open source module to install MySQL, but also may need to create a mysql user, create a folder with the correct permissions for the database files, set up a cron job to backup the database, etc)

I also assume I'll be git subtree-ing a number of community modules directly into my codebase.

My `puppet/manifests/` folder than ends up looking like a poor man's [Roles and Profiles](http://garylarizza.com/blog/2014/02/17/puppet-workflow-part-2/) setup. I take some liberties, but it's likely the author is dealing with waaaaay more Puppet nodes than I'd ever imagine with this setup.


Pulling in third party Puppet modules
---------------------

The third party Puppet community has already created infrastructure pieces I can use and customize, and has created a package manager to make installation easy. Except we need to run these package managers *before* we run Puppet on the instance!

Vagrant to the rescue! We can run multiple provisioning tasks (per instance!) in a Vagrantfile!

Before the `config.vm.provision "puppet"` line, we tell puppet to install modules we'll need later:

        config.vm.provision :shell, :inline => "test -d /etc/puppet/modules/rvm || puppet module install maestrodev/rvm"

Because the shell provisioner will always run, we want to test that a Puppet module is not installed before we try to install it.

There are other ways to manage Puppet modules, but this simple shell inline command works for me. I'll often install 4 or 5 third party modules this way, simply copy/pasting and changing the directory path and module name. As long as I'm before the puppet configuration block these modules will be installed before that happens.

Uninstalling Old Puppet Versions (and installing the latest)
-------------------------

This weekend I discovered a Ubuntu 12 LTS box with a very old version of Puppet on it (2.7). I have a love/hate relationship with Ubuntu LTS: The LTS means Long Term Support, so nothing major changes over the course of maybe 5 years. Great for server stability. However, that also means that preinstalled software that I depend on may be super old... and I may want / need the new version.

I ended up writing the following bash script:

<pre style="background-color: rgb(252,244,220); padding: 1em;"><code>
<span style="color: rgb(112,130,132);">#!/usr/bin/env&nbsp;bash
</span><span style="color: rgb(112,130,132);">#
</span><span style="color: rgb(112,130,132);">#&nbsp;This&nbsp;removes&nbsp;ancient&nbsp;Puppet&nbsp;versions&nbsp;on&nbsp;the&nbsp;VM&nbsp;-&nbsp;if&nbsp;there&nbsp;IS&nbsp;any&nbsp;ancient
</span><span style="color: rgb(112,130,132);">#&nbsp;version&nbsp;on&nbsp;it&nbsp;-&nbsp;so&nbsp;we&nbsp;can&nbsp;install&nbsp;the&nbsp;latest.
</span><span style="color: rgb(112,130,132);">#
</span><span style="color: rgb(112,130,132);">#&nbsp;It&nbsp;is&nbsp;meant&nbsp;to&nbsp;be&nbsp;run&nbsp;as&nbsp;part&nbsp;of&nbsp;a&nbsp;provisioning&nbsp;run&nbsp;by&nbsp;Vagrant
</span><span style="color: rgb(112,130,132);">#&nbsp;so&nbsp;it&nbsp;must&nbsp;ONLY&nbsp;delete&nbsp;old&nbsp;versions&nbsp;(not&nbsp;current&nbsp;versions&nbsp;other&nbsp;stages&nbsp;have&nbsp;installed)
</span><span style="color: rgb(112,130,132);">#
</span><span style="color: rgb(112,130,132);">#&nbsp;It&nbsp;assumes&nbsp;that&nbsp;we're&nbsp;targeting&nbsp;Puppet&nbsp;3.7&nbsp;(modern&nbsp;as&nbsp;of&nbsp;Feb&nbsp;2015...)
</span><span style="color: rgb(4,32,41);">
</span><span style="color: rgb(4,32,41);">INSTALLED_PUPPET_VERSION</span><span style="color: rgb(4,32,41);">=</span><span style="color: rgb(4,32,41);">$</span><span style="color: rgb(4,32,41);">(</span><span style="color: rgb(4,32,41);">apt-cache</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">policy</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">puppet</span><span style="color: rgb(4,32,41);">&nbsp;|&nbsp;</span><span style="color: rgb(33,118,199);">grep</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(37,146,134);">"Installed:&nbsp;"</span><span style="color: rgb(4,32,41);">&nbsp;|&nbsp;</span><span style="color: rgb(33,118,199);">cut</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">-d</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(37,146,134);">":"</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">-f</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">2</span><span style="color: rgb(4,32,41);">&nbsp;|&nbsp;</span><span style="color: rgb(33,118,199);">xargs</span><span style="color: rgb(4,32,41);">)
</span><span style="color: rgb(33,118,199);">echo</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(37,146,134);">"Currently&nbsp;installed&nbsp;version:&nbsp;$INSTALLED_PUPPET_VERSION"</span><span style="color: rgb(4,32,41);">

</span><span style="color: rgb(33,118,199);">if</span><span style="color: rgb(4,32,41);">&nbsp;[[&nbsp;</span><span style="color: rgb(4,32,41);">$INSTALLED_PUPPET_VERSION</span><span style="color: rgb(4,32,41);">&nbsp;!=&nbsp;</span><span style="color: rgb(4,32,41);">3.7</span><span style="color: rgb(4,32,41);">*&nbsp;]]&nbsp;;&nbsp;</span><span style="color: rgb(33,118,199);">then</span><span style="color: rgb(4,32,41);">
&nbsp;&nbsp;</span><span style="color: rgb(4,32,41);">apt-get</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">remove</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">-y</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">puppet</span><span style="color: rgb(4,32,41);">=</span><span style="color: rgb(4,32,41);">$INSTALLED_PUPPET_VERSION</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(4,32,41);">puppet-common</span><span style="color: rgb(4,32,41);">=</span><span style="color: rgb(4,32,41);">$INSTALLED_PUPPET_VERSION</span><span style="color: rgb(4,32,41);">
&nbsp;&nbsp;</span><span style="color: rgb(33,118,199);">echo</span><span style="color: rgb(4,32,41);">&nbsp;</span><span style="color: rgb(37,146,134);">"Removed&nbsp;old&nbsp;Puppet&nbsp;version:&nbsp;$INSTALLED_PUPPET_VERSION"</span><span style="color: rgb(4,32,41);">
</span><span style="color: rgb(33,118,199);">fi</span><span style="color: rgb(4,32,41);">
</span></code></pre>

It assumes your desired Puppet version is 3.7.x, which should be good until Puppet 4.

I also have a script that installs Puppet if it's not there (maybe it's not there on the box/instance, OR our script above removed it). I got it from the makers of Vagrant themselves: [puppet-bootstrap](https://github.com/hashicorp/puppet-bootstrap).

Again, added before the `config.vm.provision :puppet` bits:

    config.vm.provision :shell, path: "vagrant_tools/remove_puppet_unless_modern.sh"  # in case the VM has old crap installed...
    config.vm.provision :shell, path: "vagrant_tools/install_puppet_on_ubuntu.sh"

Notice that both these shell scripts I store in a `vagrant_tools` directory, in the same folder as my Vagrantfile. My directory structure now looks like:

    vagrant_hiera_deep_dive:
      puppet:
        manifests:
          site.pp
        modules:
      README.markdown
      Vagrantfile
      vagrant_tools
        install_puppet_on_ubuntu.sh
        remove_puppet_unless_modern.sh
        
Puppet + Hiera
==================

Using Hiera and Vagrant is slightly awkward, especially since many of the Hiera conventions are meant to support dozens or hundreds of nodes... but we're using Vagrant, so we may have one - or maybe more, but in the grand scheme of things the limit is pretty low. Low enough where Hiera gets in the way.

*Anyway*...

The way I figured out how to do this is create a `hiera` folder in our `puppet` folder. My directory structure now looks like this:

    vagrant_hiera_deep_dive:
      puppet:
        hiera:
          common.yaml
          node_site_config.yaml
          node_site_data.yaml
        manifests:
          site.pp
        modules:
      README.markdown
      vagrant_tools:
        install_puppet_on_ubuntu.sh
        remove_puppet_unless_modern.sh
      Vagrantfile

A reminder at this point: the VM (and thus Puppet) have their own file systems disassociated with the file system on your host machine. Vagrant automates the creation of specified shared folders: opening a directory portal back to the host machine.

Implicitly Vagrant creates a shared folder for `manifest_path` and `module_path` folders. (In fact, these [can be *arrays* of paths to share](https://ask.puppetlabs.com/question/2646/how-to-separate-3rd-party-modules-from-own-modules/?answer=2651#post-id-2651), not just single files!!!)

Anyway, our hiera folder must be shared manually.

Note here that Vagrant throws a curveball our way and introduces a bit of arbitraryness to where it creates the manifest and module folders. You're going to have to watch the `vagrant up` console spew to see where this is: with the `vagrant_hiera_deep_dive` VM the output was as follewed:

    ==> default: Mounting shared folders...
        default: /vagrant => /Users/rwilcox/Development/GitBased/vagrant_hiera_deep_dive
        default: /tmp/vagrant-puppet-3/manifests => /Users/rwilcox/Development/GitBased/vagrant_hiera_deep_dive/puppet/manifests
        default: /tmp/vagrant-puppet-3/modules-0 => /Users/rwilcox/Development/GitBased/vagrant_hiera_deep_dive/puppet/modules 
        
Notice the `/tmp/vagrant-puppet-3/`? That's your curveball: it may be different for different VM names (but is consistant: it'll never change)

So, create the shared folder in the Vagrantfile:

    config.vm.synced_folder("puppet/hiera", "/tmp/vagrant-puppet-3/hiera")

Likewise, we'll want to add the following lines to the puppet block

    puppet.hiera_config_path = "puppet/hiera/node_site_config.yaml"
    puppet.working_directory = "/tmp/vagrant-puppet-3/"

Important notes about the hiera config
------------------

It's important that Hiera *only* likes `.yaml` extensions, not `.yml`.

It's also important that yes, having both the `node_site_data.yml` and `node_site_config.yml` files do feel a bit silly, especially at our current scale of one machine. Sadly this is not something we can fight and win, but a limitation of the system. Hiera's documentation goes more into config vs data files.

But also note that the `node_site_config` file points to `node_site_data`, via [Hiera's config file format](https://docs.puppetlabs.com/hiera/1/configuring.html#example-config-file).

Conclusion
===================

I've been using Vagrant and Puppet at a very basic level a very long time (something like 5 years, I think). From best practices I've been using for years, to new things I've just pieced together today, I hope this was helpful to someone.
