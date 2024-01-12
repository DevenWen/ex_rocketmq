#本文档协助运行单元测试

ps 安装 rocketmq，建议使用 docker-compose 

## 1. 建立目录文件
```
.
├── conf
│   └── broker.conf
├── docker-compose.yml
```


```
version: '3.5'
services:
  rmqnamesrv:
    image: rocketmqinc/rocketmq
    container_name: rmqnamesrv
    restart: always
    ports:
      - 9876:9876
    environment:
    #内存分配
      JAVA_OPT_EXT: "-server -Xms128m -Xmx128m"
    volumes:
      - ./logs:/root/logs
    command: sh mqnamesrv
    networks:
      rmq:
        aliases:
          - rmqnamesrv
          
  rmqbroker:
    image: rocketmqinc/rocketmq
    container_name: rmqbroker
    restart: always
    depends_on:
      - rmqnamesrv
    ports:
      - 10909:10909
      - 10911:10911
    volumes:
      - ./logs:/root/logs
      - ./store:/root/store
      - ./conf/broker.conf:/opt/rocketmq-4.4.0/conf/broker.conf
    command: sh mqbroker  -c /opt/rocketmq-4.4.0/conf/broker.conf
    environment:
      NAMESRV_ADDR: "rmqnamesrv:9876"
      JAVA_OPT_EXT: "-server -Xms128m -Xmx128m -Xmn128m"
    networks:
      rmq:
        aliases:
          - rmqbroker
          
  rmqconsole:
    image: styletang/rocketmq-console-ng
    container_name: rocketmq-console
    restart: always
    ports:
      - 8080:8080
    depends_on:
      - rmqnamesrv
    environment:
      JAVA_OPTS: "-Drocketmq.namesrv.addr=rmqnamesrv:9876 -Dcom.rocketmq.sendMessageWithVIPChannel=false"
    networks:
      rmq:
        aliases:
          - rmqconsole
          
networks:
  rmq:
    name: rmq
    driver: bridge
```

broker.conf
```
brokerName = broker-a
brokerId = 0  
deleteWhen = 04  
fileReservedTime = 48  
brokerRole = ASYNC_MASTER  
flushDiskType = ASYNC_FLUSH 
autoCreateTopicEnable = true
brokerIP1 = {{宿主机ip}}
```

## 2. 启动验证
1. 启动：`docker-compose up -d`
2. 验证：http://localhost:8080
3. `mix test`

