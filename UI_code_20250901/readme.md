Run the code with function:

the following code run the following command ` python3 app.py `.



# Updating the reverse proxy

```
<VirtualHost *:80>
    ServerName 134.110.12.162
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    ErrorLog  ${APACHE_LOG_DIR}/mylimsdemo-error.log
    CustomLog ${APACHE_LOG_DIR}/mylimsdemo-access.log combined

    ProxyRequests Off
    ProxyPreserveHost On
    # (make sure modules are enabled: a2enmod proxy proxy_http headers)

    # /mylims_demo -> 127.0.0.1:5400
    <Location "/mylims_demo/">
        ProxyPass        http://127.0.0.1:5400/
        ProxyPassReverse http://127.0.0.1:5400/
        RequestHeader set X-Forwarded-Proto "http"
    </Location>
    # If the app sets cookies/paths, keep them under the prefix:
    ProxyPassReverseCookiePath / /mylims_demo/

    # /mylims -> 127.0.0.1:5300
    <Location "/mylims/">
        ProxyPass        http://127.0.0.1:5300/
        ProxyPassReverse http://127.0.0.1:5300/
        RequestHeader set X-Forwarded-Proto "http"
    </Location>
    ProxyPassReverseCookiePath / /mylims/
</VirtualHost>

```

```
sudo nano  /etc/apache2/sites-available/mylims.conf
sudo a2ensite mylims.conf
sudo systemctl restart apache2 
sudo systemctl reload apache2
```

Run the code with function:

the following code run the following command ` python3 app.py `.



# Updating the reverse proxy

ö
``` git init git add . git commit -m "Initial commit" ``` 


``` 
git init git add . 
git commit -m "Initial commit"
```


```
wget https://anaconda.org/nmquijada/tormes-1.0/2019.04.25.180147/download/tormes-1.0.yml
conda env create -n tormes-1.0 --file tormes-1.0.yml
```



# Steps to run with Gunicorn 

```
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:8000 app_test:app
``` 

- app_test → filename without .py
- app → Flask instance name inside that file
- -w 4 → use 4 worker processes
- -b 0.0.0.0:8000 → bind to port 8000 (change if needed)

**production command**

```
gunicorn --workers 4 --threads 2 --timeout 60 --bind 0.0.0.0:8000 app_test:app
```

gunicorn --workers 10 --threads 10 --timeout 60 --bind 0.0.0.0:5300 app_test:app
