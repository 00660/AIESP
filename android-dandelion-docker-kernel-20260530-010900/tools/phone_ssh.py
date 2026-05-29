import argparse
import os
import sys

import paramiko


DEFAULT_HOST = "192.168.2.89"
DEFAULT_USER = "root"
DEFAULT_KEY = os.path.join(os.environ.get("USERPROFILE", ""), ".ssh", "vxbot_phone_ed25519")


def connect(args):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=args.host,
        port=args.port,
        username=args.user,
        key_filename=args.key,
        timeout=15,
        banner_timeout=15,
        auth_timeout=15,
    )
    return client


def run(args):
    client = connect(args)
    try:
        stdin, stdout, stderr = client.exec_command(args.command)
        stdin.close()
        out = stdout.read().decode("utf-8", "replace")
        err = stderr.read().decode("utf-8", "replace")
        code = stdout.channel.recv_exit_status()
        if out:
            print(out, end="")
        if err:
            print(err, end="", file=sys.stderr)
        return code
    finally:
        client.close()


def get(args):
    client = connect(args)
    try:
        sftp = client.open_sftp()
        try:
            sftp.get(args.remote, args.local)
        finally:
            sftp.close()
        return 0
    finally:
        client.close()


def put(args):
    client = connect(args)
    try:
        sftp = client.open_sftp()
        try:
            sftp.put(args.local, args.remote)
        finally:
            sftp.close()
        return 0
    finally:
        client.close()


def exec_script(args):
    client = connect(args)
    try:
        with open(args.local, "rb") as f:
            script = f.read()
        stdin, stdout, stderr = client.exec_command(args.command)
        stdin.write(script)
        stdin.close()
        out = stdout.read().decode("utf-8", "replace")
        err = stderr.read().decode("utf-8", "replace")
        code = stdout.channel.recv_exit_status()
        if out:
            print(out, end="")
        if err:
            print(err, end="", file=sys.stderr)
        return code
    finally:
        client.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--user", default=DEFAULT_USER)
    parser.add_argument("--key", default=DEFAULT_KEY)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_run = sub.add_parser("run")
    p_run.add_argument("command")
    p_run.set_defaults(func=run)

    p_get = sub.add_parser("get")
    p_get.add_argument("remote")
    p_get.add_argument("local")
    p_get.set_defaults(func=get)

    p_put = sub.add_parser("put")
    p_put.add_argument("local")
    p_put.add_argument("remote")
    p_put.set_defaults(func=put)

    p_exec = sub.add_parser("exec")
    p_exec.add_argument("local")
    p_exec.add_argument("command", nargs="?", default="sh -s")
    p_exec.set_defaults(func=exec_script)

    args = parser.parse_args()
    raise SystemExit(args.func(args))


if __name__ == "__main__":
    main()
