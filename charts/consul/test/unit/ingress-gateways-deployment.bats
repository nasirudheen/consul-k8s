#!/usr/bin/env bats

load _helpers

@test "ingressGateways/Deployment: disabled by default" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      .
}

@test "ingressGateways/Deployment: enabled with ingressGateways, connectInject enabled, has default gateway name" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s '.[0]' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq -r '.metadata.name' | tee /dev/stderr)
  [ "${actual}" = "RELEASE-NAME-consul-ingress-gateway" ]
}

@test "ingressGateways/Deployment: serviceAccountName is set properly" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enableConsulNamespaces=true' \
      --set 'ingress.defaults.consulNamespace=namespace' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.serviceAccountName' | tee /dev/stderr)

  [ "${actual}" = "RELEASE-NAME-consul-ingress-gateway" ]
}

@test "ingressGateways/Deployment: Adds consul service volumeMount to gateway container" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | yq '.spec.template.spec.containers[0].volumeMounts[1]' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.name' | tee /dev/stderr)
  [ "${actual}" = "consul-service" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/service" ]

  local actual=$(echo $object |
      yq -r '.readOnly' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# prerequisites

@test "ingressGateways/Deployment: fails if connectInject.enabled=false" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=false' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "connectInject.enabled must be true" ]]
}

@test "ingressGateways/Deployment: fails if client.grpc=false" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'client.grpc=false' \
      --set 'connectInject.enabled=true' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "client.grpc must be true" ]]
}

@test "ingressGateways/Deployment: fails if global.enabled is false and clients are not explicitly enabled" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enabled=false' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "clients must be enabled" ]]
}

@test "ingressGateways/Deployment: fails if global.enabled is true but clients are explicitly disabled" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enabled=true' \
      --set 'client.enabled=false' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "clients must be enabled" ]]
}

@test "ingressGateways/Deployment: fails if there are duplicate gateway names" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'ingressGateways.gateways[0].name=foo' \
      --set 'ingressGateways.gateways[1].name=foo' \
      --set 'connectInject.enabled=true' \
      --set 'global.enabled=true' \
      --set 'client.enabled=true' .
  echo "status: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ingress gateways must have unique names but found duplicate name foo" ]]
}

@test "ingressGateways/Deployment: fails if a terminating gateway has the same name as an ingress gateway" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'terminatingGateways.enabled=true' \
      --set 'ingressGateways.enabled=true' \
      --set 'terminatingGateways.gateways[0].name=foo' \
      --set 'ingressGateways.gateways[0].name=foo' \
      --set 'connectInject.enabled=true' \
      --set 'global.enabled=true' \
      --set 'client.enabled=true' .
  echo "status: $output"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "terminating gateways cannot have duplicate names of any ingress gateways" ]]
}
#--------------------------------------------------------------------
# envoyImage

@test "ingressGateways/Deployment: envoy image has default global value" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "envoyproxy/envoy-alpine:v1.20.2" ]
}

@test "ingressGateways/Deployment: envoy image can be set using the global value" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.imageEnvoy=new/image' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "new/image" ]
}

#--------------------------------------------------------------------
# global.tls.enabled

@test "ingressGateways/Deployment: sets TLS env variables when global.tls.enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'https://$(HOST_IP):8501' ]

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_GRPC_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'https://$(HOST_IP):8502' ]

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_CACERT") | .value' | tee /dev/stderr)
  [ "${actual}" = "/consul/tls/ca/tls.crt" ]
}

@test "ingressGateways/Deployment: sets TLS env variables in consul sidecar when global.tls.enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[1].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = 'https://$(HOST_IP):8501' ]

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_CACERT") | .value' | tee /dev/stderr)
  [ "${actual}" = "/consul/tls/ca/tls.crt" ]
}

@test "ingressGateways/Deployment: can overwrite CA secret with the provided one" {
  cd `chart_dir`
  local ca_cert_volume=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.caCert.secretName=foo-ca-cert' \
      --set 'global.tls.caCert.secretKey=key' \
      --set 'global.tls.caKey.secretName=foo-ca-key' \
      --set 'global.tls.caKey.secretKey=key' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.volumes[] | select(.name=="consul-ca-cert")' | tee /dev/stderr)

  # check that the provided ca cert secret is attached as a volume
  local actual=$(echo $ca_cert_volume | yq -r '.secret.secretName' | tee /dev/stderr)
  [ "${actual}" = "foo-ca-cert" ]

  # check that the volume uses the provided secret key
  local actual=$(echo $ca_cert_volume | yq -r '.secret.items[0].key' | tee /dev/stderr)
  [ "${actual}" = "key" ]
}

