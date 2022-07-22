rockserve is a webhook endpoint server for RockBLOCK short burst data messages
sent over the Iridium satellite network.

Message processing has been customized for the PipeCyte project at the
University of Washington. Parsed messages can be sent along to a downstream
Prometheus server for visualization.

The server can be easily deployed on AWS EC2 using terraform.

### Build

Build a linux binary

```sh
GOOS=linux GOARCH=amd64 go build -o rockserve.linux-amd64 main.go
```

### Run

```sh
rockserve --address :8080 --prometheus
```

### Deploy

Install Terraform.

Make a copy of `env-template.sh`, let's say to `env.sh`, edit with appropriate
values, then source the file to set up your environment.

```
source env.sh
```

Then deploy with terraform

```sh
terraform plan
terraform apply
```

To bring the server down

```
terraform destroy
```
