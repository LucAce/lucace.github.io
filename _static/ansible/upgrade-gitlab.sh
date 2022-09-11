#!/bin/bash

ANSIBLE_HOME='/srv/ansible'

ansible-playbook \
    -i ${ANSIBLE_HOME}/inventory/hosts.yml \
    ${ANSIBLE_HOME}/playbooks/upgrade-gitlab.yml
