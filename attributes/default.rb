
#Use the revision of trunk to set your current jahia version
default['jahia']['revision'] = "43358" #Jahia 6.6.1.0
#default['jahia']['revision'] = "43631" #Jahia 6.6.1.1

default['jahia']['user'] = 'jahia'
default['jahia']['group'] = 'jahia'

default['jahia']['root_user'] = 'root'

default['jahia']['mysql_user'] = 'jahia'
default['jahia']['mysql_database'] = 'jahia'

default['jahia']['home_dir'] = "/home/#{node['jahia']['user']}"
default['jahia']['app_dir'] = "/jahia"


default['jahia']['build_log'] = "/var/log/jahia_build.log"
default['jahia']['local_repository'] = "/jahia-repository"
