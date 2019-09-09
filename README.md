# Integrating Sensu + InfluxDB, Sensu Summit 2019

First, clone the repo and create the data directories:

```
$ mkdir data data/chronograf/ data/influxdb data/influxdb/config/ data/influxdb/data/ data/sensu-backend/ data/sensu-agent/
```

## Start Your Containers... (Docker Compose)

There is a docker-compose file in this repo, so you can bring up all the components using `docker-compose up -d`.

## Configure Sensuctl

[Install sensuctl](https://docs-preview.sensuapp.org/sensu-go/5.12/installation/install-sensu/#install-sensuctl) and configure:

```
$ sensuctl configure -n \
--username 'admin' \
--password 'P@ssw0rd!' \
--namespace default \
--url 'http://127.0.0.1:8080'
```

## Configure InfluxDB

```
docker exec -it sensu-summit-2019_influxdb_1 influx
```

```
CREATE DATABASE sensu

CREATE USER sensu WITH PASSWORD 'password'

GRANT ALL ON sensu TO sensu
```

## Check Setup

We're going to set up a simple check that outputs data in InfluxDB Line Protocol. First, we need to add the check script to the agent container, set the owner, and give it the appropriate permissions.

```
docker cp ./line_protocol.sh sensu-summit-2019_sensu-agent_1:/usr/local/bin/
docker exec sensu-summit-2019_sensu-agent_1 chown root:root /usr/local/bin/line_protocol.sh
docker exec sensu-summit-2019_sensu-agent_1 chmod +x /usr/local/bin/line_protocol.sh
```

Next, we'll create the check using sensuctl:

```
sensuctl check create check-line \
--command '/usr/local/bin/line_protocol.sh' \
--interval 5 \
--subscriptions webserver
```

## Handler Setup

We'll also need to add the handler to the backend.

```
sensuctl asset create sensu-influxdb-handler --url "https://assets.bonsai.sensu.io/b28f8719a48aa8ea80c603f97e402975a98cea47/sensu-influxdb-handler_3.1.2_linux_amd64.tar.gz" --sha512 "612c6ff9928841090c4d23bf20aaf7558e4eed8977a848cf9e2899bb13a13e7540bac2b63e324f39d9b1257bb479676bc155b24e21bf93c722b812b0f15cb3bd"
```

After that, we can create the handler using sensuctl:

```
sensuctl handler create influx-db \
--type pipe \
--command "sensu-influxdb-handler -d sensu" \
--env-vars "INFLUXDB_ADDR=http://sensu-summit-2019_influxdb_1:8086, INFLUXDB_USER=sensu, INFLUXDB_PASS=password" \
--runtime-assets sensu-influxdb-handler
```

### Enable Handler for Check

Finally, configure the check with the appropriate metrics format and set it up to use the handler we just created:

```
sensuctl check set-output-metric-format check-line influxdb_line
sensuctl check set-output-metric-handlers check-line influx-db
```

## Run Some Queries

To access the InfluxDB CLI, execute a bash shell within the container. If you started up using Docker Compose:

```
docker exec -it sensu-summit-2019_influxdb_1 influx
```

Select the `sensu` database:

```
USE sensu
```

Make the timestamps human readable:

```
PRECISION rfc3339
```

Retrieve all the data from our Line Protocol check for the past hour:

```
SELECT * FROM randoms WHERE time > now()-1h
```

Calculate the mean of the data:

```
SELECT mean(*) FROM randoms WHERE time > now()-1h
```

Calculate the mean of the data in 1-minute windows:

```
SELECT mean(*) FROM randoms WHERE time > now()-1h GROUP BY time(1m)
```

Calculate the mean of the data in 1-minute windows, ignoring windows with no data:

```
SELECT mean(*) FROM randoms WHERE time > now()-1h GROUP BY time(1m) FILL(none)
```

Use a subquery to find the minute with the highest mean value:

```
SELECT max(mean_value) FROM (SELECT mean(*) FROM randoms WHERE time > now()-1h GROUP BY time(1m) FILL(none))
```

## Caturday

"Caturday" is a simple Go application that serves cat pics and some additional info, used by my former coworker Lorenzo Fontana. It's part of the Docker Compose file and currently running at localhost:3333.

In order to generate some test data, there is also a shell script wich uses curl to hit the Caturday application periodically. We can run that in a separate terminal window:

```
./caturday_ping.sh
```

## Prometheus

There are two files in this repo which we will use to set up collection of metrics from a Prometheus endpoint: "asset_prometheus" and "prometheus_check". The first declares the Sensu Prometheus Collector asset, and the second defines a check which will periodically scrape data from the Caturday metrics endpoint. We can install both with a single command:

```
sensuctl create --file asset_prometheus
sensuctl create --file prometheus_check
```

## Configure Chronograf

Log into Chronograf at http://localhost:8888.

Connect to the InfluxDB instance. If you used Docker compose, the URL will be `http://sensu-summit-2019_influxdb_1:8086`.

### Make Some Graphs

Graph the number of requests for Caturday:

```
SELECT "value" FROM "sensu"."autogen"."caturday_requests_count" WHERE time > :dashboardTime:
```

Calculate the rate using a non-negative derivative:

```
SELECT non_negative_derivative("value", 1m) AS "rate" FROM "sensu"."autogen"."caturday_requests_count" WHERE time > :dashboardTime: FILL(null)
```