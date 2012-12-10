maintainer       "computerlyrik"
maintainer_email "chef-cookbooks@computerlyrik.de"
license          "Apache 2.0"
description      "Installs and configures jahia Java CMS"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

%w{ mysql database tomcat maven openssl firewall}.each do |dep|
  depends dep
end

%w{ ubuntu }.each do |os|
  supports os
end
