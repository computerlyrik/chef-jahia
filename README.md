# Description

Shall setup jahia (http://jahia.com) Java CMS.

Beta testing phase - feel free....

# Requirements
Cookbooks
```
mysql and database
maven
openssl
firewall::iptables
```

# Attributes
Jahia version to check out
```ruby
default['jahia']['revision'] = "43358" #Jahia 6.6.1.0
```

#Usage
Include ```jahia::default``` recipe
Progress can be watched at ```tail -f /var/log/jahia_build.log```

# Contact
see metadata.rb

