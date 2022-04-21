---
id: index
title: Application secrets with HashiCorp Vault
sidebar_label: Intro
---

## What is Vault
Vault is a tool for managing secrets and protecting sensitive data, it allows you to store static secrets like:

* API Keys or passwords
* Dynamic secrets like database credentials

In addition you can use Vault to dynamically generate credentials for cloud services like AWS and even use it for 
general purpose cryptographic purposes like encrypting or hashing data.

To access the secrets in Vault you first need to authenticate to it, you do this using an Auth method. For example
Vault has a JWT auth method, the JWT auth method can be configured to allow you access to certain secrets based on the 
claims in your JWT.

Let's quickly look at Vaults concepts before seeing a short demo.

## Introduction to Vault

Vault is built around three main concepts:

* Secrets
* Authentication
* Policy

In this section, we review how these concepts work in Vault.

![](https://www.datocms-assets.com/2885/1576778376-vault-workflow-illustration-policy.png)

### Secrets

You can have static secrets like an API key or a credit card number or dynamic secrets like auto-generated cloud or database credentials. Vault generates dynamic secrets on-demand, while you receive static secrets already pre-defined.

With static secrets, you must create and manage the lifecycle of the secret. For example, you could store an email account password in Vault but you need to ensure that it is periodically changed.

With dynamic secrets, you delegate the responsibility to Vault for creating and managing the lifecycle of a secret. For example, you give Vault the root credentials for your PostgreSQL database, granting it access to create credentials on your behalf. When you want to log into the database, you ask Vault for credentials. Vault makes a connection to the database and generates a set of restricted access credentials. These are not permanent but leased. Vault manages the lifecycle, automatically rotating the password and revoking the access when they are no longer required.

One of the critical features of defense in depth is rotating credentials. In the event of a breach, credentials with a strict time to live (TTL) can dramatically reduce the blast radius.

![](https://www.datocms-assets.com/2885/1576778435-vault-db.png)

### Authentication

To access secrets in Vault, you need to be authenticated; authentication is in the form of pluggable backends. For example, you can use a Kubernetes Service Account token to authenticate to Vault. For human access, you could use something like GitHub tokens. In both of these instances, Vault does not directly store the credentials; instead, it uses a trusted third party to validate the credentials.  With Kubernetes Service Account tokens, when an application attempts to authenticate with Vault, Vault makes a call to the Kubernetes API to ensure the validity of the token. If the token is valid, it returns an internally managed Vault Token, used by the application for future requests.

![](https://www.datocms-assets.com/2885/1576778470-vault-k8s-auth.png)

### Policy

Policy ties together secrets and authentication by defining which secrets and what administrative operations an authenticated user can perform. For example, an operator may have a policy which allows them to configure secrets for a PostgreSQL database, but not generate credentials. An application may have permission to create credentials but not configure the backend. Vault policy allows you correctly separate responsibility based on role.

```ruby
# policy allowing creation and configuration of databases and roles
path "database/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"] 
}

path "database/config/*" {
  capabilities = ["create", "read", "update", "delete", "list"] 
}

# policy allowing credentials for the wizard database to be created 
path "database/creds/wizard" {
  capabilities = ["read"] 
}
```

Now we understand the baseics let's see how this works