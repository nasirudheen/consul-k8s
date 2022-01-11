package main

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

// Test parsing YAML to DocNodes for various smaller cases and special cases.
func TestParse(t *testing.T) {
	cases := map[string]struct {
		Input string
		Exp   DocNode
	}{
		"string value": {
			Input: `---
# Line 1
# Line 2
key: value`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						Default: "value",
						Comment: "# Line 1\n# Line 2",
						KindTag: "!!str",
					},
				},
			},
		},
		"integer value": {
			Input: `---
# Line 1
# Line 2
replicas: 3`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "replicas",
						Column:  1,
						Default: "3",
						Comment: "# Line 1\n# Line 2",
						KindTag: "!!int",
					},
				},
			},
		},
		"boolean value": {
			Input: `---
# Line 1
# Line 2
enabled: true`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "enabled",
						Column:  1,
						Default: "true",
						Comment: "# Line 1\n# Line 2",
						KindTag: "!!bool",
					},
				},
			},
		},
		"map": {
			Input: `---
# Map line 1
# Map line 2
map:
  # Key line 1
  # Key line 2
  key: value`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "map",
						Column:  1,
						Comment: "# Map line 1\n# Map line 2",
						KindTag: "!!map",
						Children: []DocNode{
							{
								Key:              "key",
								Column:           3,
								Default:          "value",
								Comment:          "# Key line 1\n# Key line 2",
								KindTag:          "!!str",
								ParentBreadcrumb: "-map",
							},
						},
					},
				},
			},
		},
		"map with multiple keys": {
			Input: `---
# Map line 1
# Map line 2
map:
  # Key line 1
  # Key line 2
  key: value
  # Int docs
  int: 1
  # Bool docs
  bool: true`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "map",
						Column:  1,
						Comment: "# Map line 1\n# Map line 2",
						KindTag: "!!map",
						Children: []DocNode{
							{
								Key:              "key",
								Column:           3,
								Default:          "value",
								Comment:          "# Key line 1\n# Key line 2",
								KindTag:          "!!str",
								ParentBreadcrumb: "-map",
							},
							{
								Key:              "int",
								Column:           3,
								Default:          "1",
								Comment:          "# Int docs",
								KindTag:          "!!int",
								ParentBreadcrumb: "-map",
							},
							{
								Key:              "bool",
								Column:           3,
								Default:          "true",
								Comment:          "# Bool docs",
								KindTag:          "!!bool",
								ParentBreadcrumb: "-map",
							},
						},
					},
				},
			},
		},
		"null value": {
			Input: `---
# key docs
# @type: string
key: null`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						Default: "null",
						Comment: "# key docs\n# @type: string",
						KindTag: "!!null",
					},
				},
			},
		},
		"description with empty line": {
			Input: `---
# line 1
#
# line 2
key: value`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						Default: "value",
						Comment: "# line 1\n#\n# line 2",
						KindTag: "!!str",
					},
				},
			},
		},
		"array of strings": {
			Input: `---
# line 1
# @type: array<string>
serverAdditionalDNSSANs: []
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "serverAdditionalDNSSANs",
						Column:  1,
						Comment: "# line 1\n# @type: array<string>",
						KindTag: "!!seq",
						Default: "[]",
					},
				},
			},
		},
		"map with empty string values": {
			Input: `---
# gossipEncryption
gossipEncryption:
  # secretName
  secretName: ""
  # secretKey
  secretKey: ""
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "gossipEncryption",
						Column:  1,
						Comment: "# gossipEncryption",
						KindTag: "!!map",
						Children: []DocNode{
							{
								Key:              "secretName",
								Column:           3,
								Default:          "",
								Comment:          "# secretName",
								KindTag:          "!!str",
								ParentBreadcrumb: "-gossipencryption",
							},
							{
								Key:              "secretKey",
								Column:           3,
								Default:          "",
								Comment:          "# secretKey",
								KindTag:          "!!str",
								ParentBreadcrumb: "-gossipencryption",
							},
						},
					},
				},
			},
		},
		"map with null string values": {
			Input: `---
bootstrapToken:
  # @type: string
  secretName: null
  # @type: string
  secretKey: null
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "bootstrapToken",
						Column:  1,
						KindTag: "!!map",
						Children: []DocNode{
							{
								Key:              "secretName",
								Column:           3,
								Default:          "null",
								Comment:          "# @type: string",
								KindTag:          "!!null",
								ParentBreadcrumb: "-bootstraptoken",
							},
							{
								Key:              "secretKey",
								Column:           3,
								Default:          "null",
								Comment:          "# @type: string",
								KindTag:          "!!null",
								ParentBreadcrumb: "-bootstraptoken",
							},
						},
					},
				},
			},
		},
		"resource settings": {
			Input: `---
# lifecycle
lifecycleSidecarContainer:
  # The resource requests and limits (CPU, memory, etc.)
  # for each of the lifecycle sidecar containers. This should be a YAML map of a Kubernetes
  # [ResourceRequirements](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) object.
  #
  # Example:
  # $$$yaml
  # resources:
  #   requests:
  #     memory: "25Mi"
  #     cpu: "20m"
  #   limits:
  #     memory: "50Mi"
  #     cpu: "20m"
  # $$$
  resources:
    requests:
      memory: "25Mi"
      cpu: "20m"
    limits:
      memory: "50Mi"
      cpu: "20m"
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "lifecycleSidecarContainer",
						Column:  1,
						KindTag: "!!map",
						Comment: "# lifecycle",
						Children: []DocNode{
							{
								Key:              "resources",
								Column:           3,
								KindTag:          "!!map",
								ParentBreadcrumb: "-lifecyclesidecarcontainer",
								Comment:          "# The resource requests and limits (CPU, memory, etc.)\n# for each of the lifecycle sidecar containers. This should be a YAML map of a Kubernetes\n# [ResourceRequirements](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) object.\n#\n# Example:\n# ```yaml\n# resources:\n#   requests:\n#     memory: \"25Mi\"\n#     cpu: \"20m\"\n#   limits:\n#     memory: \"50Mi\"\n#     cpu: \"20m\"\n# ```",
								Children: []DocNode{
									{
										Key:              "requests",
										Column:           5,
										KindTag:          "!!map",
										ParentBreadcrumb: "-lifecyclesidecarcontainer-resources",
										Children: []DocNode{
											{
												Key:              "memory",
												Column:           7,
												Default:          "25Mi",
												KindTag:          "!!str",
												ParentBreadcrumb: "-lifecyclesidecarcontainer-resources-requests",
											},
											{
												Key:              "cpu",
												Column:           7,
												Default:          "20m",
												KindTag:          "!!str",
												ParentBreadcrumb: "-lifecyclesidecarcontainer-resources-requests",
											},
										},
									},
									{
										Key:              "limits",
										Column:           5,
										KindTag:          "!!map",
										ParentBreadcrumb: "-lifecyclesidecarcontainer-resources",
										Children: []DocNode{
											{
												Key:              "memory",
												Column:           7,
												Default:          "50Mi",
												KindTag:          "!!str",
												ParentBreadcrumb: "-lifecyclesidecarcontainer-resources-limits",
											},
											{
												Key:              "cpu",
												Column:           7,
												Default:          "20m",
												KindTag:          "!!str",
												ParentBreadcrumb: "-lifecyclesidecarcontainer-resources-limits",
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
		"default as dash": {
			Input: `---
server:
  # If true, the chart will install all the resources necessary for a
  # Consul server cluster. If you're running Consul externally and want agents
  # within Kubernetes to join that cluster, this should probably be false.
  # @default: global.enabled
  # @type: boolean
  enabled: "-"
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "server",
						Column:  1,
						KindTag: "!!map",
						Children: []DocNode{
							{
								Key:              "enabled",
								Column:           3,
								Default:          "-",
								KindTag:          "!!str",
								ParentBreadcrumb: "-server",
								Comment:          "# If true, the chart will install all the resources necessary for a\n# Consul server cluster. If you're running Consul externally and want agents\n# within Kubernetes to join that cluster, this should probably be false.\n# @default: global.enabled\n# @type: boolean",
							},
						},
					},
				},
			},
		},
		"extraConfig {}": {
			Input: `---
extraConfig: |
  {}
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "extraConfig",
						Column:  1,
						KindTag: "!!str",
						Default: "{}\n",
					},
				},
			},
		},
		"affinity": {
			Input: `---
# Affinity Settings
affinity: |
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: {{ template "consul.name" . }}
            release: "{{ .Release.Name }}"
            component: server
        topologyKey: kubernetes.io/hostname
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "affinity",
						Column:  1,
						KindTag: "!!str",
						Default: "podAntiAffinity:\n  requiredDuringSchedulingIgnoredDuringExecution:\n    - labelSelector:\n        matchLabels:\n          app: {{ template \"consul.name\" . }}\n          release: \"{{ .Release.Name }}\"\n          component: server\n      topologyKey: kubernetes.io/hostname\n",
						Comment: "# Affinity Settings",
					},
				},
			},
		},
		"k8sAllowNamespaces": {
			Input: `---
# @type: array<string>
k8sAllowNamespaces: ["*"]`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "k8sAllowNamespaces",
						Column:  1,
						KindTag: "!!seq",
						Default: "[\"*\"]\n",
						Comment: "# @type: array<string>",
					},
				},
			},
		},
		"k8sDenyNamespaces": {
			Input: `---
# @type: array<string>
k8sDenyNamespaces: ["kube-system", "kube-public"]`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "k8sDenyNamespaces",
						Column:  1,
						KindTag: "!!seq",
						Default: "[\"kube-system\", \"kube-public\"]\n",
						Comment: "# @type: array<string>",
					},
				},
			},
		},
		"gateways": {
			Input: `---
# @type: array<map>
gateways:
  - name: ingress-gateway`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "gateways",
						Column:  1,
						KindTag: "!!seq",
						Comment: "# @type: array<map>",
						Children: []DocNode{
							{
								Key:              "name",
								Column:           5,
								Default:          "ingress-gateway",
								KindTag:          "!!str",
								ParentBreadcrumb: "-gateways",
								ParentWasMap:     true,
							},
						},
					},
				},
			},
		},
		"enterprise alert": {
			Input: `---
# [Enterprise Only] line 1
# line 2
key: value
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						KindTag: "!!str",
						Default: "value",
						Comment: "# [Enterprise Only] line 1\n# line 2",
					},
				},
			},
		},
		"yaml comments in examples": {
			Input: `---
# Examples:
#
# $$$yaml
# # Consul 1.5.0
# image: "consul:1.5.0"
# # Consul Enterprise 1.5.0
# image: "hashicorp/consul-enterprise:1.5.0-ent"
# $$$
key: value
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						KindTag: "!!str",
						Default: "value",
						Comment: "# Examples:\n#\n# ```yaml\n# # Consul 1.5.0\n# image: \"consul:1.5.0\"\n# # Consul Enterprise 1.5.0\n# image: \"hashicorp/consul-enterprise:1.5.0-ent\"\n# ```",
					},
				},
			},
		},
		"type override uses last match": {
			Input: `---
# @type: override-1
# @type: override-2
key: value
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						KindTag: "!!str",
						Default: "value",
						Comment: "# @type: override-1\n# @type: override-2",
					},
				},
			},
		},
		"recurse false": {
			Input: `---
key: value
# port docs
# @type: array<map>
# @recurse: false
ports:
- port: 8080
  nodePort: null
- port: 8443
  nodePort: null
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						KindTag: "!!str",
						Default: "value",
					},
					{
						Key:     "ports",
						Column:  1,
						Comment: "# port docs\n# @type: array<map>\n# @recurse: false",
					},
				},
			},
		},
		"@type: map": {
			Input: `---
# @type: map
key: null
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						KindTag: "!!null",
						Default: "null",
						Comment: "# @type: map",
					},
				},
			},
		},
		"if of type map and not annotated with @type": {
			Input: `---
key:
  foo: bar
`,
			Exp: DocNode{
				Children: []DocNode{
					{
						Key:     "key",
						Column:  1,
						KindTag: "!!map",
						Children: []DocNode{
							{
								Key:              "foo",
								Column:           3,
								KindTag:          "!!str",
								Default:          "bar",
								ParentBreadcrumb: "-key",
							},
						},
					},
				},
			},
		},
	}

	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			// Swap $ for `.
			input := strings.Replace(c.Input, "$", "`", -1)

			out, err := Parse(input)
			require.NoError(t, err)

			require.Equal(t, c.Exp, out)
		})
	}
}
