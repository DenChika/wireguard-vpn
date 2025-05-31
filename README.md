## Запуск
Чтобы сгенерировать ключи для клиента и шлюзов и вставить их в соответствующие wireguard-конфиги, надо выполнить команды
```console
chmod +x setup.sh
./setup.sh
```
Пример таких сгенерированных конфигов находится в [configs](configs)

Далее нужно собрать образы и запустить docker-контейнеры:
```console
docker-compose up -d
```

## Машины

Вместо виртуальных машин я решил использовать Docker, поскольку это быстрее, проще и меньше памяти ест.

С помощью [docker-compose.yml](docker-compose.yml) мы запускаем 3 контейнера: wg-server-1 (шлюз без psk), wg-server-2 (шлюз с psk) и wg-client.
Они создаются на основе образов lscr.io/linuxserver/wireguard:latest. Каждому раздаём ip-адрес из подсети 172.28.0.0/24.

Сгенеренные wireguard-конфиги копируем в контейнеры:
* Для wg-server-1 и wg-server-2 в файл /config/wg0.conf.
* Для wg-client нужно два конфига: для общения с шлюзами wg-server-1 и wg-server-2. Их мы копируем в /config/wg_confs/wg0.conf и /config/wg_confs/wg1.conf.

Остальная конфигурация взята с [официальной документации образа](https://hub.docker.com/r/linuxserver/wireguard)

## Wireguard-конфиги

Для работы с асимметричным шифрованием нужны wireguard-конфиги

### Общение со шлюзом без PSK
Wireguard-конфиг шлюза выглядит следующим образом:
```ini
[Interface]
Address = 10.8.0.2/24
ListenPort = 51820
PrivateKey = $SERVER1_PRIVATE_KEY

[Peer]
PublicKey = $CLIENT1_PUBLIC_KEY
AllowedIPs = 10.8.0.3/32
```
А клиента:
```ini
[Interface]
Address = 10.8.0.3/24
ListenPort = 51820
PrivateKey = $CLIENT1_PRIVATE_KEY

[Peer]
PublicKey = $SERVER1_PUBLIC_KEY
Endpoint = 172.28.0.2:51820
AllowedIPs = 10.8.0.0/24
```
Другими словами мы указываем ip-адреса клиента и шлюза для внутренней сети (10.8.0.3 и 10.8.0.2 соответственно) и устанавливаем обоюдную связь для проведения wireguard-handshake. 
Для клиента нам ещё понадобится выход к контейеру шлюза (wg-server-1).

### Общение со шлюзом с PSK
Wireguard-конфиг шлюза выглядит следующим образом:
```ini
[Interface]
Address = 10.16.0.2/24
ListenPort = 51820
PrivateKey = $SERVER2_PRIVATE_KEY

[Peer]
PublicKey = $CLIENT2_PUBLIC_KEY
PresharedKey = $PSK_KEY
AllowedIPs = 10.16.0.3/32
```
А клиента:
```ini
[Interface]
Address = 10.16.0.3/24
ListenPort = 51821
PrivateKey = $CLIENT2_PRIVATE_KEY

[Peer]
PublicKey = $SERVER2_PUBLIC_KEY
PresharedKey = $PSK_KEY
Endpoint = 172.28.0.3:51820
AllowedIPs = 10.16.0.0/24
```
Здесь мы уже указываем ip-адреса клиента и шлюза для второй внутренней сети (10.16.0.3 и 10.16.0.2 соответственно) и так же устанавливаем обоюдную связь для проведения wireguard-handshake. 
И для клиента нам ещё понадобится выход к контейеру шлюза (wg-server-2).

Стоит отметить, что у клиента прослушивается 51821 порт, потому что у клиентского контейнера два wireguard-конфига, а порт 51820 уже был занят в предыдущем пункте.

Основным отличием от предыдущего пункта является формирование PresharedKey.

## Результаты 
### Клиент-шлюз (без PSK)
```console
docker exec -it wg-client ping 10.8.0.2
```
Пакеты при этом придут следующие:

![image](https://github.com/user-attachments/assets/efd7169b-6738-4e9a-a0bb-585fe81ad5e5)

Wireguard-handshake прошёл успешно. Wireshark-логи можно посмотреть [тут](wireshark/gateway1.pcap)

### Клиент-шлюз (с PSK)
```console
docker exec -it wg-client ping 10.16.0.2
```
Пакеты при этом придут следующие:

![image](https://github.com/user-attachments/assets/d4d5ba2a-f3fc-4fbd-9388-996e57f62cbe)

Wireguard-handshake прошёл успешно. Wireshark-логи можно посмотреть [тут](wireshark/gateway2.pcap)

### Клиент без туннеля
Чтобы проверить, что туннель используется только для конкретного диапазона ip-адресов, нужно создать тестовый ip-адрес
```console
docker exec -it wg-client ip addr add 10.10.0.2/24 dev eth0
```
И попытаться подключиться


```console
docker exec -it wg-client ping 10.10.0.2
```

![image](https://github.com/user-attachments/assets/e24794fc-dd50-4cf7-8321-57fc6bb5d19f)

Как видим, пинг идёт. При этом wireshark, который ранее захватывал wireguard-пакеты

![image](https://github.com/user-attachments/assets/9e9f73b2-6772-4778-b712-2d5cf311f108)

, теперь пустует

![image](https://github.com/user-attachments/assets/411ec2ed-96d4-403a-8301-211f61fc0485)

Значит туннель не используется
