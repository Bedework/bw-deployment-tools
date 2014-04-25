#! /bin/bash -f

. /etc/profile.d/jdk.sh
# parse args

putQuickstart=0
case $1 in
   -pureQuickstart)
      pureQuickstart=1
      ;; 
esac


qs=/opt/bedework/quickstart-3.10
jboss=$qs/jboss-5.1.0.GA


# fix possible issue with postgresql install.  Fix only needed on some flavors of linux 
# (e.g. Ubuntu 12.04)

if [ -e /etc/apache2/conf.d/phppgadmin ] ; then
  mv /etc/apache2/conf.d/phppgadmin /etc/apache2/conf.d/phppgadmin.conf
  apachectl restart
fi

if [ $pureQuickstart ] ; then
  echo "***bootstrap: Running in pure Quickstart mode."
else

  # make sure you have the latest bw command before running it

  echo "***bootstrap: Updating bw.sh"
  svn update --non-interactive --trust-server-cert $qs/bedework/build/quickstart/linux/bw.sh

  echo "***bootstrap: updating source and rebuilding"
  buildArgs="-quickstart"
  su vagrant -c "cd $qs; ./bw -updateall; ./bw $buildArgs deploy; ./bw $buildArgs -tzsvr"
fi

# change default dialect for bedework dbase to Postgresql

echo "***bootstrap: setting hibernate dialect to Postgresql"
dbconfigFile=$qs/bedework/config/bedework/bwcore/dbconfig.xml
sed 's/org.hibernate.dialect.HSQLDialect/org.hibernate.dialect.PostgreSQLDialect/' ${dbconfigFile}> ${dbconfigFile}.NEW
cp $dbconfigFile ${dbconfigFile}.ORI
mv ${dbconfigFile}.NEW $dbconfigFile

echo "***bootstrap: installing databsource settings"
dsSrcDir=$qs/bedework/config/datasources/postgresql
sed 's%<password></password>%<password>xxx</password>%' $dsSrcDir/bedework-ds.xml > $jboss/server/default/bwdeploy/bedework-ds.xml

echo "***bootstrap: downloading jdbc for Postgresql"
cd $jboss/server/default/lib
wget http://jdbc.postgresql.org/download/postgresql-9.3-1101.jdbc41.jar

# deployConf

echo "***bootstrap: deploying configuration"
if [ ! $pureQuickstart ] ; then
  su vagrant -c "cd $qs; ./bw $buildArgs deployConf"
else
  su vagrant -c "cd $qs; ./bw -quickstart deployConf"
fi

echo "***bootstrap: installing start-up logic"
cd /vagrant/data
cp init.d.bedework /etc/init.d/bedework
cp runbw.sh $qs
cd $jboss/bin
sed 's%.*JBOSS_PID=$!.*%JBOSS_PID=$! ; echo $JBOSS_PID > /var/tmp/bedework.jboss.pid%' $jboss/bin/run.sh > /tmp/run.sh 
cp /tmp/run.sh $jboss/bin/run.sh
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
