# Vault Application Secrets

## Setup

1. Install Docker
1. Install Shipyard 

### Quick Install (Linux, Mac)

```shell
curl https://shipyard.run/install | bash
```

### Homebrew install

```shell
brew install shipyard-run/homebrew-repo/shipyard
```

### Debian

```shell
echo "deb [trusted=yes] https://apt.fury.io/shipyard-run/ /" | sudo tee -a /etc/apt/sources.list.d/fury.list
sudo apt-get update
```

### RPM

```shell
echo "[fury] 
name=Gemfury Private Repo 
baseurl=https://yum.fury.io/shipyard-run/ 
enabled=1 
gpgcheck=0" | sudo tee -a /etc/yum/repos.d/fury.repo
```

## Run Demo Environment

```shell
shipyard run ./shipyard
```

## Stop Demo Environment

```shell
shipyard destroy
```