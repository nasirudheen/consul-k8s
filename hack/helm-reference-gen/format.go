package main

import (
	"bytes"
	"io/ioutil"
	"strings"
	"text/template"
)

// FormatAsList formats a DocNode as a list of items which are increasingly indented.
func FormatAsList(node DocNode) (string, error) {
	listTemplate, err := ioutil.ReadFile("./templates/list.tpl")
	if err != nil {
		return "", err
	}
	docNodeTmpl := template.Must(
		template.New("").Parse(string(listTemplate)),
	)

	docs, err := generateDocsFromNode(docNodeTmpl, node)
	if err != nil {
		return "", err
	}

	toc := generateTOC(node)
	return toc + strings.Join(docs, "\n"), nil
}

// FormatAsTables formats a DocNode as a series of tables for each value which has children.
func FormatAsTables(node DocNode) (string, error) {
	buf := new(strings.Builder)

	err := generateTables(node, buf)
	if err != nil {
		return "", err
	}

	return buf.String(), nil
}

func generateTables(node DocNode, buf *strings.Builder) error {
	for _, node := range node.Children {
		if node.IsMap() {
			buf.WriteString(node.Header())
		}
		err := generateTables(node, buf)
		if err != nil {
			return err
		}
	}

	return nil
}

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
