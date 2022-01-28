# RSSH
Execute multiple tasks on multiple hosts at the same time.

## How ?

RSSH uses sshpass (called here gibbley) to run ssh sessions non-interactively, It will then executes tasks in a yaml file

## Usage

```bash
user@centos#./remote.sh rhot.ini --verbose
```
