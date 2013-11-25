require 'uri'

hostname = node['liferay']['hostname']
usr = node['liferay']['user']
downloadDir = "/Downloads"
liferayZipFile = File.basename(URI.parse(node['liferay']['download_url']).path)
liferayFullName = liferayZipFile.gsub(/liferay-portal-[\w]+-(([\d]+\.?)+-[\w]+(-[\w]+)?)-[\d]+.zip/, 'liferay-portal-\1')
liferayExtractionDir = "/tmp/#{liferayFullName}"
aprSourceArchive = File.basename(URI.parse(node['liferay']['apr_download_url']).path)
aprSourceFolder = aprSourceArchive.gsub(/(.*?)\.tar\.bz2/, '\1')
aprSourcePath = "#{downloadDir}/#{aprSourceFolder}"
nativeConnectorSourceArchive = File.basename(URI.parse(node['liferay']['native_connectors_download_url']).path)
nativeConnectorSourceFolder = nativeConnectorSourceArchive.gsub(/(.*?)\.tar\.gz/, '\1')
nativeConnectorSourcePath = "#{downloadDir}/#{nativeConnectorSourceFolder}"
liferayDir = "#{node['liferay']['install_directory']}/#{liferayFullName}"
liferayDirLink = "#{node['liferay']['install_directory']}/liferay"
liferayHomeDir = node['liferay']['home']
dbname = node['liferay']['postgresql']['database']
ldapHost = node['ldap']['hostname']
ldapPort = node['ldap']['port']
ldapSuffix = node['ldap']['domain'].split('.').map{|dc| "dc=#{dc}"}.join(',')
ldapUser = node['liferay']['ldap']['user']
ldapPassword = node['liferay']['ldap']['password']
ldapPasswordHashed = ldapPassword
mailServerHost = node['mail_server']['hostname']
admin = node['ldap']['admin_cn']
adminPassword = node['ldap']['admin_password']
adminEmail = "#{admin}@#{hostname}"
timezone = node['liferay']['timezone']
country = node['liferay']['country']
language = node['liferay']['language']

package 'libssl-dev'

# --- Create Liferay system user ---
user usr do
  comment 'Liferay User'
  shell '/bin/bash'
  home liferayHomeDir
  supports :manage_home => true
end

# --- Create Liferay LDAP user ---
execute "Register system mail account" do
  command <<-EOH
echo "dn: cn=#{ldapUser},ou=People,#{ldapSuffix}
objectClass: glue
objectClass: simpleSecurityObject
objectClass: top
objectClass: mailRecipient
cn: #{ldapUser}
mail: #{ldapUser}@#{hostname}
mailForwardingAddress: #{adminEmail}
userPassword:: #{ldapPasswordHashed}
" > /tmp/admin_user.ldif &&
ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd} -f /tmp/admin_user.ldif &&
rm -f /tmp/admin_user.ldif
  EOH
#end

# --- Download and install Liferay ---
directory downloadDir do
  mode 00755
end

remote_file "#{downloadDir}/#{liferayZipFile}" do
  source node['liferay']['download_url']
  action :create_if_missing
end

execute "Extract Liferay" do
  cwd downloadDir
  command "unzip -qd /tmp #{liferayZipFile}"
  not_if {File.exist?(liferayDir) || File.exist?(liferayExtractionDir)}
end

execute "Copy Liferay to installation directory" do
  command <<-EOH
cp -R #{liferayExtractionDir}/$(ls #{liferayExtractionDir} | grep tomcat) #{liferayDir} &&
cd #{liferayDir}/bin &&
ls | grep '\\.bat$' | xargs rm &&
cd #{liferayDir}/webapps &&
rm -rf welcome-theme sync-web &&
chown -R #{usr}:#{usr} #{liferayDir}
  EOH
  not_if {File.exist?(liferayDir)}
end

cookbook_file "#{liferayDir}/webapps/ROOT/html/themes/_unstyled/images/favicon.ico"
#cookbook_file "#{liferayHomeDir}/default_logo.png" do
#  action :create_if_missing
#end

link liferayDirLink do
  to liferayDir
end

# --- Create Liferay postgres user and database
execute "Create liferay postgres user '#{node['liferay']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"CREATE USER #{node['liferay']['postgresql']['user']};\""
  not_if("psql -U postgres -c \"SELECT * FROM pg_user WHERE usename='#{node['liferay']['postgresql']['user']}';\" | grep #{node['liferay']['postgresql']['user']}", :user => 'postgres')
end

execute "Set postgres user password of '#{node['liferay']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"ALTER ROLE #{node['liferay']['postgresql']['user']} ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['password']}';\""
end

