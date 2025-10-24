-- Create the password user
CREATE USER auth_user WITH PASSWORD 'auth_password'; 

-- Create the database 'musr' 
CREATE DATABASE musr OWNER kasmi;

-- Create the schema and table (Run while connected to the musr database)
\c musr; 

-- Create schema 'aaa'
CREATE SCHEMA aaa;

-- Create table 'lg_fi' inside schema 'aaa'
CREATE TABLE aaa.lg_fi (
    -- The user's login identifier (mail or person_id/customer_id).
    login TEXT PRIMARY KEY,
    
    -- The bcrypt hashed password.
    pswd_hash TEXT NOT NULL 
);

-- Grant necessary permissions to the Flask application user
GRANT CONNECT ON DATABASE musr TO auth_user;
GRANT USAGE ON SCHEMA aaa TO auth_user;
GRANT SELECT ON aaa.lg_fi TO auth_user;