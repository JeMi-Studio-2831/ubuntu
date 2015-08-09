#!/bin/bash -eux

# CM and CM_VERSION variables should be set inside of the Packer template:
#
# Values for CM can be:
#   'nocm'               -- build a box without a configuration management tool
#   'ansible'            -- build a box with Ansible
#   'chef'               -- build a box with Chef
#   'chefdk'             -- build a box with Chef Development Kit
#   'salt'               -- build a box with Salt
#   'puppet'             -- build a box with Puppet
#   'puppet_collections' -- build a box with Puppet Collections
#
# Values for CM_VERSION can be (when CM is ansible|chef|chefdk|salt|puppet|puppet_collections):
#   'x.y.z'              -- build a box with version x.y.z of Chef
#   'x.y'                -- build a box with version x.y of Salt
#   'x.y.z-apuppetlabsb' -- build a box with package version of Puppet
#   'latest'             -- build a box with the latest version
#
# Set CM_VERSION to 'latest' if unset because it can be problematic
# to set variables in pairs with Packer (and Packer does not support
# multi-value variables).
CM_VERSION=${CM_VERSION:-latest}
SSH_USER=${SSH_USERNAME:-vagrant}

#
# Provisioner installs.
#

install_chef()
{
    echo "==> Installing Chef"
    if [[ ${CM_VERSION} == 'latest' ]]; then
        echo "Installing latest Chef version"
        curl -Lk https://www.getchef.com/chef/install.sh | bash
    else
        echo "Installing Chef version ${CM_VERSION}"
        curl -Lk https://www.getchef.com/chef/install.sh | bash -s -- -v $CM_VERSION
    fi
}

install_chef_dk()
{
    echo "==> Installing Chef Development Kit"
    if [[ ${CM_VERSION:-} == 'latest' ]]; then
        echo "==> Installing latest Chef Development Kit version"
        curl -Lk https://www.getchef.com/chef/install.sh | sh -s -- -P chefdk
    else
        echo "==> Installing Chef Development Kit ${CM_VERSION}"
        curl -Lk https://www.getchef.com/chef/install.sh | sh -s -- -P chefdk -v ${CM_VERSION}
    fi

    echo "==> Adding Chef Development Kit and Ruby to PATH"
    echo 'eval "$(chef shell-init bash)"' >> /home/${SSH_USER}/.bash_profile
    chown vagrant /home/${SSH_USER}/.bash_profile
}

install_salt()
{
    echo "==> Installing Salt"
    if [[ ${CM_VERSION:-} == 'latest' ]]; then
        echo "Installing latest Salt version"
        wget -O - http://bootstrap.saltstack.org | sudo sh
    else
        echo "Installing Salt version $CM_VERSION"
        curl -L http://bootstrap.saltstack.org | sudo sh -s -- git $CM_VERSION
    fi
}

install_puppet()
{
    echo "==> Installing Puppet"
    DEB_NAME=puppetlabs-release-$(/usr/bin/lsb_release -cs).deb
    wget http://apt.puppetlabs.com/${DEB_NAME}
    dpkg -i ${DEB_NAME}
    apt-get update
    if [[ ${CM_VERSION:-} == 'latest' ]]; then
      echo "Installing latest Puppet version"
      apt-get install -y puppet
    else
      echo "Installing Puppet version $CM_VERSION"
      apt-get install -y puppet-common=$CM_VERSION puppet=$CM_VERSION
    fi
    rm -f ${DEB_NAME}
}

install_ansible()
{
    echo "==> Installing Ansible"
    if [[ ${CM_VERSION} == 'latest' ]]; then
        echo "Installing latest Ansible version"
        # assuming 14.04; if older need python-software-properties
        apt-get install -y software-properties-common
        apt-add-repository -y ppa:ansible/ansible
        apt-get update
    else
        echo "Installing Ansibles stable version"
    fi
    apt-get install -y ansible
}

install_puppet_collections()
{
    echo "==> Installing Puppet Collections ${CM_PC_VERSION}"
    DEB_RELEASE=$(/usr/bin/lsb_release -cs)
    DEB_NAME="puppetlabs-release-${CM_PC_VERSION}-${DEB_RELEASE}.deb"
    wget http://apt.puppetlabs.com/${DEB_NAME}
    dpkg -i ${DEB_NAME}
    apt-get update
    if [[ ${CM_VERSION:-} == 'latest' ]]; then
      echo "==> Installing latest puppet-agent version"
      apt-get install -y puppet-agent
    else
      echo "==> Installing puppet-agent version $CM_VERSION"
      apt-get install -y puppet-agent=$CM_VERSION$DEB_RELEASE
    fi

    rm -f ${DEB_NAME}
}

#
# Main script
#

case "${CM}" in
  'ansible')
    install_ansible
    ;;

  'chef')
    install_chef
    ;;

  'chefdk')
    install_chef_dk
    ;;

  'salt')
    install_salt
    ;;

  'puppet')
    install_puppet
    ;;

  'puppet_collections')
    install_puppet_collections
    ;;

  *)
    echo "==> Building box without baking in a configuration management tool"
    ;;
esac