execute "Create database '#{dbname}'" do
  user 'postgres'
  command "createdb '#{dbname}' -O #{node['liferay']['postgresql']['user']} -E UTF8 -T template0"
  not_if("psql -c \"SELECT datname FROM pg_catalog.pg_database WHERE datname='#{dbname}';\" | grep '#{dbname}'", :user => 'postgres')
end

# --- Download & install native APR library ---
remote_file "#{downloadDir}/#{aprSourceArchive}" do
  source node['liferay']['apr_download_url']
  action :create_if_missing
end

remote_file "#{downloadDir}/#{nativeConnectorSourceArchive}" do
  source node['liferay']['native_connectors_download_url']
  action :create_if_missing
end

execute "Extract APR source" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "tar xvjf #{downloadDir}/#{aprSourceArchive}"
  not_if {File.exist?(aprSourcePath)}
end

execute "Extract native connectors source" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "tar xvzf #{downloadDir}/#{nativeConnectorSourceArchive}"
  not_if {File.exist?(nativeConnectorSourcePath)}
end

execute "Compile APR source" do
  cwd aprSourcePath
  user 'root'
  group 'root'
  command <<-EOH
./configure &&
make &&
make install
  EOH
  not_if 'ls /usr/local/apr/lib | grep libapr-'
end

execute "Compile native connectors source" do
  cwd "#{nativeConnectorSourcePath}/jni/native"
  user 'root'
  group 'root'
  command <<-EOH
./configure --with-apr=/usr/local/apr --with-java-home=/usr/lib/jvm/java-7-openjdk-amd64 &&
make &&
make install
  EOH
  not_if 'ls /usr/local/apr/lib | grep libtcnative-'
end

# --- Configure Liferay tomcat ---
directory "#{liferayHomeDir}/deploy" do
  owner usr
  group usr
  mode 01755
end

template "#{liferayDir}/bin/setenv.sh" do
  owner usr
  group usr
  source "liferay.tomcat.setenv.sh.erb"
  mode 00744
  variables({
    :java_opts => node['liferay']['java_opts']
  })
end

template "#{liferayDir}/conf/server.xml" do
  owner usr
  group usr
  source "liferay.tomcat.server.xml.erb"
  mode 00644
  variables({
    :hostname => hostname,
    :http_port => node['liferay']['http_port'],
    :https_port => node['liferay']['https_port']
  })
end

# --- Configure Liferay ---
template "#{liferayHomeDir}/portal-ext.properties" do
  owner usr
  group usr
  source "liferay.portal-ext.properties.erb"
  mode 00400
  variables({
    :liferay_home => liferayHomeDir,
    :timezone => timezone,
    :country => country,
    :language => language,
    :postgres_port => node['liferay']['postgresql']['port'],
    :postgres_database => node['liferay']['postgresql']['database'],
    :postgres_user => node['liferay']['postgresql']['user'],
    :postgres_password => node['liferay']['postgresql']['password'],
    :company_name => node['liferay']['company_default_name'],
    :hostname => hostname,
    :admin_full_name => node['liferay']['admin']['name'],
    :admin_screen_name => admin,
    :admin_email => adminEmail,
    :admin_password => adminPassword,
    :mailServerHost => mailServerHost,
    :ldapHost => ldapHost,
    :ldapPort => ldapPort,
    :ldapSuffix => ldapSuffix,
    :ldapUser => ldapUser,
    :ldapPassword => ldapPassword
  })
end

# --- Register Liferay as service ---
template "/etc/init.d/liferay" do
  source "init.d.liferay.erb"
  mode 00755
  variables({
    :liferayDir => liferayDirLink,
    :liferayHomeDir => liferayHomeDir,
    :user => usr
  })
end

template "/etc/logrotate.d/liferay" do
  source "logrotate.d.liferay.erb"
  mode 00755
  variables({
    :liferay_log_home => "#{liferayDirLink}/logs"
  })
end

# --- Configure default nginx vhost ---
directory '/usr/share/nginx/cache' do
  owner 'www-data'
  group 'www-data'
  mode 00744
end

cookbook_file '/usr/share/nginx/www/index.html'
cookbook_file '/usr/share/nginx/www/50x.html'

template "/etc/nginx/sites-available/default" do
  source "liferay.nginx.vhost.erb"
  mode 00700
  variables({
    :hostname => hostname,
    :http_port => node['liferay']['http_port'],
    :https_port => node['liferay']['https_port']
  })
end

print <<-EOH
###############################################################################
# Please login as administrator, go to the LDAP configuration dialog and      #
# test your connection (and enable export manually).                          #
# Afterwards LDAP users can login.                                            #
###############################################################################
EOH

# --- Restart nginx ---
service 'nginx' do
  action :restart
end

# --- (Re)start Liferay ---
service "liferay" do
  action :restart
end
