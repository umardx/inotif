# Introduction
Inotif is a collection of tools to let certain directory of Linux/FreeBSD be stored in a git repository.
This lets you use git to review changes that were made to directory that you monitored. Or even push the repository elsewhere for backups or cherry-picking configuration changes.

# Setup for server

## Setup repository : `git init --bare`
```bash
$ sudo mkdir -p /var/www/repository
$ cd /var/www/repository
$ sudo git init --bare /var/www/repository/inotif.git
Initialized empty Git repository in /var/www/repository/inotif.git
# sudo sh -c 'echo "Inotif repository." > /var/www/repository/inotif.git/description'
$ sudo chown -R www-data:www-data /var/www/repository
```
### modify `/etc/gitweb.conf`
```
# path to git projects (<project>.git)
$projectroot = "/var/www/repository";

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
@git_base_url_list = ( 'http://localhost/git' );

# Features: syntax highlighting and blame view
$feature{'highlight'}{'default'} = [1];
$feature{'blame'}{'default'} = [1];

```
## setup gitweb
```bash
$ sudo apt-get install -y git gitweb fcgiwrap spawn-fcgi nginx libcgi-fast-perl highlight apache2-utils
```
### add server block for nginx configuration
```
server {
    listen       8080;
    server_name local_repositories;
    root /usr/share/gitweb;
    access_log /var/log/nginx/git.access.log;

    auth_basic           "GIT LOGIN";
    auth_basic_user_file /home/git/.htpasswd;

    # static repo files for cloning over https
    location ~ ^.*\.git/objects/([0-9a-f]+/[0-9a-f]+|pack/pack-[0-9a-f]+.(pack|idx))$ {
        root /home/git/repositories/;
    }

    # requests that need to go to git-http-backend
    location ~ ^.*\.git/(HEAD|info/refs|objects/info/.*|git-(upload|receive)-pack)$ {
        root /home/git/repositories;

        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME   /usr/lib/git-core/git-http-backend;
        fastcgi_param PATH_INFO         $uri;
        fastcgi_param GIT_PROJECT_ROOT  /home/git/repositories;
        fastcgi_param GIT_HTTP_EXPORT_ALL "";
        fastcgi_param REMOTE_USER $remote_user;
        include fastcgi_params;
    }

    # send anything else to gitweb if it's not a real file
    try_files $uri @gitweb;
    location @gitweb {
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        fastcgi_param SCRIPT_FILENAME   /usr/share/gitweb/gitweb.cgi;
        fastcgi_param PATH_INFO         $uri;
        fastcgi_param GITWEB_CONFIG     /etc/gitweb.conf;
        include fastcgi_params;
   }
}
```
You can add a username to the file using this command. You'll need to authenticate, then specify and confirm a password. For example using `git` as username, but you can use whatever name you'd like:
```
$ sudo htpasswd -c /etc/nginx/.htpasswd git
```
### If you want to change the design theme
Install gitweb-theme:
```bash
$ cd /usr/share/gitweb
$ sudo git clone git://github.com/kogakure/gitweb-theme
$ sudo /usr/share/gitweb/gitweb-theme/setup --install
```