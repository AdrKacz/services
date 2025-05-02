# services
Run and manage services on your local computer. Made by developers for developers.

# Test
Confirm you see logs in `test/logs`

```sh
cd test/
../services.sh list
../services.sh start server-a.sh
../services.sh start server-b.sh
../services.sh list
../services.sh stop server-a.sh
../services.sh stop server-b.sh
../services.sh list
```