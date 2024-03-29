![Deploy](https://github.com/agrinevich/viburnum/workflows/Deploy_avl/badge.svg?branch=main)

# CMS Viburnum

## General

This project will be DEPRECATED - [pagekit](https://github.com/agrinevich/pagekit) is successor.

Viburnum is Content Management System (CMS) with builtin Static Site Generator.


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
- rsync (to deploy from 'spot' dir to web-server dir)
- mc (optional)
- tmux (optional)
- certbot
- Perl modules from 'cpanfile' (dependencies)

On Debian cpanm probably will run into errors with some Perl modules. In such case install these modules from Debian repository (with apt).

## Setup

- connect to server via ssh (or [Cockpit](https://github.com/cockpit-project/cockpit/)) as root
- add dedicated user for website (like 'myblog' if you have site 'myblog.com')
- disconnect
- setup ssh login to server with keys (create ssh keys and transfer public key to server)
- connect via ssh as dedicated user (like 'myblog')
- chsh --shell /bin/bash myblog (optional, you can skip this step)
- create and store tmux session (optional, you can skip this step)
- switch to 'root' (su -)
- mkdir /var/www/myblog.com
- chown -R myblog:myblog /var/www/myblog.com
- chmod -R 755 /var/www/myblog.com (if you need)
- create myblog.com.conf in /etc/nginx/conf.d/ (there's example in github repo)
- restart nginx
- switch back to dedicated user ('myblog')
- create /var/www/myblog.com/html/index.html
- create dir ~/spot
- git clone repo to 'spot' dir (if you're setting up server for your real world client you can either create ssh key and deploy via Github Action or just git pull manually to 'spot' dir)
- cd spot
- run 'prove -l' to check all dependencies met and code compiles
- create MariaDB user ('myblog' for example)
- create MariaDB database ('myblog_db' for example)
- grant privileges ( as shown in commented rows at top of init.sql )
- check/change prefilled primary language in init.sql (English by default)
- mysql -u admin -p myblog_db < ~/spot/init.sql
- cd /var/www/myblog.com
- create dirs: tmp, log, bkp, img/la, img/sm, img2/la, img2/sm, data/navi, data/breadcrumbs
- create and fill main.conf
- copy ~/spot/tpl-front to /var/www/myblog.com (you can use mc)
- create ~/spot/rsync.exclude (example file in repo)
- [on local PC] scp -r ./html/* myblog@serverip:/var/www/myblog.com/html
- [on local PC] create project dir and .Rexfile in it (there's example in repo)
- check port numbers in .Rexfile (it must be the same in myblog.com.conf for nginx, and for each website you must use its own port numbers)
- rex -f .Rexfile deploy (you need [Rex](https://github.com/RexOps/Rex/) on local PC to start, stop, deploy Viburnum app), probably i should add more ways to do it
- redirect domain A-records to ip of your server
- when ip points to server run "certbot --nginx" to install Let's Encrypt certificate
- restart nginx

## Usage

Go "myblog.com/admin/" and enter login and password you set in main.conf

TODO:
- add CMS manual
- add unit tests
- add how to create custom plugin
