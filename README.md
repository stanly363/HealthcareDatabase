Healthcare Management Database Configuration and Import Guide

This guide provides a brief overview of essential configuration files and step-by-step instructions for setting up the PostgreSQL database on a Linux system.

File Descriptions
postgresql.conf Defines database settings, including security, logging, memory management, and SSL configurations.

pg_hba.conf Controls user authentication and access permissions for the database.

server.key The private key for SSL encryption—must be secured with correct file permissions.

server.crt The SSL certificate for encrypting client-server communications.

Executable.sql Creates all tables, functions, roles, and views necessary for the database.

IM.sql Resets all database data and ID sequences for testing purposes.

test.sh Populates the database and verifies that all functions and views work correctly.

Installation Instructions
Step 1: Stop PostgreSQL Service
Before replacing configuration files, stop the PostgreSQL service: sudo systemctl stop postgresql

Step 2: Replace Configuration Files
Copy the new configuration files to the correct location, replacing the existing ones: sudo cp postgresql.conf /etc/postgresql/16/main/ sudo cp pg_hba.conf /etc/postgresql/16/main/

Step 3: Move SSL Keys and Certificates
Move the SSL key and certificate to their respective directories: sudo mv server.key /etc/ssl/private/ sudo mv server.crt /etc/ssl/certs/

Step 4: Set Permissions for SSL Key
Ensure the private key has the correct permissions for security: sudo chmod 600 /etc/ssl/private/server.key sudo chown postgres:postgres /etc/ssl/private/server.key

Step 5: Restart PostgreSQL
Restart the PostgreSQL service to apply the new configurations: sudo systemctl start postgresql

Step 6: Import Database Schema
Run the executable SQL script to set up the database: psql -U postgres -f /path/to/Executable.sql

Step 7: Verify Database Setup
Run the test script to confirm that everything is configured correctly: chmod +x test.sh ./test.sh

Step 8: Manually Test Roles
You can login as each role with the below credentials: username : password healthcare_admin : admin healthcare_staff : doctor healthcare_user : user
