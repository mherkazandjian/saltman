import os
import sys
import yaml
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.backends import default_backend

class Provisioner:
    def __init__(self, conf_path):
        self.conf_path = conf_path

    def provision_files(self):
        """
        Provision the files for all the clusters
        clusters:
          clusterxxx:
            files:
              file1: |
                content of the file
              file2: |
                content of the file
          clusteryyy:
            ...
        """
        with open(self.conf_path, 'r') as fobj:
            conf = yaml.safe_load(fobj.read())

        print(f'provision the files of the clusters')
        for cluster_name, cluster_conf in conf['clusters'].items():
            print(f'\tprovision files for cluster {cluster_name}')
            cluster_workdir = os.path.expanduser(cluster_conf.get('workdir'))

            if not os.path.exists(cluster_workdir):
                print(f'\t\tcreate workdir for cluster {cluster_name}')
                os.makedirs(cluster_workdir)
                print(f'\t\t\tdone')

            if cluster_files := cluster_conf.get('files'):
                print(f'\t\t\twrite files for cluster {cluster_name}')
                for file_name, file_content in cluster_files.items():
                    print(f'\t\t\t\twrite file {file_name}')
                    file_path = os.path.expanduser(os.path.join(cluster_workdir, file_name))
                    # if the parent directory does not exist create it
                    if not os.path.exists(os.path.dirname(file_path)):
                        os.makedirs(os.path.dirname(file_path))
                    with open(file_path, 'w') as fobj:
                        fobj.write(file_content)
                    print('\t\t\t\t  done')

    def provision_docker_compose_file(self):
        """
        Provision the docker compose configuration
        """
        with open(self.conf_path, 'r') as fobj:
            conf = yaml.safe_load(fobj.read())

        for cluster_name, cluster_conf in conf['clusters'].items():
            print(f'provision the docker compose configuration file for cluster {cluster_name}')
            cluster_workdir = os.path.expanduser(cluster_conf.get('workdir'))
            docker_compose_fpath = os.path.expanduser(
                os.path.join(cluster_workdir, 'docker-compose.yml'))
            print(f'\tprovision {docker_compose_fpath}')
            with open(docker_compose_fpath, 'w') as fobj:
                fobj.write(yaml.dump(cluster_conf['docker_compose']))
            print('\t  done')

    def provision_and_check_docker_compose_volume_dirs(self):
        """
        check the volumes section of the docker compose file and check that the host
        directories exist and if they do not, create them. The following is done
        for each service
          for each volume in the volumes section
              check if the host directory exists
              if it does not, create it
        """
        with open(self.conf_path, 'r') as fobj:
            conf = yaml.safe_load(fobj.read())

        print(f'check and provision the host volume directories if they do not exist')
        for cluster_name, cluster_conf in conf['clusters'].items():
            docker_compose_conf = cluster_conf['docker_compose']

            # find the list of env variables in the files/docker_compose_dot_env section
            # that is a key=value pair with one such pair per line
            docker_compose_dot_env = cluster_conf.get('files', {}).get('docker_compose_dot_env')
            env_vars = {}
            if docker_compose_dot_env:
                for line in docker_compose_dot_env.split('\n'):
                    if line.strip() and '=' in line:
                        key, value = line.split('=', 1)
                        env_vars[key.strip()] = value.strip()

            # by default add the value of ${HOME} to the env_vars
            env_vars['HOME'] = os.path.expanduser('~')

            for _, service_conf in docker_compose_conf['services'].items():
                if volumes := service_conf.get('volumes'):
                    for volume in volumes:
                        # check if the host directory exists
                        host_dir = volume.split(':')[0]

                        # check of the host_dir contains an env variable anywhere
                        # if it does, replace it with the value of the env variable
                        for key, value in env_vars.items():
                            if f'${{{key}}}' in host_dir:
                                host_dir = host_dir.replace(f'${{{key}}}', value)

                        host_dir = os.path.expanduser(host_dir)

                        if not os.path.exists(host_dir):
                            print(f'\tthe directory {host_dir} does not exist, create it')
                            os.makedirs(host_dir)
                            print(f'\t\tdone')
                        else:
                            print(f'\t{host_dir} already exists')


def provision_config(conf_path):

    provisioner = Provisioner(conf_path)

    provisioner.provision_files()

    provisioner.provision_docker_compose_file()

    provisioner.provision_and_check_docker_compose_volume_dirs()







#        # provision the ssh configuration file
#        #
#        print(f'\tprovisioning cluster {cluster_name} ssh configuration')
#        ssh_config_fpath = os.path.expanduser(
#            os.path.join(cluster_workdir, 'ssh_config'))
#        docker_compose_conf = cluster_conf['docker_compose']
#        with open(ssh_config_fpath, 'w') as fobj:
#            fobj.write('Host *\n')
#            fobj.write('    StrictHostKeyChecking no\n')
#            fobj.write('    UserKnownHostsFile /dev/null\n')
#            fobj.write('\n\n')
#
#            for _, service_conf in docker_compose_conf['services'].items():
#                ports = service_conf['ports']
#                src, dst = ports[0].split(':')
#                hostname = service_conf.get('hostname')
#                if hostname and '.' in hostname:
#                    hostname = hostname.split('.')[0]
#                proxy_host = cluster_conf['proxy_host']
#                user = cluster_conf['admin_user']
#                ssh_identity_file = os.path.join(cluster_workdir, cluster_conf['admin_key_name'])
#                if dst == '22':
#                    fobj.write(f'Host {hostname}\n')
#                    fobj.write(f'    Hostname {proxy_host}\n')
#                    fobj.write(f'    User {user}\n')
#                    fobj.write(f'    Port {src}\n')
#                    fobj.write(f'    IdentityFile {ssh_identity_file}\n')
#                    fobj.write('\n\n')
#
#        #
#        # create the pub and private keys
#        #
#        print(f'\tprovisioning cluster {cluster_name} pub/priv ssh keys')
#
#        private_key = ed25519.Ed25519PrivateKey.generate()
#        public_key = private_key.public_key()
#        public_key_comment = b'admin key host'
#
#        # define file names for the keys
#        key_name = cluster_conf['admin_key_name']
#        private_key_path = os.path.expanduser(os.path.join(cluster_workdir, key_name))
#        public_key_fpath = private_key_path + '.pub'
#
#        # serialize the private key to PEM format
#        with open(private_key_path, "wb") as fobj:
#            fobj.write(private_key.private_bytes(
#                encoding=serialization.Encoding.PEM,
#                format=serialization.PrivateFormat.OpenSSH,
#                encryption_algorithm=serialization.NoEncryption()
#            ))
#        os.chmod(private_key_path, 0o600)
#
#        # serialize the public key to OpenSSH format
#        with open(public_key_fpath, "wb") as fobj:
#            content = public_key.public_bytes(
#                encoding=serialization.Encoding.OpenSSH,
#                format=serialization.PublicFormat.OpenSSH)
#            content += b' ' + public_key_comment + b'\n'
#            fobj.write(content)
#        print('  done')

provision_config(sys.argv[1])

print('done')
