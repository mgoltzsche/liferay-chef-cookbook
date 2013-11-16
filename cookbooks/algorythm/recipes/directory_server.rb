package '389-ds-base'
package 'ldap-utils'

dirman = 'manager'
passwd = 'maximum!'
maxOpenFiles = 4096
hostname = node['hostname']
domain = node['liferay']['hostname']

fullMachineName = "#{hostname}.#{domain}"
domainContexts = domain.each_line('\\.').map(|dc| "dc=#{dc}").join(', ')
print domainContexts

execute "Decrease TCP timeout" do
  command <<-EOH
echo "net.ipv4.tcp_keepalive_time = 600" >> /etc/sysctl.conf &&
sysctl -p
  EOH
  not_if('cat /etc/sysctl.conf | grep "net.ipv4.tcp_keepalive_time = 600"')
end

execute "Increase open file limit" do
  command <<-EOH
echo "*		 soft	 nofile		 #{maxOpenFiles}
*		 hard	 nofile		 #{maxOpenFiles}" >> /etc/security/limits.conf
  EOH
  not_if('cat /etc/security/limits.conf | grep "*		 soft	 nofile		 #{maxOpenFiles}"')
end

execute "Increase open file limit" do
  command <<-EOH
echo "*		 soft	 nofile		 #{maxOpenFiles}
*		 hard	 nofile		 #{maxOpenFiles}" >> /etc/security/limits.conf
  EOH
  not_if('cat /etc/security/limits.conf | grep "*		 soft	 nofile		 #{maxOpenFiles}"')
end

execute "Increase open file limit" do
  command <<-EOH
echo "[General]
FullMachineName= #{fullMachineName}
SuiteSpotUserID= dirsrv
SuiteSpotGroup= dirsrv
ConfigDirectoryLdapURL= ldap://#{fullMachineName}:389/o=NetscapeRoot
ConfigDirectoryAdminID= admin
ConfigDirectoryAdminPwd= thepassword
AdminDomain= #{domain}

[slapd]
ServerIdentifier= #{hostname}
ServerPort= 389
Suffix= #{domainContexts}
RootDN= cn=#{dirman}
RootDNPwd= #{passwd}

[admin]
ServerAdminID= admin
ServerAdminPwd= thepassword
SysUser= dirsrv
" > ds-config.inf &&
ulimit -n #{maxOpenFiles} &&
setup-ds -sf ds-config.inf
rm -f ds-config.inf
  EOH
end

#execute "Configure TCPv4 localhost listening" do
#  command <<-EOH
#echo "dn: cn=config
#changetype: modify
#replace: nsslapd-listenhost
#nsslapd-listenhost: 127.0.0.1" > nsslapd-listenhost.ldif &&
#ldapmodify -a -x -h dev.algorythm.de -p 389 -D cn="#{usr}" -w #{passwd} -f nsslapd-listenhost.ldif
#rm -f nsslapd-listenhost.ldif
#  EOH
#end
