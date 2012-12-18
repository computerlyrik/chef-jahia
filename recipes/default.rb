#
# Cookbook Name:: jahia
# Recipe:: default
#
# Copyright 2012, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

################### Firewalling Configuration
include_recipe "firewall::iptables"

firewall "iptables" do
  action :flush
end

execute "/sbin/iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080"


################### Mysql Configuration
node.set['mysql']['bind_address'] = "127.0.0.1"
include_recipe "mysql::server"
include_recipe "database::mysql"
node.set_unless['jahia']['mysql_password'] = secure_password

#setup db
mysql_connection_info = {:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']}

mysql_database_user node['jahia']['mysql_user'] do
  password  node['jahia']['mysql_password']
  database_name node['jahia']['mysql_database']
  connection mysql_connection_info
  action :grant
end

mysql_database node['jahia']['mysql_database'] do
  connection mysql_connection_info
  action :create
end 

################### Tomcat Configuration
node.set["tomcat"]["java_options"] = "-Xms1024m -Xmx1024m -Djava.awt.headless=true -XX:MaxPermSize=256m -server -Dhibernate.jdbc.use_streams_for_binary=true -verbose:gc"
#node.set["tomcat"]["pid"]=/tmp/jahia-6.6.pid
include_recipe "tomcat"

service "tomcat6"

directory "#{node['tomcat']['base']}/lib" do
  action :create
  owner node['tomcat']['user']
  group node['tomcat']['user']
end

%w{annotations-api.jar
    catalina-ant.jar
    catalina-ha.jar
    catalina.jar
    catalina-tribes.jar
    ccpp-1.0.jar
    ecj-3.7.jar
    el-api.jar
    jahia-server-utils-1.3.jar
    jasper-el.jar
    jasper.jar
    jsp-api.jar
    pluto-container-api-2.0.2.jar
    pluto-container-driver-api-2.0.2.jar
    pluto-taglib-2.0.2.jar
    portals-bridges-common-1.0.4.jar
    portlet-api_2.0_spec-1.0.jar
    servlet-api.jar
    tomcat-coyote.jar
    tomcat-dbcp.jar
    tomcat-i18n-es.jar
    tomcat-i18n-fr.jar
    tomcat-i18n-ja.jar}.each do |lib|
  cookbook_file "#{node['tomcat']['base']}/lib/#{lib}" do
    owner node['tomcat']['user']
    group node['tomcat']['user']
    action :create_if_missing
  end
end

################### User Configuration
group node['jahia']['user'] do
  gid 999
end

user node['jahia']['user'] do
  gid node['jahia']['user']
  home node['jahia']['home_dir']
  shell "/bin/sh"
  supports :manage_home => true
  system true
end

group "adm" do
  action :modify
  members node['jahia']['user']
  append true
end

group node["tomcat"]["group"] do
  action :modify
  members node['jahia']['user']
  append true
end

################### Maven Configuration
node.set['maven']['version'] = 3
node.set['maven']['3']['url'] = 'http://mirror.netcologne.de/apache.org/maven/maven-3/3.0.4/binaries/apache-maven-3.0.4-bin.tar.gz'
include_recipe "maven"

link "/usr/bin/mvn" do
  to "/usr/local/maven/bin/mvn"
end

################### Jahia Configuration

directory node['jahia']['local_repository'] do
  owner node['tomcat']['user']
  group node['tomcat']['user']
end

directory "/root/.m2/"

node.set_unless['jahia']['root_password'] = secure_password
#give settingsxml direct to mvn if possible
template "/root/.m2/settings.xml" 

################### Jahia Checkout&Build -defined reverseful
package "subversion"


#####encapsulate some directory and file processes needed during installation
directory "jackrabbit_workdir" do
  path "#{node['tomcat']['webapp_dir']}/ROOT/WEB-INF/var/repository/workspaces"
  owner node['tomcat']['user']
  recursive true
  action :nothing
end
directory "root_dir" do
  path "#{node['tomcat']['webapp_dir']}/ROOT"
  owner node['tomcat']['user']
  recursive true
  action :nothing
end

#fix a bug
file "#{node['tomcat']['base']}/velocity.log" do
  owner node['tomcat']['user']
  action :create_if_missing 
end


##checkout and install jahia

execute "test" do
  command "echo foobar >> #{node['jahia']['build_log']}"
  action :run
end

#NOTE :sync will be called on updates, if revision is re-set
subversion node['jahia']['app_dir'] do
  repository "http://subversion.jahia.org/svn/jahia/trunk"
  revision node['jahia']['revision']
  action :sync

end

execute "build" do
  command "mvn install >> #{node['jahia']['build_log']}"
  cwd node['jahia']['app_dir']
  environment ({'MAVEN_OPTS'=>'-Xmx1024m'})
  subscribes :run, resources(:subversion => node['jahia']['app_dir'] ), :immediately
  notifies :stop, resources(:service => "tomcat6"), :immediately
  notifies :delete, resources(:directory => "root_dir"), :immediately
  notifies :create, resources(:directory => "root_dir"), :immediately
  action :nothing
end

execute "deploy" do
  command "mvn jahia:deploy >> #{node['jahia']['build_log']}"
  cwd node['jahia']['app_dir']
  environment ({'MAVEN_OPTS'=>'-Xmx1024m'})
  action :nothing
  subscribes :run, resources(:execute=>"build"), :immediately
  notifies :create, resources(:directory=>"jackrabbit_workdir"), :immediately
end

execute "configure" do
  command "mvn jahia:configure >> #{node['jahia']['build_log']}"
  cwd node['jahia']['app_dir']
  action :nothing
  subscribes :run, resources(:execute=>"deploy")
end

##checout and install jahia assets
package "git-core"

#needs modify of pom xml to build all modules
git "/jahia-modules" do
  repository "https://github.com/Jahia/modules-set.git"
  action :sync
end

execute "install-modules" do
  cwd "/jahia-modules"
  command "mvn clean install jahia:deploy >> #{node['jahia']['build_log']}"
  action :nothing
  subscribes :run, resources(:git => "/jahia-modules"), :immediately
end

git "/jahia-templates" do
  repository "https://github.com/Jahia/templates-set.git"
  action :sync
end

execute "install-templates" do
  cwd "/jahia-templates"
  command "mvn clean install jahia:deploy >> #{node['jahia']['build_log']}"
  action :nothing
  subscribes :run, resources(:git => "/jahia-templates"), :immediately
end

##finalize
execute "finalize" do
  command "chown -R #{node['tomcat']['user']}:#{node['tomcat']['user']} #{node['tomcat']['webapp_dir']}/ROOT  node['jahia']['local_repository']"
  action :nothing
  subscribes :run, resources(:execute=>"configure")
  subscribes :run, resources(:execute =>"install-modules")
  subscribes :run, resources(:execute =>"install-templates")
  notifies :create_if_missing, resources(:file=>"#{node['tomcat']['base']}/velocity.log"), :immediately
  notifies :restart, resources(:service=>"tomcat6")
end

