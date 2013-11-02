# --- Install prerequisites ---
package 'imagemagick'
package 'unzip'
package 'openjdk-7-jre-headless'

# --- Set host name ---
hostname = node['liferay']['hostname']

file '/etc/hostname' do
  content "#{hostname}\n"
end

service 'hostname' do
  action :restart
end

file '/etc/hosts' do
  content "127.0.0.1 localhost #{hostname}\n"
end
