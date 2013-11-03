package 'nginx'

# Create cache directory
directory '/usr/share/nginx/cache' do
  owner 'www-data'
  group 'www-data'
  mode 00744
  action :create
end

# Set default vhost and pages
cookbook_file '/usr/share/nginx/www/index.html'
cookbook_file '/usr/share/nginx/www/50x.html'

template "/etc/nginx/sites-available/default" do
  source "default.erb"
  mode 00700
  variables({
    :port => node['liferay']['port']
  })
end

# Restart nginx
service 'nginx' do
  action :restart
end
