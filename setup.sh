#!/bin/bash

mkdir -p keys configs

wg genkey | tee keys/server1_private.key | wg pubkey > keys/server1_public.key
wg genkey | tee keys/client1_private.key | wg pubkey > keys/client1_public.key
wg genkey | tee keys/server2_private.key | wg pubkey > keys/server2_public.key
wg genkey | tee keys/client2_private.key | wg pubkey > keys/client2_public.key
wg genpsk > keys/psk.key

SERVER1_PRIVATE_KEY=$(cat keys/server1_private.key)
SERVER1_PUBLIC_KEY=$(cat keys/server1_public.key)
CLIENT1_PRIVATE_KEY=$(cat keys/client1_private.key)
CLIENT1_PUBLIC_KEY=$(cat keys/client1_public.key)
SERVER2_PRIVATE_KEY=$(cat keys/server2_private.key)
SERVER2_PUBLIC_KEY=$(cat keys/server2_public.key)
CLIENT2_PRIVATE_KEY=$(cat keys/client2_private.key)
CLIENT2_PUBLIC_KEY=$(cat keys/client2_public.key)
PSK_KEY=$(cat keys/psk.key)

rm -r keys

cat > configs/server1.conf <<EOF
[Interface]
Address = 10.8.0.2/24
ListenPort = 51820
PrivateKey = $SERVER1_PRIVATE_KEY

[Peer]
PublicKey = $CLIENT1_PUBLIC_KEY
AllowedIPs = 10.8.0.3/32
EOF

cat > configs/client1.conf <<EOF
[Interface]
Address = 10.8.0.3/24
ListenPort = 51820
PrivateKey = $CLIENT1_PRIVATE_KEY

[Peer]
PublicKey = $SERVER1_PUBLIC_KEY
Endpoint = 172.28.0.2:51820
AllowedIPs = 10.8.0.0/24
EOF

cat > configs/server2.conf <<EOF
[Interface]
Address = 10.16.0.2/24
ListenPort = 51820
PrivateKey = $SERVER2_PRIVATE_KEY

[Peer]
PublicKey = $CLIENT2_PUBLIC_KEY
PresharedKey = $PSK_KEY
AllowedIPs = 10.16.0.3/32
EOF

cat > configs/client2.conf <<EOF
[Interface]
Address = 10.16.0.3/24
ListenPort = 51821
PrivateKey = $CLIENT2_PRIVATE_KEY

[Peer]
PublicKey = $SERVER2_PUBLIC_KEY
PresharedKey = $PSK_KEY
Endpoint = 172.28.0.3:51820
AllowedIPs = 10.16.0.0/24
EOF