@test "ingressGateways/Deployment: CA cert volume present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes[] | select(.name == "consul-ca-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

#--------------------------------------------------------------------
# global.tls.enableAutoEncrypt

@test "ingressGateways/Deployment: consul-auto-encrypt-ca-cert volume is added when TLS with auto-encrypt is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.volumes[] | select(.name == "consul-auto-encrypt-ca-cert") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: consul-auto-encrypt-ca-cert volumeMount is added when TLS with auto-encrypt is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.containers[0].volumeMounts[] | select(.name == "consul-auto-encrypt-ca-cert") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: get-auto-encrypt-client-ca init container is created when TLS with auto-encrypt is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.initContainers[] | select(.name == "get-auto-encrypt-client-ca") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: consul-ca-cert volume is not added if externalServers.enabled=true and externalServers.useSystemRoots=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      --set 'externalServers.enabled=true' \
      --set 'externalServers.hosts[0]=foo.com' \
      --set 'externalServers.useSystemRoots=true' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.volumes[] | select(.name == "consul-ca-cert")' | tee /dev/stderr)
  [ "${actual}" = "" ]
}

#--------------------------------------------------------------------
# global.acls.manageSystemACLs

@test "ingressGateways/Deployment: consul-sidecar uses -token-file flag when global.acls.manageSystemACLs=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq -s '[.[0].spec.template.spec.containers[1].command[6]] | any(contains("-token-file=/consul/service/acl-token"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: Adds consul envvars CONSUL_HTTP_ADDR on ingress-gateway-init init container when ACLs are enabled and tls is enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.initContainers[1].env[]' | tee /dev/stderr)

  local actual
  actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = "https://\$(HOST_IP):8501" ]
}

@test "ingressGateways/Deployment: Adds consul envvars CONSUL_HTTP_ADDR on ingress-gateway-init init container when ACLs are enabled and tls is not enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'connectInject.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.initContainers[1].env[]' | tee /dev/stderr)

  local actual
  actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = "http://\$(HOST_IP):8500" ]
}

@test "ingressGateways/Deployment: Does not add consul envvars CONSUL_CACERT on ingress-gateway-init init container when ACLs are enabled and tls is not enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.initContainers[1].env[] | select(.name == "CONSUL_CACERT")' | tee /dev/stderr)

  [ "${actual}" = "" ]
}

@test "ingressGateways/Deployment: Adds consul envvars CONSUL_CACERT on ingress-gateway-init init container when ACLs are enabled and tls is enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.initContainers[1].env[]' | tee /dev/stderr)

  local actual=$(echo $env | jq -r '. | select(.name == "CONSUL_CACERT") | .value' | tee /dev/stderr)
    [ "${actual}" = "/consul/tls/ca/tls.crt" ]
}

@test "ingressGateways/Deployment: CONSUL_HTTP_TOKEN_FILE is not set when acls are disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.enabled=true' \
      --set 'global.acls.manageSystemACLs=false' \
      . | tee /dev/stderr |
      yq '[.spec.template.spec.containers[0].env[0].name] | any(contains("CONSUL_HTTP_TOKEN_FILE"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/Deployment: CONSUL_HTTP_TOKEN_FILE is set when acls are enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq -s '[.[0].spec.template.spec.containers[0].env[].name] | any(contains("CONSUL_HTTP_TOKEN_FILE"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: consul-logout preStop hook is added when ACLs are enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq '[.spec.template.spec.containers[0].lifecycle.preStop.exec.command[3]] | any(contains("/consul-bin/consul logout"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# metrics

@test "ingressGateways/Deployment: when global.metrics.enabled=true, adds prometheus scrape=true annotations" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.metrics.enabled=true'  \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations."prometheus.io/scrape"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: when global.metrics.enabled=true, adds prometheus port=20200 annotation" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.metrics.enabled=true'  \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations."prometheus.io/port"' | tee /dev/stderr)
  [ "${actual}" = "20200" ]
}

@test "ingressGateways/Deployment: when global.metrics.enabled=true, adds prometheus path=/metrics annotation" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.metrics.enabled=true'  \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations."prometheus.io/path"' | tee /dev/stderr)
  [ "${actual}" = "/metrics" ]
}

