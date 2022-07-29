# Filezilla add user

This Powershell script can add a new user to Filezilla-server
- use filezilla-crypt to salt and hash password
- create a basic folder structure for the created user
- add entry to users.xml
- tell filezilla-server to reload the changed configuration

## Prerequisites

Filezilla-server running on windows

## Compatibility
 Tested with Filezilla-server v1.5.0