#cloud-config
${jsonencode({
  "users": [
    "default",
    { "name": "kitkat69",
      "gecos": "Artem",
      "sudo": "ALL=(ALL) NOPASSWD: ALL",
      "groups": "users",
      "ssh_authorized_keys": "${ssh_key}",
      "shell": "/bin/bash"
    }
  ],
  "apt": {
    "primary": {
      "arches": "[default]",
      "uri": "https://nginx.org/packages/ubuntu/"
    }
  },
  "package_update": "true",
  "packages": [
    "nginx"
  ],
  "write_files": [
    { "content": "${index}",
      "owner": "root:root",
      "permissions": "0644",
      "path": "/var/www/html/index.html"
    }
  ]
  "runcmd": [
    [ "systemctl", "daemon-reload" ],
    [ "systemctl", "enable", "nginx" ],
    [ "systemctl", "start", "--no-block", "nginx" ]
  ]
})}
