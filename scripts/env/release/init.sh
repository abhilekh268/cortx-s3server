#!/bin/sh

SCRIPT_PATH=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT_PATH")
CURRENT_DIR=`pwd`

# We are setting up new VM, so just attempt clean openldap
systemctl stop slapd 2>/dev/null || /bin/true
yum remove -y openldap-servers openldap-clients || /bin/true
rm -f /etc/openldap/slapd.d/cn\=config/cn\=schema/cn\=\{1\}s3user.ldif
rm -rf /var/lib/ldap/*
rm -f /etc/sysconfig/slapd* 2>/dev/null || /bin/true
rm -f /etc/openldap/slapd* 2>/dev/null || /bin/true
rm -rf /etc/openldap/slapd.d/*

# Tools for ssl certificate generation
yum install -y openssl java-1.8.0-openjdk-headless

# Generate the certificates rpms for dev setup
# clean up
rm -f ~/rpmbuild/RPMS/x86_64/stx-s3-certs*
rm -f ~/rpmbuild/RPMS/x86_64/stx-s3-client-certs*

cd ${BASEDIR}/../../../rpms/s3certs
# Needs openssl and jre which are installed with rpm_build_env
./buildrpm.sh

# install the built certs
rpm -e stx-s3-certs stx-s3-client-certs || /bin/true
yum install openldap-servers haproxy -y # so we have "ldap" and "haproxy" users.
yum localinstall -y ~/rpmbuild/RPMS/x86_64/stx-s3-certs*
yum localinstall -y ~/rpmbuild/RPMS/x86_64/stx-s3-client-certs*

# Setup using ansible
yum install -y ansible

cd ${BASEDIR}/../../../ansible

# Update ansible/hosts file with local ip
cp -f ./hosts ./hosts_local
sed -i "s/^xx.xx.xx.xx/127.0.0.1/" ./hosts_local

# run ansible to configure build env
ansible-playbook -i ./hosts_local --connection local setup_release_node.yml -v  -k

rm -f ./hosts_local

systemctl restart haproxy

cd ${CURRENT_DIR}