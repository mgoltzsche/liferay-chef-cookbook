require 'uri'

# --- Create liferay system user ---
user node['liferay']['user'] do
  comment 'Liferay User'
  home "/home/#{node['liferay']['user']}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download and install Liferay ---
downloadDir = "/home/#{node['liferay']['user']}"
liferayZipFile = File.basename(URI.parse(node['liferay']['download_url']).path)
liferayExtractionDir = liferayZipFile.gsub(/liferay-portal-[\w]+-(([\d]+\.?)+-[\w]+(-[\w]+)?)-[\d]+.zip/, 'liferay-portal-\1')

remote_file "#{downloadDir}/#{liferayZipFile}" do
  owner node['liferay']['user']
  group node['liferay']['group']
  source node['liferay']['download_url']
  action :create_if_missing
  notifies :run, "bash[Extract Liferay]", :immediately
end

bash "Extract Liferay" do
  cwd downloadDir
  user node['liferay']['user']
  group node['liferay']['group']
  code "unzip -q #{liferayZipFile}"
  action :nothing
  notifies :run, "bash[Move Liferay]", :immediately
end

bash "Move Liferay" do
  cwd downloadDir
  user "root"
  code "mv #{liferayExtractionDir} #{node['liferay']['install_directory']}"
  action :nothing
end

# --- Clean up Liferay installation ---
Dir.glob("#{node['liferay']['install_directory']}/liferay/tomcat/bin/*.bat").each do |bat_file|
  file bat_file do
    action :delete
  end
end

directory "#{node['liferay']['install_directory']}/liferay/tomcat/webapps/welcome-theme" do
  recursive true
  action :delete
end

directory "#{node['liferay']['install_directory']}/liferay/tomcat/webapps/resources-importer-web" do
  recursive true
  action :delete
end