@test "ingressGateways/Deployment: when global.metrics.enabled=true, sets proxy setting" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.metrics.enabled=true'  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.initContainers[1].command | join(" ") | contains("envoy_prometheus_bind_addr = \"${POD_IP}:20200\"")' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: when global.metrics.enableGatewayMetrics=false, does not set proxy setting" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.metrics.enabled=true'  \
      --set 'global.metrics.enableGatewayMetrics=false'  \
      . | tee /dev/stderr |
      yq '.spec.template' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.spec.initContainers[1].command | join(" ") | contains("envoy_prometheus_bind_addr = \"${POD_IP}:20200\"")' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  local actual=$(echo $object | yq -s -r '.[0].metadata.annotations."prometheus.io/path"' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo $object | yq -s -r '.[0].metadata.annotations."prometheus.io/port"' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo $object | yq -s -r '.[0].metadata.annotations."prometheus.io/scrape"' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: when global.metrics.enabled=false, does not set proxy setting" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.metrics.enabled=false'  \
      . | tee /dev/stderr |
      yq '.spec.template' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.spec.initContainers[1].command | join(" ") | contains("envoy_prometheus_bind_addr = \"${POD_IP}:20200\"")' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  local actual=$(echo $object | yq -s -r '.[0].metadata.annotations."prometheus.io/path"' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo $object | yq -s -r '.[0].metadata.annotations."prometheus.io/port"' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo $object | yq -s -r '.[0].metadata.annotations."prometheus.io/scrape"' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

#--------------------------------------------------------------------
# replicas

@test "ingressGateways/Deployment: replicas defaults to 2" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.replicas' | tee /dev/stderr)
  [ "${actual}" = "2" ]
}

@test "ingressGateways/Deployment: replicas can be set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.replicas=3' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.replicas' | tee /dev/stderr)
  [ "${actual}" = "3" ]
}

@test "ingressGateways/Deployment: replicas can be set through specific gateway, overrides default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.replicas=3' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].replicas=12' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.replicas' | tee /dev/stderr)
  [ "${actual}" = "12" ]
}

#--------------------------------------------------------------------
# ports

@test "ingressGateways/Deployment: has default ports" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].ports' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.[0].containerPort' | tee /dev/stderr)
  [ "${actual}" = "21000" ]

  local actual=$(echo $object | yq -r '.[0].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-health" ]

  local actual=$(echo $object | yq -r '.[1].containerPort' | tee /dev/stderr)
  [ "${actual}" = "8080" ]

  local actual=$(echo $object | yq -r '.[1].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-0" ]

  local actual=$(echo $object | yq -r '.[2].containerPort' | tee /dev/stderr)
  [ "${actual}" = "8443" ]

  local actual=$(echo $object | yq -r '.[2].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-1" ]
}

@test "ingressGateways/Deployment: can set ports through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.ports[0].port=1234' \
      --set 'ingressGateways.defaults.service.ports[1].port=4444' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].ports' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.[0].containerPort' | tee /dev/stderr)
  [ "${actual}" = "21000" ]

  local actual=$(echo $object | yq -r '.[0].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-health" ]

  local actual=$(echo $object | yq -r '.[1].containerPort' | tee /dev/stderr)
  [ "${actual}" = "1234" ]

  local actual=$(echo $object | yq -r '.[1].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-0" ]

  local actual=$(echo $object | yq -r '.[2].containerPort' | tee /dev/stderr)
  [ "${actual}" = "4444" ]

  local actual=$(echo $object | yq -r '.[2].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-1" ]
}

@test "ingressGateways/Deployment: can set ports through specific gateway overriding defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].service.ports[0].port=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].ports' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.[0].containerPort' | tee /dev/stderr)
  [ "${actual}" = "21000" ]

  local actual=$(echo $object | yq -r '.[0].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-health" ]

  local actual=$(echo $object | yq -r '.[1].containerPort' | tee /dev/stderr)
  [ "${actual}" = "1234" ]

  local actual=$(echo $object | yq -r '.[1].name' | tee /dev/stderr)
  [ "${actual}" = "gateway-0" ]
}

#--------------------------------------------------------------------
# resources

@test "ingressGateways/Deployment: resources has default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].resources' | tee /dev/stderr)

  [ $(echo "${actual}" | yq -r '.requests.memory') = "100Mi" ]
  [ $(echo "${actual}" | yq -r '.requests.cpu') = "100m" ]
  [ $(echo "${actual}" | yq -r '.limits.memory') = "100Mi" ]
  [ $(echo "${actual}" | yq -r '.limits.cpu') = "100m" ]
}

@test "ingressGateways/Deployment: resources can be set through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.resources.requests.memory=memory' \
      --set 'ingressGateways.defaults.resources.requests.cpu=cpu' \
      --set 'ingressGateways.defaults.resources.limits.memory=memory2' \
      --set 'ingressGateways.defaults.resources.limits.cpu=cpu2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "memory" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "memory2" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu2" ]
}

@test "ingressGateways/Deployment: resources can be set through specific gateway, overriding defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.resources.requests.memory=memory' \
      --set 'ingressGateways.defaults.resources.requests.cpu=cpu' \
      --set 'ingressGateways.defaults.resources.limits.memory=memory2' \
      --set 'ingressGateways.defaults.resources.limits.cpu=cpu2' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].resources.requests.memory=gwmemory' \
      --set 'ingressGateways.gateways[0].resources.requests.cpu=gwcpu' \
      --set 'ingressGateways.gateways[0].resources.limits.memory=gwmemory2' \
      --set 'ingressGateways.gateways[0].resources.limits.cpu=gwcpu2' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.containers[0].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "gwmemory" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "gwcpu" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "gwmemory2" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "gwcpu2" ]
}

