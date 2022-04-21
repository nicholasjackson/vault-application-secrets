---
id: vault_agent
title: Generation Application configuration using Vault Agent
sidebar_label: Vault Agent
---

To provide secrets to our application we need to do two things:
1. Authenticate to Vault to obtain a token that can access secrets
1. Prepare a config file for the application that contains those secrets

The example application requires a config file that is JSON based, it looks like this

```json
{
  "api_key": "default",
  "db_connection": "default",
  "timeout": "5s"
}
```

To inject our api key from Vault's `kv` secrets engine that is stored at the path `secret/api` we first need 
to obtain the secret and then generate the configuration file. 

To manage this process and also to manage the authentication Vault has a tool called `Vault Agent`, you can run
Vault Agent as a background process and it manages the authentication with the Vault server and enables you
to create templates for your configuration file that Vault Agent will automatically retrieve and inject secrets for.

![](https://mktg-content-api-hashicorp.vercel.app/api/assets?product=vault&version=refs%2Fheads%2Frelease%2F1.10.x&asset=website%2Fpublic%2F%2Fimg%2Fdiagram-vault-agent.png)

We can use Vault agent with the JWT authentication that we configured in the previous steps to automatically generate
our configuration. Let's see how we configure this.

## Configuring Vault Agent for Authentication

```javascript
auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      path = "/jwt.token"
      role = "api"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}
```

Write this config file by executing the following command in the terminal

```javascript
cat << EOF > /agent_config.hcl
auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      path = "/jwt.token"
      role = "api"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}
EOF
```

To authenticate we need a JWT token, generally your will provision the JWT for the application when it is provisioned,
to simulate this we can just copy the example JWT that we used earlier.

```shell
cp /files/jwt.token /jwt.token
```

Now let's start Vault agent

```shell
vault agent -config=/agent_config.hcl
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/" user="root"/></p>

You should see output that looks like the following:

```shell
==> Vault agent started! Log data will stream in below:

==> Vault agent configuration:

           Api Address 1: http://127.0.0.1:8100
                     Cgo: disabled
               Log Level: info
                 Version: Vault v1.10.0
             Version Sha: 7738ec5d0d6f5bf94a809ee0f6ff0142cfa525a6

2022-04-21T08:36:56.535Z [INFO]  auth.jwt: jwt auth method created: path=/jwt.token
2022-04-21T08:36:56.536Z [INFO]  template.server: starting template server
2022-04-21T08:36:56.536Z [INFO]  template.server: no templates found
2022-04-21T08:36:56.536Z [INFO]  sink.server: starting sink server
2022-04-21T08:36:56.536Z [INFO]  auth.handler: starting auth handler
2022-04-21T08:36:56.536Z [INFO]  auth.handler: authenticating
2022-04-21T08:36:56.543Z [INFO]  auth.handler: authentication successful, sending token to sinks
2022-04-21T08:36:56.543Z [INFO]  auth.handler: starting renewal process
2022-04-21T08:36:56.546Z [INFO]  auth.handler: renewed auth token
```

Since you configured the listener in the configuration, any request to the Vault server can be
sent to `http://127.0.0.1:8100`, the Vault token that was obtained by the agent when it
authenticated is automatically appended to this request.

Why not try this out, run the following command in the terminal.

```shell
VAULT_ADDR=http://127.0.0.1:8100 vault kv get secret/api
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/" user="root"/></p>

Now you have configured Vault Agent for authentication let's see how you can configure the template feature.

## Configuring the template

Vault agent has a sophisticated template feature that enables you to fetch secrets from Vault and generate
application configuration files.

To fetch the secret api from Vault you can use the `secret` function that is part of [Consul Template](https://github.com/hashicorp/consul-template/blob/master/docs/templating-language.md#secret)

This looks like the following example:

```go
{{ with secret "secret/api" }}
{{ .Data.data.api_key }}
{{ end }}
```

Since our example application requires JSON as output you can embed this function into the json
configuration, which looks like this:

```shell
{
  "api_key": "{{ with secret "secret/api" }}{{ .Data.data.api_key }}{{ end }}",
  "db_connection": "default",
  "timeout": "5s"
}
```

To use a template you first need to write it to a location where Vault Agent can read it.

```shell
cat <<EOF > /config.tmpl
{
  "api_key": "{{ with secret "secret/api" }}{{ .Data.data.api_key }}{{ end }}",
  "db_connection": "default",
  "timeout": "5s"
}
EOF
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/" user="root"/></p>

For Vault agent to process a template you need to add a `template` stanza to the configuration

```javascript
template {
  source      = "/config.tmpl"
  destination = "/config.json"
}
```

Update your Vault agent configuration so that it contains this section

```shell
cat << EOF > /agent_config.hcl
auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      path = "/jwt.token"
      role = "api"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}

template {
  source      = "/config.tmpl"
  destination = "/config.json"
}
EOF
```

You can then restart Vault Agent

```shell
cp /files/jwt.token /jwt.token; \
pkill vault; \
vault agent -config=/agent_config.hcl
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/" user="root"/></p>

Vault Agent should have processed the configuration file and injected the secret, you can see this by running the following
command.

```shell
cat /config.json
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/" user="root"/></p>

## Signaling the application to reload config

Now you have configured Vault Agent to authenticate and to create the config file, the final task is to let the 
application know that the config has been updated.

The example application has been built to respond to a `SIGHUP`, when it receives this signal it will automatically
reload the config from disk.

You can try this out by manually sending a SIGHUP to the example app using the following command.

```shell
kill -s SIGHUP $(cat /echo_config.pid)
```

The example app has an endpoint `/config` that echos the config file it has read, if you make a request to this endpoint
you will see that the application has correctly reloaded the config.


```shell
curl http://localhost:9090/config
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/files" user="root"/></p>

To ensure that the application automatically receives the signal once Consul template is complete you can
add the `command` parameter to the `template` stanza.

```shell
template {
  source      = "/config.tmpl"
  destination = "/config.json"
  command = "kill -s SIGHUP $(cat /echo_config.pid)"
}
```

Let's update the template with this added parameter:

```shell
cat << EOF > /agent_config.hcl
auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      path = "/jwt.token"
      role = "api"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}

template {
  source      = "/config.tmpl"
  destination = "/config.json"
  command = "kill -s SIGHUP $(cat /echo_config.pid)"
}
EOF
```

And restart Vault Agent to update these changes

```shell
cp /files/jwt.token /jwt.token; \
pkill vault; \
vault agent -config=/agent_config.hcl
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/" user="root"/></p>

If you look at the logs for the application you will see it received this command and reloaded
the config that was produced by Vault Agent.

```shell
cat echo_config.log 
```

```shell
2022-04-21T13:31:13.693Z [INFO]  Starting application
2022-04-21T13:31:13.693Z [INFO]  Load config: file=/config.json
2022-04-21T13:32:27.625Z [INFO]  Received SIGHUP
2022-04-21T13:32:27.625Z [INFO]  Load config: file=/config.json
```

<p><Terminal target="app.container.shipyard.run" shell="/bin/bash" workdir="/" user="root"/></p>

## Summary

Quickly summarizing what you have learned in this example.

1. How to store an interact with secrets in Vault
1. How to create policy to control access to secrets
1. How Vault authentication works and how to configure the JWT authentication
1. How to configure Vault Agent to automatically authenticate and create application specific config
