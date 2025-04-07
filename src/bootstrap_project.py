import os
import sys
import yaml
from pathlib import Path
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

        if not conf.get('workdir', None):
            raise ValueError('workdir not defined for cluster and global config')
        else:
            project_workdir = Path(conf['workdir'])

        print(f'provision the files of the clusters')
        for cluster_name, cluster_conf in conf['clusters'].items():
            print(f'\tprovision files for cluster {cluster_name}')
            if not cluster_conf.get('workdir', None):
                cluster_workdir = project_workdir / cluster_name
            else:
                cluster_workdir = Path(cluster_conf['workdir'])
            cluster_workdir = os.path.expanduser(cluster_workdir)

            print(f'\t\tcreate workdir for cluster {cluster_name}')
            print(f'\t\t\t{cluster_workdir}')
            os.makedirs(cluster_workdir, exist_ok=True)
            print(f'\t\tdone')

            if cluster_files := cluster_conf.get('files'):
                print(f'\t\twrite files for cluster {cluster_name}')
                for file_name, file_content in cluster_files.items():
                    file_path = os.path.expanduser(cluster_workdir / Path(file_name))
                    print(f'\t\t\twrite file {file_path}')
                    with open(file_path, 'w') as fobj:
                        fobj.write(file_content)
                    print('\t\t\t\tdone')

        if project_files := conf.get('files'):
            print(f'\tprovision files for the project')
            for file_name, file_content in project_files.items():
                file_path = os.path.expanduser(project_workdir / Path(file_name))
                print(f'\t\twrite file {file_path}')
                # create the directory if it does not exist
                os.makedirs(os.path.dirname(file_path), exist_ok=True)
                with open(file_path, 'w') as fobj:
                    fobj.write(file_content)
                print('\t\t\t  done')

    def provision_docker_compose_file(self):
        """
        Provision the docker compose configuration
        """
        with open(self.conf_path, 'r') as fobj:
            conf = yaml.safe_load(fobj.read())

        if not conf.get('workdir', None):
            raise ValueError('workdir not defined for cluster and global config')
        else:
            project_workdir = Path(conf['workdir'])

        for cluster_name, cluster_conf in conf['clusters'].items():
            print(f'provision the docker compose configuration file for cluster {cluster_name}')
            if not cluster_conf.get('workdir', None):
                cluster_workdir = project_workdir / cluster_name
            else:
                cluster_workdir = Path(cluster_conf['workdir'])
            cluster_workdir = os.path.expanduser(cluster_workdir)

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

        if not conf.get('workdir', None):
            raise ValueError('workdir not defined for cluster and global config')
        else:
            project_workdir = Path(conf['workdir'])

        print(f'check and provision the host volume directories if they do not exist')
        for cluster_name, cluster_conf in conf['clusters'].items():
            print(f'\tperform checks for {cluster_name}')
            if not cluster_conf.get('workdir', None):
                cluster_workdir = project_workdir / cluster_name
            else:
                cluster_workdir = Path(cluster_conf['workdir'])
            cluster_workdir = os.path.expanduser(cluster_workdir)

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
                            print(f'\t\tthe directory {host_dir} does not exist, create it')
                            os.makedirs(host_dir)
                            print(f'\t\t\tdone')
                        else:
                            print(f'\t\t{host_dir} already exists')

    def provision_ssh_config(self):
        """
        Create the ssh configuration file for all the clusters.

        For each cluster for every machine three enteries are created

           - nodex
           - node %02x
           - cluster-name-hostname
        """
        print(f'provision the ssh configuration')

        with open(self.conf_path, 'r') as fobj:
            conf = yaml.safe_load(fobj.read())

        if not conf.get('workdir', None):
            raise ValueError('workdir not defined for cluster and global config')
        else:
            project_workdir = Path(conf['workdir'])

        ssh_config_fpath = os.path.expanduser(
            os.path.join(project_workdir, 'ssh_config'))

        n_hosts = 0
        with open(ssh_config_fpath, 'w') as fobj:
            fobj.write('Host *\n')
            fobj.write('    StrictHostKeyChecking no\n')
            fobj.write('    UserKnownHostsFile /dev/null\n')
            fobj.write('\n\n')

            for cluster_name, cluster_conf in conf['clusters'].items():
                print(f'\tadd ssh aliases for the hosts for cluster {cluster_name}')
                if not cluster_conf.get('workdir', None):
                    cluster_workdir = project_workdir / cluster_name
                else:
                    cluster_workdir = Path(cluster_conf['workdir'])
                cluster_workdir = os.path.expanduser(cluster_workdir)

            ssh_config_fpath = os.path.expanduser(
                os.path.join(cluster_workdir, 'ssh_config'))

            for _, cluster_conf in conf['clusters'].items():
                docker_compose_conf = cluster_conf['docker_compose']

                for _, service_conf in docker_compose_conf['services'].items():
                    ports = service_conf['ports']
                    src, dst = ports[0].split(':')
                    hostname = service_conf.get('hostname')
                    if hostname and '.' in hostname:
                        hostname = hostname.split('.')[0]
                    proxy_host = cluster_conf['proxy_host']
                    user = cluster_conf['admin_user']
                    ssh_identity_file = cluster_workdir / Path(cluster_conf['admin_key_name'])
                    if dst == '22':
                        hostnames = [
                            hostname,
                            f'node{n_hosts:02d}',
                            f'node{n_hosts}',
                            f'{cluster_name}-{hostname}'
                        ]
                        for _hostname in hostnames:
                            print(f'\t\tadd ssh alias for host {_hostname}')
                            fobj.write(f'Host {_hostname}\n')
                            fobj.write(f'    Hostname {proxy_host}\n')
                            fobj.write(f'    User {user}\n')
                            fobj.write(f'    Port {src}\n')
                            fobj.write(f'    IdentityFile {ssh_identity_file}\n')
                            fobj.write('\n\n')
                        n_hosts += 1


    def provision_ssh_keys(self):
        """
        Create the pub and private keys, one key per cluster
        """
        with open(self.conf_path, 'r') as fobj:
            conf = yaml.safe_load(fobj.read())

        if not conf.get('workdir', None):
            raise ValueError('workdir not defined for cluster and global config')
        else:
            project_workdir = Path(conf['workdir'])

        for cluster_name, cluster_conf in conf['clusters'].items():
            print(f'provision the ssh priv/pub keys for cluster {cluster_name}')
            if not cluster_conf.get('workdir', None):
                cluster_workdir = project_workdir / cluster_name
            else:
                cluster_workdir = Path(cluster_conf['workdir'])
            cluster_workdir = os.path.expanduser(cluster_workdir)

            private_key = ed25519.Ed25519PrivateKey.generate()
            public_key = private_key.public_key()
            public_key_comment = b'admin key host'

            # define file names for the keys
            key_name = cluster_conf['admin_key_name']

            # serialize the private key to PEM format
            private_key_path = cluster_workdir / Path(key_name)
            print(f'\tprovision {private_key_path}')
            with open(private_key_path, "wb") as fobj:
                fobj.write(private_key.private_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PrivateFormat.OpenSSH,
                    encryption_algorithm=serialization.NoEncryption()
                ))
            os.chmod(private_key_path, 0o600)

            # serialize the public key to OpenSSH format
            public_key_fpath = private_key_path.with_suffix('.pub')
            print(f'\tprovision {public_key_fpath}')
            with open(public_key_fpath, "wb") as fobj:
                content = public_key.public_bytes(
                    encoding=serialization.Encoding.OpenSSH,
                    format=serialization.PublicFormat.OpenSSH)
                content += b' ' + public_key_comment + b'\n'
                fobj.write(content)


def provision_config(conf_path):

    provisioner = Provisioner(conf_path)

    provisioner.provision_files()

    provisioner.provision_docker_compose_file()

    provisioner.provision_and_check_docker_compose_volume_dirs()

    provisioner.provision_ssh_config()

    provisioner.provision_ssh_keys()


provision_config(sys.argv[1])

print('done')