#--------------------------------------------------------------------
# init container resources

@test "ingressGateways/Deployment: init container has default resources" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers[0].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "25Mi" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "50m" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "150Mi" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "50m" ]
}

@test "ingressGateways/Deployment: init container resources can be set through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.requests.memory=memory' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.requests.cpu=cpu' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.limits.memory=memory2' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.limits.cpu=cpu2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers[0].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "memory" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "memory2" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu2" ]
}

@test "ingressGateways/Deployment: init container resources can be set through specific gateway, overriding defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.requests.memory=memory' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.requests.cpu=cpu' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.limits.memory=memory2' \
      --set 'ingressGateways.defaults.initCopyConsulContainer.resources.limits.cpu=cpu2' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].initCopyConsulContainer.resources.requests.memory=gwmemory' \
      --set 'ingressGateways.gateways[0].initCopyConsulContainer.resources.requests.cpu=gwcpu' \
      --set 'ingressGateways.gateways[0].initCopyConsulContainer.resources.limits.memory=gwmemory2' \
      --set 'ingressGateways.gateways[0].initCopyConsulContainer.resources.limits.cpu=gwcpu2' \
      . | tee /dev/stderr |
      yq -s '.[0].spec.template.spec.initContainers[0].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "gwmemory" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "gwcpu" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "gwmemory2" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "gwcpu2" ]
}

#--------------------------------------------------------------------
# consul sidecar resources

@test "ingressGateways/Deployment: consul sidecar has default resources" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[1].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "25Mi" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "20m" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "50Mi" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "20m" ]
}

@test "ingressGateways/Deployment: consul sidecar resources can be set" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.consulSidecarContainer.resources.requests.memory=memory' \
      --set 'global.consulSidecarContainer.resources.requests.cpu=cpu' \
      --set 'global.consulSidecarContainer.resources.limits.memory=memory2' \
      --set 'global.consulSidecarContainer.resources.limits.cpu=cpu2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[1].resources' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "memory" ]

  local actual=$(echo $object | yq -r '.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu" ]

  local actual=$(echo $object | yq -r '.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "memory2" ]

  local actual=$(echo $object | yq -r '.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "cpu2" ]
}

@test "ingressGateways/Deployment: fails if global.lifecycleSidecarContainer is set" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.lifecycleSidecarContainer.resources.requests.memory=100Mi' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "global.lifecycleSidecarContainer has been renamed to global.consulSidecarContainer. Please set values using global.consulSidecarContainer." ]]
}

#--------------------------------------------------------------------
# affinity

@test "ingressGateways/Deployment: affinity defaults to one per node" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey' | tee /dev/stderr)
  [ "${actual}" = "kubernetes.io/hostname" ]
}

@test "ingressGateways/Deployment: affinity can be set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.affinity=key: value' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.affinity.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

@test "ingressGateways/Deployment: affinity can be set through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.affinity=key: value' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].affinity=key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.affinity.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# tolerations

@test "ingressGateways/Deployment: no tolerations by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.tolerations' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: tolerations can be set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.tolerations=- key: value' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.tolerations[0].key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

@test "ingressGateways/Deployment: tolerations can be set through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.tolerations=- key: value' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].tolerations=- key: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.tolerations[0].key' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# nodeSelector

@test "ingressGateways/Deployment: no nodeSelector by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: can set a nodeSelector through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.nodeSelector=key: value' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.nodeSelector.key' | tee /dev/stderr)
  [ "${actual}" = "value" ]
}

@test "ingressGateways/Deployment: can set a nodeSelector through specific gateway, overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.nodeSelector=key: value' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].nodeSelector=key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.nodeSelector.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# priorityClassName

@test "ingressGateways/Deployment: no priorityClassName by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "ingressGateways/Deployment: can set a priorityClassName through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.priorityClassName=name' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "name" ]
}

@test "ingressGateways/Deployment: can set a priorityClassName per gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.priorityClassName=name' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].priorityClassName=priority' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "priority" ]
}

#--------------------------------------------------------------------
# annotations

@test "ingressGateways/Deployment: no extra annotations by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations | length' | tee /dev/stderr)
  [ "${actual}" = "1" ]
}

