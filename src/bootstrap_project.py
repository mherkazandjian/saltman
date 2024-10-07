import os
import sys
import yaml
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.backends import default_backend

def provision_config(conf_path):
    with open(conf_path, 'r') as fobj:
        conf = yaml.safe_load(fobj.read())

    print(f'provisioning the configuration of the clusters')
    for cluster_name, cluster_conf in conf['clusters'].items():
        #
        # provision the defined files
        #
        print(f'\tprovisioning cluster {cluster_name} configuration')
        cluster_workdir = os.path.expanduser(cluster_conf.get('workdir'))
        # check that the workdir exists if not create it
        if not os.path.exists(cluster_workdir):
            print(f'\t\tcreating workdir for cluster {cluster_name}')
            os.makedirs(cluster_workdir)
            print(f'\t\tdone')
        if cluster_files := cluster_conf.get('files'):
            print(f'writing files for cluster {cluster_name}')
            for file_name, file_content in cluster_files.items():
                print(f'writing file {file_name}')
                file_path = os.path.expanduser(os.path.join(cluster_workdir, file_name))
                # if the parent directory does not exist create it
                if not os.path.exists(os.path.dirname(file_path)):
                    os.makedirs(os.path.dirname(file_path))
                with open(file_path, 'w') as fobj:
                    fobj.write(file_content)
                print('  done')

        #
        # provision the docker compose configuration
        #
        print(f'\tprovisioning cluster {cluster_name} docker compose configuration')
        docker_compose_fpath = os.path.expanduser(
            os.path.join(cluster_workdir, 'docker-compose.yml'))
        with open(docker_compose_fpath, 'w') as fobj:
            fobj.write(yaml.dump(cluster_conf['docker_compose']))
        print('  done')

        #
        # provision the ssh configuration file
        #
        print(f'\tprovisioning cluster {cluster_name} ssh configuration')
        ssh_config_fpath = os.path.expanduser(
            os.path.join(cluster_workdir, 'ssh_config'))
        docker_compose_conf = cluster_conf['docker_compose']
        with open(ssh_config_fpath, 'w') as fobj:
            fobj.write('Host *\n')
            fobj.write('    StrictHostKeyChecking no\n')
            fobj.write('    UserKnownHostsFile /dev/null\n')
            fobj.write('\n\n')

            for _, service_conf in docker_compose_conf['services'].items():
                ports = service_conf['ports']
                src, dst = ports[0].split(':')
                hostname = service_conf.get('hostname')
                proxy_host = cluster_conf['proxy_host']
                user = cluster_conf['admin_user']
                ssh_identity_file = os.path.join(cluster_workdir, cluster_conf['admin_key_name'])
                if dst == '22':
                    fobj.write(f'Host {hostname}\n')
                    fobj.write(f'    Hostname {proxy_host}\n')
                    fobj.write(f'    User {user}\n')
                    fobj.write(f'    Port {src}\n')
                    fobj.write(f'    IdentityFile {ssh_identity_file}\n')
                    fobj.write('\n\n')

        #
        # create the pub and private keys
        #
        print(f'\tprovisioning cluster {cluster_name} pub/priv ssh keys')

        private_key = ed25519.Ed25519PrivateKey.generate()
        public_key = private_key.public_key()

        # define file names for the keys
        key_name = cluster_conf['admin_key_name']
        private_key_path = os.path.expanduser(os.path.join(cluster_workdir, key_name))
        public_key_fpath = private_key_path + '.pub'

        # serialize the private key to PEM format
        with open(private_key_path, "wb") as fobj:
            fobj.write(private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            ))
        os.chmod(private_key_path, 0o600)

        # serialize the public key to OpenSSH format
        with open(public_key_fpath, "wb") as fobj:
            fobj.write(public_key.public_bytes(
                encoding=serialization.Encoding.OpenSSH,
                format=serialization.PublicFormat.OpenSSH

            ))
        print('  done')

provision_config(sys.argv[1])

print('done')
