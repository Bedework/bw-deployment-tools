#! /bin/bash

export JAVA_HOME=/usr/lib/jvm/default-java
export QUICKSTART_HOME=/opt/bedework/quickstart-3.10
export DS_HOME=$QUICKSTART_HOME/apacheds-1.5.3-fixed

cd $QUICKSTART_HOME
export LAUNCH_JBOSS_IN_BACKGROUND=1
./startjboss > /dev/null 2> logs/jboss.errors &
./runcache > /dev/null 2> logs/vert.x.errors &
cd $DS_HOME                                                                         
$JAVA_HOME/jre/bin/java \
-Dlog4j.configuration=file:conf/log4j.properties -Dapacheds.log.dir=$DS_HOME/logs \
-classpath $DS_HOME/lib/antlr-2.7.7.jar:$DS_HOME/lib/apacheds-bootstrap-extract-1.5.3.jar:\
$DS_HOME/lib/apacheds-bootstrap-partition-1.5.3.jar:$DS_HOME/lib/apacheds-btree-base-1.5.3.jar:\
$DS_HOME/lib/apacheds-core-1.5.3.jar:$DS_HOME/lib/apacheds-core-constants-1.5.3.jar:\
$DS_HOME/lib/apacheds-core-entry-1.5.3.jar:$DS_HOME/lib/apacheds-core-shared-1.5.3.jar:\
$DS_HOME/lib/apacheds-jdbm-1.5.3.jar:$DS_HOME/lib/apacheds-jdbm-store-1.5.3.jar:\
$DS_HOME/lib/apacheds-kerberos-shared-1.5.3.jar:$DS_HOME/lib/apacheds-noarch-installer-1.5.3.jar:\
$DS_HOME/lib/apacheds-protocol-changepw-1.5.3.jar:$DS_HOME/lib/apacheds-protocol-dns-1.5.3.jar:\
$DS_HOME/lib/apacheds-protocol-kerberos-1.5.3.jar:$DS_HOME/lib/apacheds-protocol-ldap-1.5.3.jar:\
$DS_HOME/lib/apacheds-protocol-ntp-1.5.3.jar:$DS_HOME/lib/apacheds-protocol-shared-1.5.3.jar:\
$DS_HOME/lib/apacheds-schema-bootstrap-1.5.3.jar:$DS_HOME/lib/apacheds-schema-extras-1.5.3.jar:\
$DS_HOME/lib/apacheds-schema-registries-1.5.3.jar:$DS_HOME/lib/apacheds-server-jndi-1.5.3.jar:\
$DS_HOME/lib/apacheds-server-xml-1.5.3.jar:$DS_HOME/lib/apacheds-utils-1.5.3.jar:\
$DS_HOME/lib/apacheds-xbean-spring-1.5.3.jar:$DS_HOME/lib/bootstrapper.jar:\
$DS_HOME/lib/commons-cli-1.1.jar:$DS_HOME/lib/commons-collections-3.2.jar:\
$DS_HOME/lib/commons-daemon-1.0.1.jar:$DS_HOME/lib/commons-lang-2.3.jar:\
$DS_HOME/lib/jcl104-over-slf4j-1.4.3.jar:$DS_HOME/lib/log4j-1.2.14.jar:\
$DS_HOME/lib/mina-core-1.1.6.jar:$DS_HOME/lib/mina-filter-ssl-1.1.6.jar:\
$DS_HOME/lib/shared-asn1-0.9.11.jar:$DS_HOME/lib/shared-asn1-codec-0.9.11.jar:\
$DS_HOME/lib/shared-bouncycastle-reduced-0.9.11.jar:$DS_HOME/lib/shared-ldap-0.9.11.jar:\
$DS_HOME/lib/shared-ldap-constants-0.9.11.jar:$DS_HOME/lib/slf4j-api-1.4.3.jar:\
$DS_HOME/lib/slf4j-log4j12-1.4.3.jar:$DS_HOME/lib/spring-beans-2.0.6.jar:\
$DS_HOME/lib/spring-context-2.0.6.jar:$DS_HOME/lib/spring-core-2.0.6.jar:\
$DS_HOME/lib/wrapper.jar:$DS_HOME/lib/xbean-spring-3.3.jar org.apache.directory.server.UberjarMain conf/server.xml \
> ../logs/apacheds.out 2> ../logs/apacheds.errors &
echo $! > /var/tmp/bedework.apacheds.pid

