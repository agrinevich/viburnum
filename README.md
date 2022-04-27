![Deploy](https://github.com/agrinevich/viburnum/workflows/Deploy_avl/badge.svg?branch=main)

# CMS Viburnum

## General

Viburnum is Content Management System (CMS) with builtin Static Site Generator.

This project is still **work in progress**. You can get updates in one of following ways:
- create ssh key on your server and i will send updates via Github actions
- or just git clone this repo and then git pull

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

## Install

TODO: add install instructions

## Add website

TODO: add new site instructions

## Usage

TODO: add CMS manual
