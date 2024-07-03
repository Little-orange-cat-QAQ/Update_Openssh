#! /bin/bash
# check system
openssl_version="openssl-3.3.0"
openssh_version="openssh-9.7p1"
function check_system() {
system=`cat /etc/redhat-release | awk '{print $1}'`
if [ $system == 'CentOS' ] || [ $system == 'Fedora' ]
 then
   echo "系统为$system,可以进行后续安装"
else
   echo "系统为$system,不可以安装"
   exit 1
fi
}


function update_openssl() {
# install software
yum install perl* gcc zlib*

# update openssl version
tar -zxvf $openssl_version\.tar.gz -C /opt/
cd /opt/$openssl_version && ./config shared --prefix=/usr/local/openssl
make -j 4 && make install
if [ $? -eq 0 ]
 then
   echo "/usr/local/openssl/lib64/" >> /etc/ld.so.conf
   ldconfig
   mv /usr/bin/openssl /usr/bin/openssl.old
   ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
   ln -s /usr/local/openssl/lib64/libcrypto.so.3 /usr/lib64/libcrypto.so.3
   ln -s /usr/local/openssl/lib64/libssl.so.3 /usr/lib64/libssl.so.3
else
 echo "error"
 exit 1
fi
}

function update_openssh() {
# update openssh version
# backup software
mv /etc/ssh/ /etc/ssh.bak/
mv /usr/bin/ssh /usr/bin/ssh.bak
mv /usr/sbin/sshd /usr/sbin/sshd.bak
mv /etc/init.d/sshd /etc/init.d/sshd.bak

# uninstall sshd software
rpm -e --nodeps $(rpm -qa |grep openssh)

# tar openssh pack
tar -zxvf $openssh_version\.tar.gz -C /opt/
cd /opt/$openssh_version && ./configure --prefix=/usr/local/openssh --sysconfdir=/etc/ssh --with-zlib --with-ssl-dir=/usr/local/openssl
make -j 4 && make install
if [ $? -eq 0 ]
 then
  chmod 600 /etc/ssh/*
  cp -rf /usr/local/openssh/sbin/sshd /usr/sbin/sshd
  cp -rf /usr/local/openssh/bin/ssh /usr/bin/ssh
  cp -rf /usr/local/openssh/bin/ssh-keygen /usr/bin/ssh-keygen
  cp -ar /opt/$openssh_version/contrib/redhat/sshd.init /etc/init.d/sshd
  cp -ar /opt/$openssh_version/contrib/redhat/sshd.pam /etc/pam.d/sshd.pam
else
 echo "error"
 exit 1
fi
}


# edit config
function edit_config() {
cat >>/etc/ssh/sshd_config<<EOF
PermitRootLogin yes
X11Forwarding yes
PasswordAuthentication yes
KexAlgorithms diffie-hellman-group1-sha1,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1,diffie-hellman-group-exchange-sha256,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group1-sha1,curve25519-sha256@libssh.org
EOF
chmod 755 /etc/init.d/sshd

# start service
systemctl enable sshd
systemctl start sshd
}

# use function
check_system
update_openssl
update_openssh
edit_config
