package main

import (
	"bytes"
	"text/template"
)

func generateDocsFromNode(tm *template.Template, node DocNode) ([]string, error) {
	var out []string
	for _, child := range node.Children {
		var nodeOut bytes.Buffer
		err := tm.Execute(&nodeOut, child)
		if err != nil {
			return nil, err
		}
		childOut, err := generateDocsFromNode(tm, child)
		if err != nil {
			return nil, err
		}
		out = append(append(out, nodeOut.String()), childOut...)
	}
	return out, nil
}
