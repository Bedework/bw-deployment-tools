#! /bin/bash -f

. /etc/profile.d/jdk.sh
# parse args

everything="false"
updateOnly="false"
putQuickstart="false"
case $1 in
   -pureQuickstart)
      pureQuickstart="true"
      echo "***bootstrap: Simply testing quickstart."
      ;; 
   -everything)
      everything="true"
      echo "***bootstrap: Updating quickstart and running over Postgresql."
      ;; 
   -updateOnly)
      updateOnly="true"
      echo "***bootstrap: Updating quickstart and running over Hypersonic."
      ;;
esac


qs=/opt/bedework/quickstart-3.10
jboss=$qs/jboss-5.1.0.GA

# little housekeeping
if [ -f /vagrant/node.js ] ; then
  jsonGrepFile=/vagrant/node.js
else
  jsonGrepFile=/vagrant/Vagrantfile
fi

# fix possible issue with postgresql install.  Fix only needed on some flavors of linux 
# (e.g. Ubuntu 12.04)

if [ -e /etc/apache2/conf.d/phppgadmin ] ; then
  mv /etc/apache2/conf.d/phppgadmin /etc/apache2/conf.d/phppgadmin.conf
  apachectl restart
fi

if [ "$pureQuickstart" = "true" ] ; then
  echo "***bootstrap: Running in pure Quickstart mode."
else
  # make sure you have the latest bw command before running it

  echo "***bootstrap: Updating bw.sh"
  svn update --non-interactive --trust-server-cert $qs/bedework/build/quickstart/linux/bw.sh

  echo "***bootstrap: updating source and rebuilding"
  su vagrant -c "cd $qs; ./bw -updateall; ./bw deploy; ./bw -tzsvr; ./bw -synch; ./bw -eventreg"
fi

# change default dialect for bedework dbase to Postgresql

if [ "$everything" = "true" ] ; then
  echo "***bootstrap: setting hibernate dialect to Postgresql"
  dbconfigFile=$qs/bedework/config/bedework/bwcore/dbconfig.xml
  cp $dbconfigFile ${dbconfigFile}.ORI
  sed 's/org.hibernate.dialect.HSQLDialect/org.hibernate.dialect.PostgreSQLDialect/' ${dbconfigFile}> ${dbconfigFile}.NEW
  mv ${dbconfigFile}.NEW $dbconfigFile

  echo "***bootstrap: installing datasource settings"
  dsSrcDir=$qs/bedework/config/datasources/postgresql
  dbasePassword=`grep '"bedework" => "' $jsonGrepFile | awk '{print $NF}' | sed 's/"//g'`
  sed 's%<password></password>%<password>'$dbasePassword'</password>%' $dsSrcDir/bedework-ds.xml > $jboss/server/default/bwdeploy/bedework-ds.xml

  echo "***bootstrap: downloading jdbc for Postgresql"
  cd $jboss/server/default/lib
  wget http://jdbc.postgresql.org/download/postgresql-9.3-1101.jdbc41.jar
fi
# deployConf

echo "***bootstrap: deploying configuration"
su vagrant -c "cd $qs; ./bw deployConf"

echo "***bootstrap: setting jmx-console password"
jmxPassword=`grep "jmx-console_password" $jsonGrepFile | awk '{print $NF}' | sed 's/"//g'` 
echo "admin:$jmxPassword" > $jboss/server/default/conf/props/jmx-console-users.properties

echo "***bootstrap: installing start-up logic"
cd /vagrant/data

# Using dos2unix to avoid EOL issues on certain hosts

dos2unix -n init.d.bedework /etc/init.d/bedework
dos2unix -n runbw.sh $qs/runbw.sh
cd $jboss/bin
sed 's%.*JBOSS_PID=$!.*%JBOSS_PID=$! ; echo $JBOSS_PID > /var/tmp/bedework.jboss.pid%' $jboss/bin/run.sh > /tmp/run.sh 
dos2unix -n /tmp/run.sh $jboss/bin/run.sh
chmod 755 /etc/init.d/bedework $qs/runbw.sh $jboss/bin/run.sh


echo "***bootstrap: starting up JBoss and ApacheDS"
/etc/init.d/bedework start


echo "***bootstrap: waiting for jmx-console to be available"
wget -out /dev/null --retry-connrefused http://localhost:5080/jmx-console
if [ "$everything" = "true" ] ; then
  #echo "***bootstrap: sleeping for 20 minutes to let the system settle before attempting restore"
  #sleep 1200
  echo "***bootstrap: setting schema attributes"
  su vagrant -c "$jboss/bin/twiddle.sh setattrs org.bedework.bwengine.core:service=DbConf Export True SchemaOutFile $jboss/server/default/data/bedework/dumprestore/schema.txt"
  echo "***bootstrap: exporting schema"
  su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine.core:service=DbConf schema"
  echo "***bootstrap: setting dumprestore attributes"
  su vagrant -c "$jboss/bin/twiddle.sh setattrs org.bedework.bwengine:service=dumprestore AllowRestore True"
  echo "***bootstrap: restoring data"
  su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine:service=dumprestore restoreData"
fi
if [ "$pureQuickstart" = "false" ] ; then
  echo "***bootstrap: reindexing"
  su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine:service=indexing rebuildIndex"
fi
# set up any conveniences

echo "***bootstrap: setting up convenience links, etc."
cd ~vagrant
ln -s $jboss/server/default/log .
ln -s $qs/bedework/config/bwbuild .
ln -s $qs qs
ln -s $jboss jboss
chown vagrant log bwbuild qs jboss
