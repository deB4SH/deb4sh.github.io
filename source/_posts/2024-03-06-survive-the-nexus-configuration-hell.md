---
title: DevOpsStory - Survive the Nexus Configuration-Hell
date: 2024-03-06 00:00 
comments: false 
tags:
- terraform
- sonatype nexus
- nexus
- tf
- devops
---

Hi all,
I wanted to move all my artifacts back into my homelab to be able to run it airgapped. 
To reduce the overhead of running multiple services to achieve this goal I've comitted myself on running the sonatype nexus repository manager. Through their broad community support multiple package types are supported by one solution. To survive the administration configuration hell of the repository manager and store a configuration as code within my git, I opted towards writing multiple terraform modules to configure my nexus. The following blog post shall give you a broad overview how I approached the issue and explain how to use my modules for this specific usecase.

<img src="https://github.com/deB4SH/deb4sh.github.io/blob/main/source/_posts/2024-03-06-survive-the-nexus-configuration-hell/header_cropped.jpeg?raw=true" alt="logo" width="500" height="auto">


**Let's survive the configuration hell!**
Nexus provides an [integration api](https://help.sonatype.com/en/rest-and-integration-api.html) for scripted setups which is reachable under `${*YOUR_NEXUS_URL*}/service/rest`.
A swagger documentation is available under `${*YOUR_NEXUS_URL*}/service/rest/swagger.json`. 

Happily enough [amartin](https://registry.terraform.io/namespaces/amartingarcia) provides a [nexus provider](https://registry.terraform.io/modules/terraform-nexus-modules/repository/nexus/latest) for configuring nexus via terraform including a good documentation how to work with this provider.

> To store credentials generated within the module I'll use the bitwarden provider to access my vault and store them there accordingly. 
> There is a good documentation and well written provider available under the following [link](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs)


As first step lets configure all used providers in this blog post within the `main.tf`.
We are using the nexus provider, a random provider for password generation and as already mention within the note a bitwarden provider to store the generated passwords.

```terraform
terraform {
  required_providers {
    nexus = {
      source = "datadrivers/nexus"
      version = "2.1.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.6.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = ">= 0.7.0"
    }
  }
}
```

Following the declaration of all required providers is the instanciation of these with the relevant variables to configure them accordingly.

> This guide references the nexus directly within a local network. There is no trusted certificate available for nexus at this point. If you are planning to run this approach against a publically available nexus please configure the insecure flag within the nexus provider accordingly.

```terraform
provider "random" {
  
}

provider "nexus" {
  insecure = true
  username = var.nexus.username
  password = var.nexus.password
  url      = var.nexus.url
}

provider "bitwarden" {
  email           = var.bitwarden.email
  master_password = var.bitwarden.master_password
  client_id       = var.bitwarden.client_id
  client_secret   = var.bitwarden.client_secret
  server          = var.bitwarden.server
}
```

To externalize all sensetive credentials it is advised to create a specific tfvars for each environment. The general `variables.tf` which follows the shown example may look like the following block.

```terraform
variable "nexus" {
  type = object({
    username = string
    password = string
    url = string
  })
  sensitive = true
}

variable "bitwarden" {
  type = object({
    email = string
    master_password = string
    server = string
    client_id = string
    client_secret = string
  })
  sensitive = true
}
```

An according `development.tfvars` may look like.

```terraform
nexus={
    username="local-admin"
    password="awesome#Super.Password!6576"
    url="https://nexus.local.lan"
}

bitwarden={
    email="svc.user.nexus@local.lan"
    master_password="my#Awesome.Master!Password"
    client_id="user.1233-123123-123123-123"
    client_secret="1K{....}}zB"
    server="https://keyvault.local.lan"
}
```

With these base steps done you are now good to go for the implementation of your configuration. 

So lets start with implementing a hosted docker repository, shall we?

Create a new directory called `modules` in the root of your project and create a new file called `providers.tf` inside it.
It would also be possible to reuse the provider from your base terraform code but if you want to externalize the module it may be usefule to also externalize the providers.

Within the `providers.tf` file add the following content:

```terraform
terraform {
  required_providers {
    nexus = {
      source = "datadrivers/nexus"
      version = "2.1.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.6.0"
    }
  }
}
```

As next step we need to create a `variables.tf` to configure our required variables for this setup.
Each registry requires a name, a port and an isOnline flag. 
A blobStoreName is required to configure final storage environment that is used on your host.

```terraform
variable "name" {
    type = string
    description = "Name of the docker registry"

}

variable "isOnline" {
    type = bool
    default = true
    description = "Toggle switch to enable or disable online usage of this repository"

}

variable "port" {
    type = string
    description = "Port to announce service on"

}

variable "blobStoreName" {
    type = string
    default = "default"
    description = "Blob Storage wihin nexus to use"

}
```

After a successful deployment we want to extract some configured values like the username of the read user and required password.
For this please add and configure the `outputs.tf` file:

```terraform
output "pull-user" {
    value = nexus_security_user.pull-user.userid
}

output "pull-user-pw" {
    value = random_password.pull-user-password.result
}

output "push-user" {
    value = nexus_security_user.push-user.userid
}

output "push-user-pw" {
    value = random_password.push-user-password.result
}
```

With everything done configuration-wise it is now required to configure the actual repository that hosts the files.
The following listing creates a hosted docker repository in your nexus environment with the configuration you've set in your variables. 
If you like you could easily extend the configuration with the currently pre-defined values in this registry.


```terraform
resource "nexus_repository_docker_hosted" "registry" {
  name   = "${var.name}"
  online = var.isOnline

  docker {
    force_basic_auth = false
    v1_enabled       = false
    http_port        = "${var.port}"
  }

  storage {
    blob_store_name                = "${var.blobStoreName}"
    strict_content_type_validation = true
    write_policy                   = "ALLOW"
  }
}
```

To access this newly created registry we need to create as last step new accounts. This can also be done via terraform. 
The following code-blocks create random passwords for a user designated to access the registry via read only rules and one password for a user with write permission.

```terraform
resource "random_password" "pull-user-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "push-user-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "nexus_security_user" "pull-user" {
  userid     = "docker-${var.name}-pull"
  firstname  = "Docker Pull"
  lastname   = "${var.name}"
  email      = "svc.docker.${var.name}-pull@local.lan"
  password   = random_password.pull-user-password.result
  roles      = ["docker-${var.name}-pull-role"]
  status     = "active"
  depends_on = [nexus_repository_docker_hosted.registry, nexus_security_role.security-role-pull]
}

resource "nexus_security_user" "push-user" {
  userid     = "docker-${var.name}-push"
  firstname  = "Docker Push"
  lastname   = "${var.name}"
  email      = "svc.docker.${var.name}-push@local.lan"
  password   = random_password.push-user-password.result
  roles      = ["docker-${var.name}-push-role"]
  status     = "active"
  depends_on = [nexus_repository_docker_hosted.registry, nexus_security_role.security-role-push]
}
```
As you may have seen these users reference their specific security roles that we are currently not providing.
As last step we need to set those up.

```terraform
resource "nexus_security_role" "security-role-pull" {
  description = "Docker Pull Role for ${var.name}"
  name        = "docker-${var.name}-pull-role"
  privileges = [
    "nx-repository-view-docker-${var.name}-read",
    "nx-repository-view-docker-${var.name}-browse",
  ]
  roleid = "docker-${var.name}-pull-role"
  depends_on = [nexus_repository_docker_hosted.registry]
}

resource "nexus_security_role" "security-role-push" {
  description = "Docker Pull Role for ${var.name}"
  name        = "docker-${var.name}-push-role"
  privileges = [
    "nx-repository-view-docker-${var.name}-read",
    "nx-repository-view-docker-${var.name}-browse",
    "nx-repository-view-docker-${var.name}-add",
  ]
  roleid = "docker-${var.name}-push-role"
  depends_on = [nexus_repository_docker_hosted.registry]
}
```

When everything works together you should be able to create repositories easily with close to zero configuration overhead due to the flexibility of terraform.
This setup allows you to create multiple repositories at once.
For example if you are using the newly created module in your main terraform structure you could easily wrap it with a for_each call.

```terraform
module "docker-registry" {
  source = "github.com/deB4SH/terraform-nexus-docker-module?ref=1.0.0"

  for_each = { for dr in var.docker_repository : dr.name => dr}

  name = each.key
  isOnline = each.value.isOnline
  port = each.value.port
  blobStoreName = each.value.blobStoreName
}
```

Based on the given information in the following block this will create two repositories with dedicated read and write users with close nearly no configuration from your end.

```
docker_repository=[
    {
        name="test1"
        isOnline=true
        port="61000"
        blobStoreName="default"
    },
    {
        name="test2"
        isOnline=true
        port="61001"
        blobStoreName="default"
    }
]
```

I hope this guide will help you to get an introduction towards managing your infrastructure with terraform. 

##### Sources

* [Terraform Provider by amartingarcia](https://registry.terraform.io/modules/terraform-nexus-modules/repository/nexus/latest)
* [Terraform Nexus Hosted Docker Module](https://github.com/deB4SH/terraform-nexus-docker-module)
* [Terraform Nexus Hosted APT Module](https://github.com/deB4SH/terraform-nexus-apt-module)