ansible-playbook coh_ansible/talabs_coh_ansible_cluster_facts.yml --extra-vars "cohesity_server='172.16.3.101' cohesity_username='admin' cohesity_password='TechAccel1!' cohesity_validate_certs='false'"
cat coh_ansible//cohesity_facts.json

