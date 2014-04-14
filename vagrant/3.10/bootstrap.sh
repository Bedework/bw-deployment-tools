#! /bin/bash -f

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

if [ ! $pureQuickstart ] ; then

  # make sure you have the latest bw command before running it

  svn update --non-interactive --trust-server-cert $qs/bedework/build/quickstart/linux/bw.sh

  # create blended config dir from default and jboss-postgresql.  Use Postgresql 
  # for main database and set the bedework password to "xxx"

  cd $qs/bedework/config/bwbuild
  cp -pr jboss-postgresql vagrant
  cp default/bedework*ds.xml vagrant
  sed 's%<password></password>%<password>xxx</password>%' jboss-postgresql/bedework-ds.xml > vagrant/bedework-ds.xml
  cp jboss-postgresql/cal.properties vagrant


  # update and build as user "vagrant"

  buildArgs="-bwchome $qs/bedework/config/bwbuild -bwc vagrant"
  su vagrant -c "cd $qs; ./bw -updateall; ./bw $buildArgs deploy; ./bw $buildArgs -tzsvr"
fi


# deployConf

if [ ! $pureQuickstart ] ; then
  su vagrant -c "cd $qs; ./bw $buildArgs deployConf"
else
  su vagrant -c "cd $qs; ./bw -quickstart deployConf"
fi

# set up start up logic

cd /vagrant/data
cp init.d.bedework /etc/init.d/bedework
cp runbw.sh $qs
cd $jboss/bin
sed 's%.*JBOSS_PID=$!.*%JBOSS_PID=$! ; echo $JBOSS_PID > /var/tmp/bedework.jboss.pid%' $jboss/bin/run.sh > /tmp/run.sh 
cp /tmp/run.sh $jboss/bin/run.sh
chmod 755 /etc/init.d/bedework $qs/runbw.sh $jboss/bin/run.sh


# start bedework

/etc/init.d/bedework start


# wait for jmx-console to become available, then reindex and set up the postgresql db

wget -out /dev/null --retry-connrefused http://localhost:5080/jmx-console
su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine:service=indexing rebuildIndex"
if [ ! $pureQuickstart ] ; then
  su vagrant -c "$jboss/bin/twiddle.sh setattrs org.bedework.bwengine.core:service=DbConf HibernateDialect org.hibernate.dialect.PostgreSQLDialect Export True"
  su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine.core:service=DbConf schema"
  su vagrant -c "$jboss/bin/twiddle.sh invoke org.bedework.bwengine:service=dumprestore restoreData"
fi

# set up any conveniences

cd ~vagrant
ln -s $jboss/server/default/log .
chown vagrant log
