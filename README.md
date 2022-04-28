![Deploy](https://github.com/agrinevich/viburnum/workflows/Deploy_avl/badge.svg?branch=main)

# CMS Viburnum

## General

Viburnum is Content Management System (CMS) with builtin Static Site Generator.

This project is still **work in progress**.

![screenshot](/assets/images/cms-viburnum-screenshot.png)

CMS consists of 3 applications:

1. Admin ([Plack](https://github.com/plack/Plack/) web app)
2. User ([Plack](https://github.com/plack/Plack/) web app)
3. JobQueue ([TheSchwartz](https://github.com/akiym/TheSchwartz/) app)

## Requirements

VPS server with root access is required (to install Perl modules, etc).

You will need on server:

- ssh
- git
- cpanminus (to install Perl dependencies)
- gcc
- nginx
- mariadb
- rsync (to deploy from 'spot' dir to web-server dir with [Rex](https://github.com/RexOps/Rex/))
- mc (optional)
- tmux (optional)
- certbot
- Perl modules from 'cpanfile' (dependencies)

On Debian cpanm probably will run into errors with some Perl modules. In such case install these modules from Debian repository (with apt).

## Setup

Each website on server needs its own system user.

- add system user (like 'myblog' if you have site 'myblog.com')
- create and store tmux session (optional, you can skip this step)
- connect to server via ssh
- switch to root (su -)
- mkdir /var/www/myblog.com
- chown -R $USER:$USER /var/www/myblog.com
- chmod -R 755 /var/www/myblog.com (if you need)
- create myblog.com.conf in /etc/nginx/conf.d/ (there's example in github repo)
- restart nginx
- switch back to your system user ('myblog')
- create /var/www/myblog.com/index.html
- redirect domain A-records to ip of your server
- create dir /home/user/spot
- git clone repo to 'spot' dir (if you're setting up server for your real world client you should create ssh key and deploy via Github Action)
- cd spot
- run 'prove -l' to check all dependencies met and code compiles
- create MariaDB user ('myblog' for example)
- create MariaDB database ('myblog_db' for example)
- grant privileges ( as shown in commented rows at top of init.sql )
- check/change prefilled primary language in init.sql (English by default)
- mysql -u admin -p myblog_db < ~/spot/init.sql
- cd /var/www/myblog.com
- create dirs: tmp, log, img/la, img/sm, img2/la, img2/sm, data/breadcrumbs, data/navi, bkp
- create and fill main.conf
- copy ~/spot/tpl-front to /var/www/myblog.com
- setup ssh connection from local PC to server with key auth
- [from local PC] scp -r ./html/* myblog@serverip:/home/myblog/spot/html
- [on server] copy files from ./spot/html to /var/www/myblog.com/html
- [on local PC] create project dir and .Rexfile in it (there's example in repo)
- check port numbers in .Rexfile (it must be the same in myblog.com.conf for nginx)
- rex -f .Rexfile deploy (you need [Rex](https://github.com/RexOps/Rex/) on local PC to start, stop, deploy Viburnum app), probably i should add more ways to do it
- run "certbot --nginx" to install Let's Encrypt certificate
- restart nginx

## Usage

Go "www.myblog.com/admin/" and enter login and password you set in main.conf

TODO: add CMS manual
