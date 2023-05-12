#!/bin/bash
#
# Start in nfs-server with:
# wget -N https://files.techaccelerator.com/cohesity/public/scripts/ansible/talabs_coh_ansible_setup.sh
# sh ./talabs_coh_ansible_setup.sh
#
# Update all linux packages if required
# yum -y update
# 
#
# Install Python3 required by pip3 and Ansible
#
yum install python3 -y
#
# Upgrade pip3 to latest
#
pip3 install pip --upgrade
#
# Install ansible via pip3
#
pip3 install ansible
#
# Install Cohesity Ansible module
#
ansible-galaxy collection install cohesity.dataprotect
#
# Install Cohesity SDK
#
pip3 install cohesity-management-sdk
#
# Get a sample Ansible playbook to start a protection group job
#
mkdir -p coh_ansible
#
cd coh_ansible
#
wget -N https://github.com/Cohesity-Academy/labscripts/blob/main/AA/Ansible/talabs_coh_ansible_start_pg.yml
wget -N https://github.com/Cohesity-Academy/labscripts/blob/main/AA/Ansible/talabs_coh_ansible_start_pg.sh
#
# Get a sample Ansible playbook to gather Cohesity cluster facts
wget -N https://github.com/Cohesity-Academy/labscripts/blob/main/AA/Ansible/talabs_coh_ansible_cluster_facts.yml
wget -N https://github.com/Cohesity-Academy/labscripts/blob/main/AA/Ansible/talabs_coh_ansible_cluster_facts.sh
#
# Run the sample protection group job for the predefined Virtual protection group on cohesity-a VE cluster 
#
#ansible-playbook ./talabs_coh_ansible_start_pg.yml --extra-vars "cohesity_server='172.16.3.101' cohesity_username='admin' cohesity_password='TechAccel1!' cohesity_validate_certs='false'"
#
#ansible-playbook ./talabs_coh_ansible_cluster_facts.yml --extra-vars "cohesity_server='172.16.3.101' cohesity_username='admin' cohesity_password='TechAccel1!' cohesity_validate_certs='false'"
#
# Read the Cohesity Facts .json file
#
# cat cohesity_facts.json
#
#

