# Introduction
Inotif is a collection of tools to let certain directory of Linux/FreeBSD be stored in a git repository.
This lets you use git to review changes that were made to directory that you monitored. Or even push the repository elsewhere for backups or cherry-picking configuration changes.

# Setup for server

## git init --bare as `git` user (depending on username used)
```bash
$ mkdir /home/git/repository
$ git init --bare /home/git/repository/inotif.git
Initialized empty Git repository in /home/git/repository/inotif.git/
$ sudo ln -s /home/git/repository /git
$ sudo chown git:git /git
```
## setup gitweb
```bash
$ sudo apt-get install -y git gitweb fcgiwrap spawn-fcgi nginx libcgi-fast-perl highlight
$ git clone https://github.com/umardx/inotif.git
$ mv conf/gitweb.conf /home/git/gitweb.conf
```
### add server block for nginx configuration
```
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    #root /var/www/...;
    # Server name is used in the title of GitWeb pages
    server_name localhost;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Git over HTTP
    location ~ ^/git/.*\.git/objects/([0-9a-f]+/[0-9a-f]+|pack/pack-[0-9a-f]+.(pack|idx))$ {
        root /home/git;
    }
    # Remove git-receive-pack in next line to forbid push to this server
    location ~ ^/git/(.*\.git/(HEAD|info/refs|objects/info/.*|git-(upload|receive)-pack))$ {
        rewrite ^/git(/.*)$ $1 break;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME     /usr/lib/git-core/git-http-backend;
        fastcgi_param PATH_INFO           $uri;
        fastcgi_param GIT_PROJECT_ROOT    /home/git/repository;
        fastcgi_param GIT_HTTP_EXPORT_ALL "";
        include fastcgi_params;
    }

    # Git web
    location /git/static/ {
        alias /usr/share/gitweb/static/;
    }
    location /git/ {
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME     /usr/share/gitweb/gitweb.cgi;
        fastcgi_param PATH_INFO           $uri/git;
        fastcgi_param GITWEB_CONFIG       /home/git/gitweb.conf;
        fastcgi_param GIT_HTTP_EXPORT_ALL "";
        include fastcgi_params;
    }
}
```
### add server block for apache configuration
```
<VirtualHost *:80>
    ServerName localhost

    SetEnv GIT_PROJECT_ROOT /home/git/repository
    SetEnv GIT_HTTP_EXPORT_ALL

    AliasMatch ^/git/(.*/objects/[0-9a-f]{2}/[0-9a-f]{38})$          /home/git/$1
    AliasMatch ^/git/(.*/objects/pack/pack-[0-9a-f]{40}.(pack|idx))$ /home/git/$1
    # Remove git-receive-pack in next line to forbid push to this server
    ScriptAliasMatch \
            "(?x)^/git/(.*/(HEAD | \
                            info/refs | \
                            objects/info/[^/]+ | \
                            git-(upload|receive)-pack))$" \
            /usr/libexec/git-core/git-http-backend/$1

    ScriptAlias /git/ /usr/share/gitweb/gitweb.cgi/
    Alias /git /usr/share/gitweb
    <Directory "/usr/share/gitweb/">
        AddHandler cgi-script .cgi
        DirectoryIndex gitweb.cgi
        Options +ExecCGI

        AllowOverride None
        Order allow,deny
        Allow from all

        SetEnv GITWEB_CONFIG /home/git/gitweb.conf
    </Directory>
</VirtualHost>
```

### If you want to change the design theme
Install gitweb-theme:
```bash
$ cd /usr/share/gitweb
$ sudo git clone git://github.com/kogakure/gitweb-theme
$ sudo /usr/share/gitweb/gitweb-theme/setup --install
```

### Setup Agent

#### Debian derivative
- Create user with name: Inotif
- Do this:
> sudo cp inotif /usr/local/bin/
> sudo cp init.d/inotif /etc/init.d/
> sudo cp conf/inotif.conf /etc/
> sudo update-rc.d inotif defaults
> sudo update-rc.d inotif enable

Based on [this](https://www.digitalocean.com/community/tutorials/how-to-configure-a-linux-service-to-start-automatically-after-a-crash-or-reboot-part-1-practical-examples)

#### FreeBSD
- Create user with name: Inotif
- Do this:
> sudo cp inotif /usr/local/bin/...
> sudo cp rc.d/inotif /etc/rc.d/
> sudo cp conf/inotif.conf /etc/

Based on: [this](https://www.freebsd.org/doc/handbook/configtuning-starting-services.html) and [this](ttps://joekuan.wordpress.com/2010/05/09/quick-tutorial-on-how-to-create-a-freebsd-system-startup-script/)
