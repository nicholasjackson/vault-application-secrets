---
id: static_secrets
title: Adding Static Secrets To an Application
sidebar_label: Static Secrets
---

Let's look at a workflow to add static secrets to our application. Our application uses a config file like the following
example.


```json
{
  "api_key": "abcdefghijklmnopqrstuvwxyz",
  "db_connection": "postgres://admin:mypassword@dbserver:5432/mydb",
  "timeout": "5s"
}
```

This config file is loaded on startup and whenever the application receives a `SIGHUP` signal.

There are two main problems with this approach, both of which we will address in this session, they are `Secrets Sprawl` and `Long Lived High Privilege 
Credentials`.

With `Secret Sprawl` you can end up in a situation where your secrets are technically no longer secret either because everyone knows them or because
you don't actually know where they are. When you combine this with Long Lived High Privilege credentials you have a situation where you can leak 
credentials without knowing you have done so, and those credentials can be used long after the initial exploit. 

We are going to address both of these issues, but first let's look at how you can handle secrets sprawl for static credentials with HashiCorp Vault.

## Storing secrets using the CLI

For simplicity, the first few commands you are going to execute here is going to use the root token, using the root token in any environment other
than an example environment is very rare. The root token should really only be used to setup the initial Vault configuration including user accounts 
that can administer Vault.

To store static secrets you can use the `kv` secrets engine, the `kv` secrets engine can be configured in one of two modes v2, that allows multiple
versions and rollback capability for secrets, and v1 that only retains the most recent stored version of secret. We are going to look at the newer v2
engine.

To store the `api_key` that the example application requires using the Vault CLI you can execute the following command:

```shell
vault kv put secret/api api_key=abcdefg timeout=5s
```

Breaking this down, you are setting the key `api_key` to the value of `abcdefg` and the key `timeout` to the value of `5s`, these keys are going
to be stored at the path `api` in the secrets engine mounted at the path `secret`.

In Vault all secrets engines are mounted at a path, by default the `kv` engine is mounted at the path `secret`, the path that follows this can be 
any valid URI. There is no real rules on how you store your secrets, it really depends on your organizational structure, and application topography.

For example, maybe you have a core services team that is responsible for the `api` you may choose to use the convention of `/<mount point>/<team>/<service>`, 
e.g. `/secret/core/api`.

Vault does not prescribe where your store your secrets other than requiring the mount point to be the first part of the path, however, when we start to look at
policy, you will see how the organization of your secret can dramatically effect the access management.

Why not use the terminal below to try setting the secret in the previous example.    

<Terminal target="tools.container.shipyard.run" shell="/bin/bash" workdir="/files" user="root" />

You should see some output that looks like the following:

```shell
= Secret Path =
secret/data/api

======= Metadata =======
Key                Value
---                -----
created_time       2022-04-17T14:24:41.587508283Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```

At the beginning of this output you will see the `Secret Path`, has a value of `secret/data/api`, you are probably wondering why this path was returned
when you set the path as `secret/api`. This is just a technical detail for the v2 `kv` engine, if you had been using the original v1 engine the path would be
as you set it `secret/api`. The CLI is actually hiding the `data` part of the path for you, had you set the secret using the API directly you would need
to have included the `data` part when using the v2 `kv` engine. An example of this can be seen below:

```shell
curl ${VAULT_ADDR}/v1/secret/data/api \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --data '{"data": {"api_key": "12345678", "timeout": "5s"}}'
```

If you run this in the terminal you will see a json response like below:

```json
{
  "request_id":"8ddd853f-f481-c7a7-472b-5125cf740576",
  "lease_id":"",
  "renewable":false,
  "lease_duration":0,
  "data":{
    "created_time":"2022-04-17T14:52:01.163761054Z",
    "custom_metadata":null,
    "deletion_time":"",
    "destroyed":false,
    "version":2
    },
  "wrap_info":null,
  "warnings":null,
  "auth":null
}
```

Note the `"version": 2`, this is because we have updated the secret, the original version is still accessible so that if necessary this operation could be
rolled back.

## Accessing secrets using the CLI

Let's now see how you can access those secrets using the CLI, the command is quite simple:

```shell
vault kv get secret/api
```

Note that when using the CLI, you do not need to include the path `data`, the CLI automatically manages this for you, if you run the command in the termainal
below.

<Terminal target="tools.container.shipyard.run" shell="/bin/bash" workdir="/files" user="root" />

You should see some output similar to below:

```shell
= Secret Path =
secret/data/api

======= Metadata =======
Key                Value
---                -----
created_time       2022-04-17T14:52:01.163761054Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            2

===== Data =====
Key        Value
---        -----
api_key    12345678
timeout    5s
```

## Accessing different versions of secrets

Since this is the v2 `kv` engine, if you wanted to get the original version of the secret that was stored using the first CLI command you could use the following
command.

```shell
vault kv get secret/api --version=1
```

You should see the previous version returned

```shell
= Secret Path =
secret/data/api

======= Metadata =======
Key                Value
---                -----
created_time       2022-04-17T14:24:41.587508283Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1

===== Data =====
Key        Value
---        -----
api_key    abcdefg
```

## Rolling back secrets

If you would like to roll back to the first version you can use the following command:

```
➜ vault kv rollback --version=1 secret/api
```

```shell
Key                Value
---                -----
created_time       2022-04-18T07:32:39.183844647Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            3
```

Now when you get the secret `api` you will see the original value that you set, also note that the version is now `3`, the reason for this is that
Vault always preserves history, to do this it copies the value from the original version and created a new version.

Let's now see how you can control access to secrets with policy.