cluster-init: true
disable-cloud-controller: true
disable:
- servicelb
- local-storage
flannel-iface: eth1
node-ip: ${node_ip}
advertise-address: ${node_ip}
tls-san: ${node_ip}
kubelet-arg: "cloud-provider=external"
token: ${token}
node-name: ${node_name}