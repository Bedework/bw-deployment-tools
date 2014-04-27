In this incarnation, Vagrant does very little, mainly bringing the virtual machine up and
installing chef-solo.   The hope is that this will prove useful to deployers who start with 
an existing server (and so wouldn't have interest in vagrant).  Install chef-solo, git clone 
this package, then run chef-solo and the byshell.sh scriptand it may just do most of the work 
for you! 

Once the machine is spun up, ssh to it and

1) cd /vagrant
2) edit node.json to set the database passwords 
3) sudo chef-solo -c solo.rb   <== install lots of packages, create a db, download bedework, etc.
4) sudo bash byshell.sh        <== finish the install, bring bedework up over postgresql, etc 

Once finished, you can start and stop JBoss and ApacheDS with /etc/init.d/bedework
Also, there are a few symlinks in ~vagrant to help you find things more easily
