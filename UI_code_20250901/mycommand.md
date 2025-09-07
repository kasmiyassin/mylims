# install the env python my lims

``` 
# install the venv 
sudo apt install python3.12-venv

# create mylims venv
python3 -m venv mylims

# activate
source mylims/bin/activate
deactivate

```

# start the app

```
python3 app.py
```

# Updating the reverse proxy

```
# create conf file
sudo nano  /etc/apache2/sites-available/mylims.conf

# write it on site
sudo a2ensite mylims.conf

# start the apache

sudo systemctl restart apache2 
sudo systemctl reload apache2

```

