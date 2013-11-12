usr = node['liferay']['user']
downloadDir = "/home/#{usr}/Downloads"
version = node['nexus']['version']
nexusWebappWar = "#{downloadDir}/nexus-#{version}.war"
nexusWebappDir = "#{node['liferay']['install_directory']}/liferay/tomcat/webapps/nexus"

remote_file nexusWebappWar do
  owner usr
  group usr
  source "http://www.sonatype.org/downloads/nexus-#{version}.war"
  action :create_if_missing
end

directory nexusWebappDir do
  owner usr
  group usr
  mode 01750
  action :create
  recursive true
end

execute "Deploy Nexus OSS" do
  cwd downloadDir
  user usr
  group usr
  command "unzip -qd #{nexusWebappDir} #{nexusWebappDir}"
  not_if {File.exist?(nexusWebappDir)}
end

# --- Restart Liferay ---
service "liferay" do
  action :restart
end
