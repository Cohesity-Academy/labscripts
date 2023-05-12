ansible-playbook coh_ansible/coh_ansible_cluster_facts.yml --extra-vars "cohesity_server='192.168.1.100' cohesity_username='admin' cohesity_password='cohesity123' cohesity_validate_certs='false'"
cat coh_ansible//cohesity_facts.json

