# Introduction
Inotif is a collection of tools to let certain directory of Linux/FreeBSD be stored in a git repository.
This lets you use git to review changes that were made to directory that you monitored. Or even push the repository elsewhere for backups or cherry-picking configuration changes.

# Setup for Server
## Setup nginx + git-http-backend + http authentication:
```bash
$ sudo apt-get install -y git gitweb fcgiwrap spawn-fcgi nginx libcgi-fast-perl highlight apache2-utils
```
Setup repository : `git init --bare`
```bash
$ sudo mkdir -p /var/www/git
$ cd /var/www/git
$ sudo git init --bare /var/www/git/inotif.git
Initialized empty Git repository in /var/www/git/inotif.git
$ cp /var/www/git/inotif.git/hooks/post-update.sample /var/www/git/inotif.git/hooks/post-update
$ chmod a+x /var/www/git/inotif.git/hooks/post-update
$ sudo sh -c 'echo "Inotif repository." > /var/www/git/inotif.git/description'
$ sudo chown -R www-data:www-data /var/www/git
```
modify `/etc/gitweb.conf`
```bash
# path to git projects (<project>.git)
$projectroot = "/var/www/git";

# directory to use for temp files
$git_temp = "/tmp";

# target of the home link on top of all pages
$home_link = $my_uri || "/";

# html text to include at home page
$home_text = "indextext.html";

# file with project list; by default, simply scan the projectroot dir.
$projects_list = $projectroot;

# stylesheet to use
@stylesheets = ("static/gitweb.css");

# javascript code for gitweb
$javascript = "static/gitweb.js";

# logo to use
$logo = "static/git-logo.png";
$logo_url = ".";
$logo_label = "Local Git Repositories";

# the 'favicon'
#$favicon = "static/git-favicon.png";

# git-diff-tree(1) options to use for generated patches
#@diff_opts = ("-M");
@diff_opts = ();

# This prevents gitweb to show hidden repositories
#$export_ok = "git-daemon-export-ok";
#$strict_export = 1;

# This lets it make the URLs you see in the header
@git_base_url_list = ( 'http://localhost:8080' );

# Features: syntax highlighting and blame view
$feature{'highlight'}{'default'} = [1];
$feature{'blame'}{'default'} = [1];
```
add server block for nginx configuration
```bash
server {
    listen 8080;
    server_name local_git;
    access_log /var/log/nginx/git.access.log;

    auth_basic           "GIT LOGIN";
    auth_basic_user_file /etc/nginx/.htpasswd;

    client_max_body_size 0; # Avoid fatal: The remote end hung up unexpectedly

    location /index.cgi {
        root /usr/share/gitweb/;
        include fastcgi_params;
        gzip off;
        fastcgi_param SCRIPT_NAME $uri;
        fastcgi_param GITWEB_CONFIG /etc/gitweb.conf;
        fastcgi_pass  unix:/var/run/fcgiwrap.socket;
    }

    location / {
        root /usr/share/gitweb/;
        index index.cgi;
    }
    # static repo files for cloning           
    location ~ ^.*\.git/objects/([0-9a-f]+/[0-9a-f]+|pack/pack-[0-9a-f]+.(pack|idx))$ {
        root /var/www/git/;
    }

    # requests that need to go to git-http-backend
    location ~ ^.*\.git/(HEAD|info/refs|objects/info/.*|git-(upload|receive)-pack)$ {
        root /var/www/git;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME   /usr/lib/git-core/git-http-backend;
        fastcgi_param PATH_INFO         $uri;
        fastcgi_param GIT_PROJECT_ROOT  /var/www/git;
        fastcgi_param GIT_HTTP_EXPORT_ALL "";
        fastcgi_param REMOTE_USER $remote_user;
        include fastcgi_params;
    }
}
```
You can add a username to the file using this command. You'll need to authenticate, then specify and confirm a password. For example using `git` as username, but you can use whatever name you'd like:
```bash
$ sudo htpasswd -c /etc/nginx/.htpasswd git
```
If you want to change the design theme
Install gitweb-theme:
```bash
$ cd /usr/share/gitweb
$ sudo git clone git://github.com/kogakure/gitweb-theme
$ sudo /usr/share/gitweb/gitweb-theme/setup --install
```
$ sudo sh -c '/usr/share/gitweb/gitweb-theme/setup --install'
```
## Setup consul for remote environment:
Consul must be downloaded and unzipped. The software comes as a single statically linked binary which makes the installation very simple: It can simply be placed in a directory which is listed in $PATH. I used /usr/local/bin for this purpose.
```bash
$ sudo apt-get -y install unzip
$ wget https://releases.hashicorp.com/consul/0.9.0/consul_0.9.0_linux_amd64.zip
$ unzip consul_0.9.0_linux_amd64.zip
$ sudo mv consul /usr/local/bin/
$ rm consul_0.9.0_linux_amd64.zip
```
To automatically start Consul an Init and Systemd Script can be downloaded [here](https://gist.github.com/umardx/675ab11330bf10b9a308b02fc411eb35). The init script or systemd script defines /etc/consul/ as the configuration directory for Consul. This directory must be created and populated with a Consul configuration file.
```bash
# mkdir -p /etc/consul
# cat << EOF > /etc/consul/config.json
{
    "bind_addr": "192.168.114.35",
    "client_addr": "0.0.0.0",
    "ui": true,
    "datacenter": "dc1",
    "data_dir": "/var/consul",
    "encrypt": "yJ9iwAO918Zb9RzaHDSUcA==",
    "log_level": "INFO",
    "enable_syslog": true,
    "enable_debug": true,
    "node_name": "inotif-node",
    "server": true,
    "bootstrap_expect": 1,
    "leave_on_terminate": false,
    "skip_leave_on_interrupt": true,
    "rejoin_after_leave": true,
    "retry_join": [
      "192.168.114.35:8301"
    ]
}
EOF
```
To generates an encryption key that can be used for Consul agent traffic encryption. The keygen command uses a cryptographically strong pseudo-random number generator to generate the key.
```bash
$ consul keygen
yJ9iwAO918Zb9RzaHDSUcA=="
```
The parameter `bootstrap_expect` is set to 1 (add node at `retry-join` parameter to add more bootstrap) which means consul will wait for at least 1 nodes to appear before a leader election will happen. So don’t expect a lot to happen at this point. These steps must be repeated on every other Consul server instance. Make sure to adjust the values for `node_name`, `client_addr`, and `bind_addr` to match the configuration of the particular node.
## Troubleshooting
If you see ngingx error.log say something like
```bash
connect() to unix:/var/run/fcgiwrap.socket failed (13: Permission denied) while connecting
```
then check the owner:group of /var/run/fcgiwrap.socket (it should be www-data:www-data). If not, just restart FCGIwrap:
```bash
$ sudo /bin/systemctl restart fcgiwrap nginx
```

# Setup for Client (Agent)
#### Tested on Ubuntu 16.04, Debian 7.11, Debian 8.8, and FreeBSD 11.1.

1. Set up ssh-key pair to all client

2. Clone git repository
    ```
    $ git clone https://github.com/umardx/inotif.git
    ```
3. Edit config file:
    - In folder `conf`, copy file `inotif.conf.example` to `inotif.conf` and set-up parameter there (adjust to your network setting).
    - In folder `conf`, copy file `supervisord.conf.example` to `supervisord.conf` and set-up parameter there (optional, if you just copy-paste it will run).

4. Go to ansible playbook folder
    ```
    $ cd ansible-playbook
    ```
5. Copy file `hosts.example` to `hosts` and edit data with IP Client

6. Start ansible
    ```
    $ ansible-playbook -i hosts playbook.yml
    ```

