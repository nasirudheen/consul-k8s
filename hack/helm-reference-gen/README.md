# Helm Reference Generator

This script generates markdown documentation out of the values.yaml file for use on consul.io.

## Usage

From the root of the `consul-k8s` repo, generate Helm value documentation with

``` bash
make gen-docs [consul-repo-path] [-validate]
```

Where `[consul-repo-path]` is the location of the `hashicorp/consul` repo. Defaults to `../../../consul`.

If `-validate` is set, the generated docs won't be output anywhere. This is useful in CI to ensure the generation will succeed.
