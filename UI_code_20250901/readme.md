Run the code with function:

the following code run the following command ` python3 app.py `.



# Updating the reverse proxy

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

app_test → filename without .py
app → Flask instance name inside that file
-w 4 → use 4 worker processes
-b 0.0.0.0:8000 → bind to port 8000 (change if needed)

**production command**

```
gunicorn --workers 4 --threads 2 --timeout 60 --bind 0.0.0.0:8000 app_test:app
```
