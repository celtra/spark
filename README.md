Sparkie - The Simple Spark Cluster EC2 Manager
==============================================

Requirements
------------
Peace of mind

Installation
------------
- Checkout the repo (`git clone git@github.com:celtra/sparkie.git`)
- Copy `stacker/config/config.yml.dist` to `stacker/config/config.yml`
- Edit `stacker/config/config.yml`
- Create the stack with `stacker aws create`
- Login to EC2 Console and update your driver security group (most likely gateway)
  and add your sparkie-Master and sparkie-Slave groups in it.
  If you **fail** this step, you will see cluster fine, but you won't be able to
  run any jobs.

TODO
----

- Update driver securityGroup automatically.
