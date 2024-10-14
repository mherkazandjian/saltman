#!/usr/bin/env python3
"""
Helper script that takes container snapshots and updates the docker compose file
"""
import os
import argparse
from argparse import RawTextHelpFormatter
from ruamel.yaml import YAML
from ruamel.yaml import round_trip_dump
from subprocess import Popen, PIPE
import shlex
from multiprocess import Process

def parse_args() -> argparse.Namespace:
    """
    Parse the command line arguments
    """

    parser = argparse.ArgumentParser(
        description=(
            "Modify the content of the docker-compose file\n"
            "\n"
            "usage example\n"
            "\n"
            "    # aaaaaaaaaaa\n"
            "       yed --yaml=/path/to/foo.yml --data-in-from-file=/tmp/foo.txt --target-key=foo:bar:baz\n"
            "       yed --yaml=~/projects/surf/dms-salt-pillar/nodes/frost-yoda/ssl.sls --data-in-from-file ~/certs/frost-yoda_irods_surfsara_nl_cert.cer  --target-key 'ssl:cert'\n"
            "    # bbbbbbbbb\n"
            "       yed --yaml=/path/to/foo.yml --target-key 'ssl:cert' --data-in-from-url 'https://cert-manager.com/customer/foocustomer/ssl?action=download&sslId=42098234format=x509CO'\n"
        ),
        formatter_class=RawTextHelpFormatter
    )

    parser.add_argument(
        "-f",
        type=str,
        default=None,
        dest="docker_compose_fpath",
        help="The path to the docker compose file (one file supported)"
    )

    parser.add_argument(
        "-a",
        "--action",
        type=str,
        default=None,
        dest="action",
        help="The action to do [take,restore]"
    )

    parser.add_argument(
        "-n",
        "--name",
        type=str,
        default=None,
        dest="snapshot_name",
        help="The hyphen separated name of the snapshot, e.g foo-bar-baz"
    )

#    parser.add_argument(
#        "--data-in-from-file",
#        type=str,
#        default=None,
#        dest="content_file",
#        help="The path to file that contains the content of the data"
#    )
#
#    parser.add_argument(
#        "--data-in-from-url",
#        type=str,
#        default=None,
#        dest="content_url",
#        help="The url to the file that contains the content of the data"
#    )
#
#    parser.add_argument(
#        "--data-in-from-yaml",
#        type=str,
#        default=None,
#        dest="content_yml",
#        help="The path to the source yaml file from which to extract a key value"
#    )
#
#    parser.add_argument(
#        "--src-key",
#        type=str,
#        default=None,
#        dest="src_key",
#        help="The source key in the yaml file to be extracted"
#    )
#
#    parser.add_argument(
#        "--target-key",
#        type=str,
#        default=None,
#        dest="target_key",
#        help="The target key in the yaml file to be replaced"
#    )
#
#    parser.add_argument(
#        "--extract",
#        action="store_true",
#        default=False,
#        help="Extract the value of the target key"
#    )
#
#    parser.add_argument(
#        "-v",
#        "--verbosity",
#        action="count",
#        default=0
#    )

    return parser.parse_args()

def main():
    """
    The main function of the script
    """

    # parse the arguments and check them
    args_parsed = parse_args()


    yaml = YAML()
    yaml.indent(mapping=2, sequence=2, offset=2)
    yaml.width = 4096
    yaml.preserve_quotes = True
    yaml.explicit_start = True
    yaml.explicit_end = True

    # read the full yaml file
    docker_compose_fpath = os.path.expanduser(args_parsed.docker_compose_fpath)
    with open(docker_compose_fpath, 'r') as fobj:
        data = fobj.read()
    code = yaml.load(data)

    # get the list of all docker images on the host
    cmd = 'docker images --format "{{.Repository}}:{{.Tag}}"'
    process = Popen(shlex.split(cmd), stdout=PIPE, stderr=PIPE)
    stdout, _ = process.communicate()
    host_docker_images = stdout.decode().split('\n')

    for service in code['services']:
        print('service:', service)
        docker_image = code['services'][service]['image']
        if ':' in docker_image:
            docker_image, _ = docker_image.split(':')
        snapshot_image = f'{docker_image}:{args_parsed.snapshot_name}'
        if args_parsed.action == 'take':
            cmd = f"docker commit docker-{service}-1 {snapshot_image}"
            print('  take a snapshot of the docker image')
            print(f'  cmd: {cmd}')
            process = Popen(shlex.split(cmd), stdout=PIPE, stderr=PIPE)
            stdout, stderr = process.communicate()
        elif args_parsed.action == 'restore':
            if 'build' in code['services'][service]:
                # make a backup of the docker compose file before modifying it
                yaml_fpath = docker_compose_fpath + '.bak'
                with open(os.path.expanduser(yaml_fpath), 'w') as fobj:
                    yaml.dump(code, fobj)
                code['services'][service].pop('build')
            if snapshot_image in host_docker_images:
                yaml_fpath = docker_compose_fpath
                print(f'  update the docker image for service {service} to {snapshot_image}')
                code['services'][service]['image'] = snapshot_image
                with open(os.path.expanduser(yaml_fpath), 'w') as fobj:
                    yaml.dump(code, fobj)
            else:
                print(f'  Error: Image {snapshot_image} not found on the host')
                raise ValueError
        else:
            # unsupported action, raise an error
            print('Invalid action')
            raise ValueError

if __name__ == '__main__':
    main()
