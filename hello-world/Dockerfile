FROM golang:1.27.1-alpine

WORKDIR /app

# Copy the local configuration file into the container
# The local configuration file will be used as the default configuration for the application.
# It is embedded into the go binary using the `embed` package.
COPY config/local.config.toml ./config/local.config.toml

COPY go.mod ./
COPY go.sum ./

COPY main.go ./

RUN go mod tidy && go mod download

RUN go build -o hello-world

EXPOSE 8080

CMD ["./hello-world"]