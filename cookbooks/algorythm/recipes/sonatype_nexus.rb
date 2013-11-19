usr = node['liferay']['user']
downloadDir = "/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusDeployWarFile = "#{node['liferay']['install_directory']}/liferay/deploy/nexus.war"
hostname = node['nexus']['hostname']

# --- Download & deploy Nexus OSS ---
remote_file nexusWarFile do
  source "http://www.sonatype.org/downloads/nexus-#{version}.war"
  action :create_if_missing
end

execute "Deploy Sonatype Nexus" do
  user usr
  group usr
  command "cp #{nexusWarFile} #{nexusDeployWarFile}"
  not_if {File.exist?("#{node['liferay']['install_directory']}/liferay/tomcat/webapps/nexus")}
end

link "/etc/nginx/sites-enabled/#{hostname}" do
  to "/etc/nginx/sites-available/#{hostname}"
end

# --- Restart nginx ---
service "nginx" do
  action :restart
end
