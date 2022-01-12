package main

import (
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

var (
	// typeAnnotation matches the @type annotation. It captures the value of @type.
	typeAnnotation = regexp.MustCompile(`(?m).*@type: (.*)$`)

	// defaultAnnotation matches the @default annotation. It captures the value of @default.
	defaultAnnotation = regexp.MustCompile(`(?m).*@default: (.*)$`)

	// recurseAnnotation matches the @recurse annotation. It captures the value of @recurse.
	recurseAnnotation = regexp.MustCompile(`(?m).*@recurse: (.*)$`)

	// commentPrefix matches on the YAML comment prefix, e.g.
	// ```
	// # comment here
	//   # comment with indent
	// ```
	// Will match on "comment here" and "comment with indent".
	//
	// It also properly handles YAML comments inside code fences, e.g.
	// ```
	// # Example:
	// # ```yaml
	// # # yaml comment
	// # ````
	// ```
	// And will not match the "# yaml comment" incorrectly.
	commentPrefix = regexp.MustCompile(`(?m)^[^\S\n]*#[^\S\n]?`)
)

// Parse parses yamlStr into a tree of DocNode's.
func Parse(yamlStr string) (DocNode, error) {
	var node yaml.Node
	err := yaml.Unmarshal([]byte(yamlStr), &node)
	if err != nil {
		return DocNode{}, err
	}

	// Due to how the YAML is parsed this is the first real node.
	rootNode := node.Content[0].Content
	children, err := parseNodeContent(rootNode, "", false)
	if err != nil {
		return DocNode{}, err
	}
	return DocNode{
		Column:   0,
		Children: children,
	}, nil
}

// parseNodeContent recursively parses the yaml nodes and outputs a DocNode
// tree.
func parseNodeContent(nodeContent []*yaml.Node, parentBreadcrumb string, parentWasMap bool) ([]DocNode, error) {
	var docNodes []DocNode

	// This is a special type of node where it's an array of maps.
	// e.g.
	// ````
	// ingressGateways:
	// - name: name
	// ````
	//
	// In this case we show the docs as:
	// - ingress-gateway: ingress gateway descrip
	//   - name: name descrip.
	//
	// To do that, we actually need to skip the map node.
	if len(nodeContent) == 1 {
		return parseNodeContent(nodeContent[0].Content, parentBreadcrumb, true)
	}

	// skipNext is true if we should skip the next node. Due to how the YAML is
	// parsed, a key: value pair results in two YAML nodes but we only need
	// doc node out of that so in the loop we look ahead to the next node
	// and use it to construct our DocNode. Then we can skip it on the next
	// iteration.
	skipNext := false
	for i, child := range nodeContent {
		if skipNext {
			skipNext = false
			continue
		}

		docNode, err := buildDocNode(i, child, nodeContent, parentBreadcrumb, parentWasMap)
		if err != nil {
			return nil, err
		}

		if err := docNode.Validate(); err != nil {
			return nil, &ParseError{
				FullAnchor: docNode.HTMLAnchor(),
				Err:        err.Error(),
			}
		}

		docNodes = append(docNodes, docNode)
		skipNext = true
		continue
	}
	return docNodes, nil
}

// toInlineYaml will return the yaml string representation for content
// using the inline representation, i.e. `["a", "b"]`
// instead of:
// ```
// - "a"
// - "b"
// ```
func toInlineYaml(content []*yaml.Node) (string, error) {
	// We have to use this struct so we can set the struct tag "flow" so the
	// generated yaml uses the inline format.
	type intermediary struct {
		Arr []*yaml.Node `yaml:"arr,flow"`
	}
	i := intermediary{
		Arr: content,
	}
	out, err := yaml.Marshal(i)
	if err != nil {
		return "", err
	}
	// Hack: because we had to use our struct, it has the key "arr: " which
	// we need to trim. Before trimming it will look like:
	// `arr: ["a","b"]`.
	return strings.TrimPrefix(string(out), "arr: "), nil
}
