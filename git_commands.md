```cd fra-controlling-airflow``` 

in order to see the branches already exist there
```git branch```

in order to switch to the main branch
```
git checkout main
```

git status

in order to save the changes
```
git stash
```

git pull



to make a new branch

```
git checkout -b delete_matomo_connection
```


in order to just add a dag named matomo_connection_test.py
```
git add dags/matomo_connection_test.py
```
```
git status
```
```
git commit -m "Delete matomo connection"

```
```
git push origin delete_matomo_connection


```
