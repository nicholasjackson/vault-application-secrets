---
id: authentication
title: Authenticating with Vault
sidebar_label: Authentication
---

When we looked at policy you saw how you can obtain a Vault token using the command `vault token create`,
while this is convenient for testing it is impractical for your applications to authenticate to Vault.

The most secure process is that your applications exchanges a piece of information that can identify it
for a Vault token. Examples of this type of information includes a signed X509 certificate that has the 
identity encoded, a signed JWT, or cloud meta data.

For simplicity, this example is going to use JWT, when you started this demo environment, the file `/jwt.token`
contains a valid JWT that was created when this application started.

You can see this token by running the following command

```shell
cat ./jwt.token
```

This will only show you the 3 parts of the jwt `header`, `body`, `signature`, the header and the body consisting of base64 encoded json.

```shell
eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.
eyJhdWQiOiJ2YXVsdCIsImV4cCI6IjIwMjMtMDQtMThUMTU6Mjk6NTEuOTU5ODQwMTM2WiIsImlhdCI6MTY1MDI5NTc5MSwiaXNzIjoiRXhhbXBsZSBBcHAiLCJqdGkiOjk1OTg0MDgyNywibmJmIjoxNjUwMjk1NzkxLCJzdWIiOiJhcGkifQ.
nTL_vXQ33ie3IhoPTco3Df4lizlfvEL6idWIGNl9aGqWrGAjrSxc8HxiYqrV1eOv3dYAUzzPQAm_87PrMfLwcguAbGvXIiRgtseIf_8xYdxG2do-Xk1ITVUFJr2URS4OEP6vr1I6JiWfzW8CP2ssu9QKawZj9DAg27gv2eIE3RU3Xbobonevg2cNSfdD6LlTsQpmvW6GAy4aP3yokhhBaWf4TnVH-X4-_j7WiDWgXSS4t7CbS_V3wFrLNRVyO_uTHUTQNKDVsgYoh758cWXXe0bwKjQMWc7Ve0xLZk46RNPzAJkyFyytwpuppN6kzSnn7mmOEYUuFsRWLxSq6nnaWwaoVqJCmYlo3ZuzlCzv0xk0QuYMtr4V4BLwmTA98OkBsqLhl6B-VGHjPfULVJMNNhzUEJeUOmIMahMIjeQNPYpxtxLmlIf17fNRknr9xvyWFZMvpGea2uBxfvu6fCxOazd2IE_YKNEYISBrs7d45aW7TVydqkeu-vTqJFEKKoJfoIrhwhD-qUHL-89zUR3LTIi8C9vj4dKDx9uy150esVx_8JLGWTP5sgUADp4fkRtLRhGT7NLOOuV0RZh2qsxPmkaGxuQJmgqnEvgwFXevADRBytv0e9pJLYxzwgN6eQ6ofMWgw-yXodrcW1ZpqgTTemw27QSU2cstp31WIIum9ac
```

To see the actual contents of the jwt you can use the following script that will decode it and print the formatted json.

```shell
  cat /files/jwt.token | jwt-util decode-jwt -
```

<p><Terminal target="jwt-util.container.shipyard.run" shell="/bin/sh" workdir="/files" user="root"/></p>

It will look something like this.

```shell
-------- Header --------
{
  "alg": "RS512",
  "typ": "JWT"
}

---------- Body ---------
{
  "aud": "vault",
  "exp": "2023-04-18T15:29:51.959840136Z",
  "iat": 1650295791,
  "iss": "Example App",
  "jti": 959840827,
  "nbf": 1650295791,
  "sub": "api"
}
```

## Enabling the JWT auth method in Vault

So, how do we use this token to authenticate with Vault, first we need to set up the authentication backend, all Vault authentication methods need
to be enabled, you can do that with the following command.

```shell
vault auth enable jwt
```

You should see output like the following:

```shell
Success! Enabled jwt auth method at: jwt/
```

<p><Terminal target="tools.container.shipyard.run" shell="/bin/bash" workdir="/files" user="root"/></p>

Next you need to configure it, since the validation of a JWT requires checking the signature using the public key part of the key that was used to 
sign the JWT. You can configure Vault with a number of different options such as configuring Vault to use a remote key store, or the option we are 
going to use that is provide the public key in the configuration.

The folder `/files` contains the private key that was used to generate the JWT that you saw earlier, it also contains the public part of this key.
The public part is what Vault will use to validate the signature of the JWT, run the following command to configure it.

```shell
vault write auth/jwt/config \
  jwt_validation_pubkeys="$(cat /files/public.pem)"
```

Next we need to create a role, a role is the thing that maps an authentication to the policy that will be included on the returned token

```
vault write auth/jwt/role/api \
    bound_subject="api" \
    bound_audiences="vault" \
    policies=api \
    user_claim="sub" \
    role_type=jwt \
    ttl=1h
```

<p><Terminal target="tools.container.shipyard.run" shell="/bin/bash" workdir="/files" user="root"/></p>

Full documentation for the configuraion of the JWT auth method and roles can be found in the following documentation:

[https://www.vaultproject.io/api-docs/auth/jwt]([https://www.vaultproject.io/api-docs/auth/jwt)

## Authenticating using JWT

Now the JWT authentication has been configured you can attempt to authenticate using the generated JWT. 

```shell
vault write auth/jwt/login role=api jwt=$(cat /files/jwt.token)
```

Vault will validate the signature of the JWT before checking that the `bound_subject`, `bound_audiences`, that you configured in the role match
the claims stored in the JWT. In addition, Vault will also ensure that the `not before` and `expiry` for the token are valid. If successful you 
should see a response containing a Vault token and the policy attached to it like the following:

```shell
Key                  Value
---                  -----
token                hvs.CAESIIixYCEx6kop-1cgSONf1tlqLLzkSaJ63AWC77zvd4veGh4KHGh2cy5WRWJmWHdPYVNpdUVDQVo3MDJBNDdWWlo
token_accessor       A7SN7xOTuUAplqeKUhsj5FXt
token_duration       1h
token_renewable      true
token_policies       ["api" "default"]
identity_policies    []
policies             ["api" "default"]
token_meta_role      api
```

<p><Terminal target="tools.container.shipyard.run" shell="/bin/bash" workdir="/files" user="root"/></p>

Now all of that is configured, we can put all these pieces together and use Vault Agent to automatically authenticate and generate a configuration file
for our example application.