@test "ingressGateways/Deployment: extra annotations can be set through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "3" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

@test "ingressGateways/Deployment: extra annotations can be set through specific gateway" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "3" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

@test "ingressGateways/Deployment: extra annotations can be set through defaults and specific gateway" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.annotations=defaultkey: defaultvalue' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].annotations=key1: value1
key2: value2' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.metadata.annotations' | tee /dev/stderr)

  local actual=$(echo $object | yq '. | length' | tee /dev/stderr)
  [ "${actual}" = "4" ]

  local actual=$(echo $object | yq -r '.defaultkey' | tee /dev/stderr)
  [ "${actual}" = "defaultvalue" ]

  local actual=$(echo $object | yq -r '.key1' | tee /dev/stderr)
  [ "${actual}" = "value1" ]

  local actual=$(echo $object | yq -r '.key2' | tee /dev/stderr)
  [ "${actual}" = "value2" ]
}

#--------------------------------------------------------------------
# WAN_ADDR

@test "ingressGateways/Deployment: WAN_ADDR set correctly for ClusterIP service set in defaults (the default)" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_ADDR=\"$(cat /tmp/address.txt)\"")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_ADDR set correctly for ClusterIP service set in specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=Static' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.type=ClusterIP' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_ADDR=\"$(cat /tmp/address.txt)\"")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_ADDR set correctly for LoadBalancer service set in defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=LoadBalancer' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_ADDR=\"$(cat /tmp/address.txt)\"")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_ADDR set correctly for LoadBalancer service set in specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.type=LoadBalancer' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_ADDR=\"$(cat /tmp/address.txt)\"")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_ADDR set correctly for NodePort service set in defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.defaults.service.ports[0].nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_ADDR=\"${HOST_IP}\"")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_ADDR set correctly for NodePort service set in specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.type=NodePort' \
      --set 'ingressGateways.gateways[0].service.ports[0].nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_ADDR=\"${HOST_IP}\"")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_ADDR definition fails if using unknown service type in defaults" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=Static' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "currently set ingressGateway value service.type is not supported" ]]
}

@test "ingressGateways/Deployment: WAN_ADDR definition fails if using unknown service type in specific gateway overriding defaults" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.type=Static' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "currently set ingressGateway value service.type is not supported" ]]
}

#--------------------------------------------------------------------
# WAN_PORT

@test "ingressGateways/Deployment: WAN_PORT set correctly for non-NodePort service in defaults (the default)" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_PORT=80")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_PORT can be set for non-NodePort service in defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.ports[0].port=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_PORT=1234")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_PORT set correctly for non-NodePort service in specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.ports[0].port=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_PORT=1234")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_PORT set correctly for NodePort service with nodePort set in defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.defaults.service.ports[0].nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_PORT=1234")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_PORT set correctly for NodePort service with nodePort set in specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.ports[0].nodePort=8888' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.type=NodePort' \
      --set 'ingressGateways.gateways[0].service.ports[0].nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("WAN_PORT=1234")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: WAN_PORT definition fails if .service.type=NodePort and ports[0].nodePort is empty in defaults" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .service.type=NodePort and using ingressGateways.defaults.service.ports, the first port entry must include a nodePort" ]]
}

@test "ingressGateways/Deployment: WAN_PORT definition fails if .service.type=NodePort and ports[0].nodePort is empty in specific gateway and not provided in defaults" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.ports[0].port=1234' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .service.type=NodePort and defining ingressGateways.gateways.service.ports, the first port entry must include a nodePort" ]]
}

@test "ingressGateways/Deployment: WAN_PORT definition fails if .service.type=NodePort and ports[0].nodePort is empty in defaults and specific gateway" {
  cd `chart_dir`
  run helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.defaults.service.ports=null' \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "if ingressGateways .service.type=NodePort, the first port entry in either the defaults or specific gateway must include a nodePort" ]]
}

#--------------------------------------------------------------------
# ingress-gateway-init init container

@test "ingressGateways/Deployment: ingress-gateway-init init container defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s-control-plane service-address \
  -log-level=info \
  -log-json=false \
  -k8s-namespace=default \
  -name=RELEASE-NAME-consul-ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT=8080

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  id = "${POD_NAME}"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 21000
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:21000"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: ingress-gateway-init init container with acls.manageSystemACLs=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2]' | tee /dev/stderr)

  exp='consul-k8s-control-plane acl-init \
  -component-name=ingress-gateway/RELEASE-NAME-consul-ingress-gateway \
  -acl-auth-method=RELEASE-NAME-consul-k8s-component-auth-method \
  -token-sink-file=/consul/service/acl-token \
  -log-level=info \
  -log-json=false

