#!/bin/bash

read -p "Password: " -s PASSWORD
echo
read -p "User id: " USER_ID
read -p "Homeserver url (with https://): " HS

data="{
    \"type\": \"m.login.password\",
    \"identifier\": {
        \"type\": \"m.id.user\",
        \"user\": \"$USER_ID\"
    },
    \"password\": \"$PASSWORD\"
}"

curl -X POST -d "$data" -H 'Content-Type: application/json' $HS/_matrix/client/r0/login
