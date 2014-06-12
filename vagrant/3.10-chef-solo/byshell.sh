#! /bin/bash -f

. /etc/profile.d/jdk.sh
# parse args

putQuickstart=0
rerun=0
case $1 in
   -pureQuickstart)
      pureQuickstart=1
      ;; 
   -rerun)
      rerun=1
      ;;
esac

qs=/opt/bedework/quickstart-3.10
wwwDocRoot=/opt/bedework/wwwDocRoot
jboss=$qs/jboss-5.1.0.GA

# little housekeeping
if [ -f /vagrant/node.json ] ; then
  jsonGrepFile=/vagrant/node.json
else
  jsonGrepFile=/vagrant/Vagrantfile
fi

# fix possible issue with postgresql install.  Fix only needed on some flavors of linux 
# (e.g. Ubuntu 12.04)

if [ -e /etc/apache2/conf.d/phppgadmin ] ; then
  mv /etc/apache2/conf.d/phppgadmin /etc/apache2/conf.d/phppgadmin.conf
  apachectl restart
fi

if [ $pureQuickstart ] ; then
  echo "***bootstrap: Running in pure Quickstart mode."
else
  echo "***bootstrap: Copying stylesheets to $wwwDocRoot"
  mkdir -p $wwwDocRoot/3.10
  cp -pr $jboss/server/default/deploy/ROOT.war/*rsrc* $wwwDocRoot/3.10
  chown -R vagrant $wwwDocRoot/3.10 
  # make sure you have the latest bw command before running it

  if [ $rerun = 0 ] ; then
    echo "***bootstrap: Updating bw.sh"
    svn update --non-interactive --trust-server-cert $qs/bedework/build/quickstart/linux/bw.sh

    echo "***bootstrap: updating source and rebuilding"
    buildArgs="-quickstart"
    su vagrant -c "cd $qs; ./bw -updateall; ./bw $buildArgs deploy; ./bw $buildArgs -tzsvr"
  fi
fi

# change default dialect for bedework dbase to Postgresql

echo "***bootstrap: setting hibernate dialect to Postgresql"
dbconfigFile=$qs/bedework/config/bedework/bwcore/dbconfig.xml
sed 's/org.hibernate.dialect.HSQLDialect/org.hibernate.dialect.PostgreSQLDialect/' ${dbconfigFile}> ${dbconfigFile}.NEW
cp $dbconfigFile ${dbconfigFile}.ORI
mv ${dbconfigFile}.NEW $dbconfigFile
chown vagrant $dbconfigFile

echo "***bootstrap: installing datasource settings"
dsSrcDir=$qs/bedework/config/datasources/postgresql
dbasePassword=`grep '"bedework": "' $jsonGrepFile | awk '{print $NF}' | sed 's/"//g'`
sed 's%<password></password>%<password>'$dbasePassword'</password>%' $dsSrcDir/bedework-ds.xml > $jboss/server/default/bwdeploy/bedework-ds.xml
chown vagrant $jboss/server/default/bwdeploy/bedework-ds.xml

echo "***bootstrap: downloading jdbc for Postgresql"
cd $jboss/server/default/lib
if [ ! -e postgresql-9.3-1101.jdbc41.jar ] ; then
  wget http://jdbc.postgresql.org/download/postgresql-9.3-1101.jdbc41.jar
  chown vagrant postgresql-9.3-1101.jdbc41.jar
fi

# edit and deploy configuratoni 

if [ ! $pureQuickstart ] ; then
  cd /vagrant
  
  echo "***bootstrap: setting Approot and bwBrowserRoot"
  bash ./configureClients.sh -brootprefix /3.10 -arootprefix http://localhost/3.10
  echo "***bootstrap: deploying configuration"
else
  echo "***bootstrap: deploying configuration"
  su vagrant -c "cd $qs; ./bw -quickstart deployConf"
fi

echo "***bootstrap: setting jmx-console password"
jmxPassword=`grep "jmx-console_password" $jsonGrepFile | awk '{print $NF}' | sed 's/"//g'` 
echo "admin:$jmxPassword" > $jboss/server/default/conf/props/jmx-console-users.properties

echo "***bootstrap: installing start-up logic"
cd /vagrant/data

# Using dos2unix to avoid EOL issues on certain hosts

dos2unix -n  init.d.bedework /etc/init.d/bedework
dos2unix -n  runbw.sh $qs/runbw.sh
chown vagrant $qs/runbw.sh
cd $jboss/bin
sed 's%.*JBOSS_PID=$!.*%JBOSS_PID=$! ; echo $JBOSS_PID > /var/tmp/bedework.jboss.pid%' $jboss/bin/run.sh > /tmp/run.sh 
dos2unix -n /tmp/run.sh $jboss/bin/run.sh
chmod 755 /etc/init.d/bedework $qs/runbw.sh $jboss/bin/run.sh

echo "***bootstrap: starting up JBoss and ApacheDS"
/etc/init.d/bedework start

echo "***bootstrap: waiting for jmx-console to be available"
wget -out /dev/null --retry-connrefused http://localhost:5080/jmx-console
if [ ! $pureQuickstart ] ; then
  echo "***bootstrap: setting dumprestore attributes"
  su vagrant -c "$jboss/bin/twiddle.sh setattrs org.bedework.bwengine.core:service=DbConf Export True SchemaOutFile $jboss/server/default/data/bedework/dumprestore/schema.txt"
  echo "***bootstrap: exporting schema"
  su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine.core:service=DbConf schema"
  echo "***bootstrap: restoring data"
  su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine:service=dumprestore restoreData"
fi
echo "***bootstrap: reindexing"
su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine:service=indexing rebuildIndex"

# set up any conveniences

echo "***bootstrap: setting up convenience links, etc."
cd ~vagrant
ln -s $jboss/server/default/log .
ln -s $qs/bedework/config/bwbuild .
ln -s $qs qs
ln -s $jboss jboss
chown vagrant log bwbuild qs jboss