consul-k8s-control-plane service-address \
  -log-level=info \
  -log-json=false \
  -k8s-namespace=default \
  -name=RELEASE-NAME-consul-ingress-gateway \
  -output-file=/tmp/address.txt
WAN_ADDR="$(cat /tmp/address.txt)"
WAN_PORT=8080

cat > /consul/service/service.hcl << EOF
service {
  kind = "ingress-gateway"
  name = "ingress-gateway"
  id = "${POD_NAME}"
  port = ${WAN_PORT}
  address = "${WAN_ADDR}"
  tagged_addresses {
    lan {
      address = "${POD_IP}"
      port = 21000
    }
    wan {
      address = "${WAN_ADDR}"
      port = ${WAN_PORT}
    }
  }
  proxy {
    config {
      envoy_gateway_no_default_bind = true
      envoy_gateway_bind_addresses {
        all-interfaces {
          address = "0.0.0.0"
        }
      }
    }
  }
  checks = [
    {
      name = "Ingress Gateway Listening"
      interval = "10s"
      tcp = "${POD_IP}:21000"
      deregister_critical_service_after = "6h"
    }
  ]
}
EOF

/consul-bin/consul services register \
  -token-file=/consul/service/acl-token \
  /consul/service/service.hcl'

  [ "${actual}" = "${exp}" ]
}

@test "ingressGateways/Deployment: ingress-gateway-init init container includes service-address command for LoadBalancer set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=LoadBalancer' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("consul-k8s-control-plane service-address")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: ingress-gateway-init init container includes service-address command for LoadBalancer set through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.type=LoadBalancer' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("consul-k8s-control-plane service-address")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: ingress-gateway-init init container does not include service-address command for NodePort set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.service.type=NodePort' \
      --set 'ingressGateways.defaults.service.ports[0].port=80' \
      --set 'ingressGateways.defaults.service.ports[0].nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("consul-k8s-control-plane service-address")' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/Deployment: ingress-gateway-init init container does not include service-address command for NodePort set through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].service.type=NodePort' \
      --set 'ingressGateways.gateways[0].service.ports[0].port=80' \
      --set 'ingressGateways.gateways[0].service.ports[0].nodePort=1234' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.initContainers | map(select(.name == "ingress-gateway-init"))[0] | .command[2] | contains("consul-k8s-control-plane service-address")' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

#--------------------------------------------------------------------
# namespaces

