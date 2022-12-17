#!/bin/bash

sudo apt update -y
sudo apt install nginx -y
echo "Hello world" > /var/www/html/index.html
sudo systemctl restart nginx