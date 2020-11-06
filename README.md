# osrf_jenkins_agent

Chef configuration for OSRF build farm agents.

## Local testing

Test dependencies

* Chef Development Kit
* VirtualBox
* Vagrant

With the above installed, running `kitchen converge` will spin up Ubuntu 16.04 and 18.04 virtual machines and try to run this cookbook.

### Run with chef-solo

Download the dependencies using `berks`:

```bash
berks vendor berks-vendor-cookbooks
```

`chef-solo` will find the berks cookbooks donwloaded since the path is in `solo.rb`. To run `chef-solo` execute:

```bash
sudo chef-solo -c solo.rb -j solo.d/default.json
```

For testing:

```bash
sudo chef-solo -Etest -c solo.rb -j solo.d/default.json
```