@test "ingressGateways/Deployment: namespace command flag is not present by default" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0]' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.command | any(contains("-namespace"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  local actual=$(echo $object | yq -r '.lifecycle.preStop.exec.command | any(contains("-namespace"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/Deployment: namespace command flag is specified through defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enableConsulNamespaces=true' \
      --set 'ingressGateways.defaults.consulNamespace=namespace' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0]' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.command | any(contains("-namespace=namespace"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq -r '.lifecycle.preStop.exec.command | any(contains("-namespace=namespace"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: namespace command flag is specified through specific gateway overriding defaults" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enableConsulNamespaces=true' \
      --set 'ingressGateways.defaults.consulNamespace=namespace' \
      --set 'ingressGateways.gateways[0].name=ingress-gateway' \
      --set 'ingressGateways.gateways[0].consulNamespace=new-namespace' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0]' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.command | any(contains("-namespace=new-namespace"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq -r '.lifecycle.preStop.exec.command | any(contains("-namespace=new-namespace"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# partitions

@test "ingressGateways/Deployment: partition command flag is not present by default" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0]' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.command | any(contains("-partition"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  local actual=$(echo $object | yq -r '.lifecycle.preStop.exec.command | any(contains("-partition"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "ingressGateways/Deployment: partition command flag is specified through partition name" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.enableConsulNamespaces=true' \
      --set 'global.adminPartitions.enabled=true' \
      --set 'global.adminPartitions.name=default' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.containers[0]' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.command | any(contains("-partition=default"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq -r '.lifecycle.preStop.exec.command | any(contains("-partition=default"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "ingressGateways/Deployment: fails if admin partitions are enabled but namespaces aren't" {
  cd `chart_dir`
    run helm template \
        -s templates/ingress-gateways-deployment.yaml  \
        --set 'ingressGateways.enabled=true' \
        --set 'connectInject.enabled=true' \
        --set 'global.enableConsulNamespaces=false' \
        --set 'global.adminPartitions.enabled=true' .

    [ "$status" -eq 1 ]
    [[ "$output" =~ "global.enableConsulNamespaces must be true if global.adminPartitions.enabled=true" ]]
}

#--------------------------------------------------------------------
# multiple gateways

@test "ingressGateways/Deployment: multiple gateways" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-role.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[1].name=gateway2' \
      . | tee /dev/stderr |
      yq -s -r '.' | tee /dev/stderr)

  local actual=$(echo $object | yq -r '.[0].metadata.name' | tee /dev/stderr)
  [ "${actual}" = "RELEASE-NAME-consul-gateway1" ]

  local actual=$(echo $object | yq -r '.[1].metadata.name' | tee /dev/stderr)
  [ "${actual}" = "RELEASE-NAME-consul-gateway2" ]

  local actual=$(echo $object | yq '.[0] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq '.[1] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | yq '.[2] | length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

#--------------------------------------------------------------------
# Vault

@test "ingressGateway/Deployment: vault tls annotations are set when tls is enabled" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      --set 'global.tls.caCert.secretName=foo' \
      --set 'global.secretsBackend.vault.enabled=true' \
      --set 'global.secretsBackend.vault.consulClientRole=test' \
      --set 'global.secretsBackend.vault.consulServerRole=foo' \
      --set 'global.secretsBackend.vault.consulCARole=carole' \
      . | tee /dev/stderr |
      yq -r '.spec.template' | tee /dev/stderr)

  # Check annotations
  local actual=$(echo $object | jq -r '.metadata.annotations["vault.hashicorp.com/agent-init-first"]' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | jq -r '.metadata.annotations["vault.hashicorp.com/agent-inject"]' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object | jq -r '.metadata.annotations["vault.hashicorp.com/role"]' | tee /dev/stderr)
  [ "${actual}" = "carole" ]

  local actual=$(echo $object | jq -r '.metadata.annotations["vault.hashicorp.com/agent-inject-secret-serverca.crt"]' | tee /dev/stderr)
  [ "${actual}" = "foo" ]

  local actual=$(echo $object | jq -r '.metadata.annotations["vault.hashicorp.com/agent-inject-template-serverca.crt"]' | tee /dev/stderr)
  [ "${actual}" = $'{{- with secret \"foo\" -}}\n{{- .Data.certificate -}}\n{{- end -}}' ]
}

@test "ingressGateway/Deployment: vault CA is not configured by default" {
  cd `chart_dir`
  local object=$(helm template \
    -s templates/ingress-gateways-deployment.yaml  \
    --set 'ingressGateways.enabled=true' \
    --set 'connectInject.enabled=true' \
    --set 'global.tls.enabled=true' \
    --set 'global.tls.enableAutoEncrypt=true' \
    --set 'global.tls.caCert.secretName=foo' \
    --set 'global.secretsBackend.vault.enabled=true' \
    --set 'global.secretsBackend.vault.consulClientRole=foo' \
    --set 'global.secretsBackend.vault.consulServerRole=test' \
    --set 'global.secretsBackend.vault.consulCARole=test' \
    . | tee /dev/stderr |
      yq -r '.spec.template' | tee /dev/stderr)
  local actual=$(echo $object | yq -r '.metadata.annotations | has("vault.hashicorp.com/agent-extra-secret")')
  [ "${actual}" = "false" ]
  local actual=$(echo $object | yq -r '.metadata.annotations | has("vault.hashicorp.com/ca-cert")')
  [ "${actual}" = "false" ]
}


@test "ingressGateway/Deployment: vault CA is not configured when secretName is set but secretKey is not" {
  cd `chart_dir`
  local object=$(helm template \
    -s templates/ingress-gateways-deployment.yaml  \
    --set 'ingressGateways.enabled=true' \
    --set 'connectInject.enabled=true' \
    --set 'global.tls.enabled=true' \
    --set 'global.tls.enableAutoEncrypt=true' \
    --set 'global.tls.caCert.secretName=foo' \
    --set 'global.secretsBackend.vault.enabled=true' \
    --set 'global.secretsBackend.vault.consulClientRole=foo' \
    --set 'global.secretsBackend.vault.consulServerRole=test' \
    --set 'global.secretsBackend.vault.consulCARole=test' \
    --set 'global.secretsBackend.vault.ca.secretName=ca' \
    . | tee /dev/stderr |
      yq -r '.spec.template' | tee /dev/stderr)
  local actual=$(echo $object | yq -r '.metadata.annotations | has("vault.hashicorp.com/agent-extra-secret")')
  [ "${actual}" = "false" ]
  local actual=$(echo $object | yq -r '.metadata.annotations | has("vault.hashicorp.com/ca-cert")')
  [ "${actual}" = "false" ]
}

@test "ingressGateway/Deployment: vault CA is not configured when secretKey is set but secretName is not" {
  cd `chart_dir`
  local object=$(helm template \
    -s templates/ingress-gateways-deployment.yaml  \
    --set 'ingressGateways.enabled=true' \
    --set 'connectInject.enabled=true' \
    --set 'global.tls.enabled=true' \
    --set 'global.tls.enableAutoEncrypt=true' \
    --set 'global.tls.caCert.secretName=foo' \
    --set 'global.secretsBackend.vault.enabled=true' \
    --set 'global.secretsBackend.vault.consulClientRole=foo' \
    --set 'global.secretsBackend.vault.consulServerRole=test' \
    --set 'global.secretsBackend.vault.consulCARole=test' \
    --set 'global.secretsBackend.vault.ca.secretKey=tls.crt' \
    . | tee /dev/stderr |
      yq -r '.spec.template' | tee /dev/stderr)
  local actual=$(echo $object | yq -r '.metadata.annotations | has("vault.hashicorp.com/agent-extra-secret")')
  [ "${actual}" = "false" ]
  local actual=$(echo $object | yq -r '.metadata.annotations | has("vault.hashicorp.com/ca-cert")')
  [ "${actual}" = "false" ]
}

@test "ingressGateway/Deployment: vault CA is configured when both secretName and secretKey are set" {
  cd `chart_dir`
  local object=$(helm template \
    -s templates/ingress-gateways-deployment.yaml  \
    --set 'ingressGateways.enabled=true' \
    --set 'connectInject.enabled=true' \
    --set 'global.tls.enabled=true' \
    --set 'global.tls.enableAutoEncrypt=true' \
    --set 'global.tls.caCert.secretName=foo' \
    --set 'global.secretsBackend.vault.enabled=true' \
    --set 'global.secretsBackend.vault.consulClientRole=foo' \
    --set 'global.secretsBackend.vault.consulServerRole=test' \
    --set 'global.secretsBackend.vault.consulCARole=test' \
    --set 'global.secretsBackend.vault.ca.secretName=ca' \
    --set 'global.secretsBackend.vault.ca.secretKey=tls.crt' \
    . | tee /dev/stderr |
      yq -r '.spec.template' | tee /dev/stderr)
  local actual=$(echo $object | yq -r '.metadata.annotations."vault.hashicorp.com/agent-extra-secret"')
  [ "${actual}" = "ca" ]
  local actual=$(echo $object | yq -r '.metadata.annotations."vault.hashicorp.com/ca-cert"')
  [ "${actual}" = "/vault/custom/tls.crt" ]
}

#--------------------------------------------------------------------
# Vault agent annotations

@test "ingressGateway/Deployment: no vault agent annotations defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.secretsBackend.vault.enabled=true' \
      --set 'global.secretsBackend.vault.consulClientRole=test' \
      --set 'global.secretsBackend.vault.consulServerRole=foo' \
      --set 'global.tls.caCert.secretName=foo' \
      --set 'global.secretsBackend.vault.consulCARole=carole' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations | del(."consul.hashicorp.com/connect-inject") | del(."vault.hashicorp.com/agent-inject") | del(."vault.hashicorp.com/role")' | tee /dev/stderr)
  [ "${actual}" = "{}" ]
}

@test "ingressGateway/Deployment: vault agent annotations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      --set 'global.secretsBackend.vault.enabled=true' \
      --set 'global.secretsBackend.vault.consulClientRole=test' \
      --set 'global.secretsBackend.vault.consulServerRole=foo' \
      --set 'global.tls.caCert.secretName=foo' \
      --set 'global.secretsBackend.vault.consulCARole=carole' \
      --set 'global.secretsBackend.vault.agentAnnotations=foo: bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# terminationGracePeriodSeconds

@test "ingressGateways/Deployment: terminationGracePeriodSeconds defaults to 10" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.terminationGracePeriodSeconds' | tee /dev/stderr)
  [ "${actual}" = "10" ]
}

@test "ingressGateways/Deployment: terminationGracePeriodSeconds can be set through defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.terminationGracePeriodSeconds=5' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.terminationGracePeriodSeconds' | tee /dev/stderr)
  [ "${actual}" = "5" ]
}

@test "ingressGateways/Deployment: can set terminationGracePeriodSeconds through specific gateway overriding defaults" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/ingress-gateways-deployment.yaml  \
      --set 'ingressGateways.enabled=true' \
      --set 'connectInject.enabled=true' \
      --set 'ingressGateways.defaults.terminationGracePeriodSeconds=5' \
      --set 'ingressGateways.gateways[0].name=gateway1' \
      --set 'ingressGateways.gateways[0].terminationGracePeriodSeconds=30' \
      . | tee /dev/stderr |
      yq -s -r '.[0].spec.template.spec.terminationGracePeriodSeconds' | tee /dev/stderr)
  [ "${actual}" = "30" ]
}
